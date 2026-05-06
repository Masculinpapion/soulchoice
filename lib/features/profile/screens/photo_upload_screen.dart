import 'dart:math';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart';
import '../providers/profile_provider.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

// Her slot ya boş, ya yeni local bytes, ya da mevcut uzak fotoğraf
class _PhotoEntry {
  final Uint8List? bytes; // yeni fotoğraf — memory'de tutulur, file I/O yok
  final String? url;
  final String? remoteId;

  const _PhotoEntry._({this.bytes, this.url, this.remoteId});

  static const empty = _PhotoEntry._();
  factory _PhotoEntry.local(Uint8List b) => _PhotoEntry._(bytes: b);
  factory _PhotoEntry.remote(String u, String id) =>
      _PhotoEntry._(url: u, remoteId: id);

  bool get isEmpty => bytes == null && url == null;
  bool get isLocal => bytes != null;
  bool get isRemote => url != null;
}

class PhotoUploadScreen extends ConsumerStatefulWidget {
  /// true → ayarlardan gelindi (mevcut fotoğrafları yükle, kaydedince pop)
  /// false → onboarding akışı (min fotoğraf zorunlu, kaydedince selfie)
  final bool isEditing;
  const PhotoUploadScreen({super.key, this.isEditing = false});

  @override
  ConsumerState<PhotoUploadScreen> createState() => _PhotoUploadScreenState();
}

class _PhotoUploadScreenState extends ConsumerState<PhotoUploadScreen> {
  final List<_PhotoEntry> _photos =
      List.filled(AppConstants.maxPhotos, _PhotoEntry.empty);
  // Editing modunda yüklenen orijinal remote fotoğraflar — hangileri silineceğini takip etmek için
  final List<_PhotoEntry> _originalRemotePhotos = [];
  final _picker = ImagePicker();
  bool _isUploading = false;
  bool _isLoading = false;

  int get _filledCount => _photos.where((p) => !p.isEmpty).length;
  bool get _canSave =>
      widget.isEditing ? _filledCount > 0 : _filledCount >= AppConstants.minPhotos;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) _loadExistingPhotos();
  }

  Future<void> _loadExistingPhotos() async {
    setState(() => _isLoading = true);
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final rows = await Supabase.instance.client
          .from('user_photos')
          .select('id, url, order_index')
          .eq('user_id', uid)
          .eq('is_selfie', false)
          .order('order_index');
      if (!mounted) return;
      setState(() {
        // Tüm slot'ları sıfırla, sonra DB'den gelen verileri doldur
        for (int i = 0; i < AppConstants.maxPhotos; i++) {
          _photos[i] = _PhotoEntry.empty;
        }
        for (int i = 0; i < rows.length && i < AppConstants.maxPhotos; i++) {
          _photos[i] = _PhotoEntry.remote(
            rows[i]['url'] as String,
            rows[i]['id'] as String,
          );
        }
        // Storage cleanup için orijinal listeyi sakla
        _originalRemotePhotos
          ..clear()
          ..addAll(_photos.where((p) => p.isRemote));
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickPhoto(int index) async {
    try {
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
        maxWidth: 1080,
      );
      if (picked == null || !mounted) return;

      final rawBytes = await picked.readAsBytes();

      // Flutter tabanlı crop ekranı — UCropActivity yok, request code çakışması yok
      final croppedBytes = await Navigator.of(context).push<Uint8List>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => _CropScreen(imageBytes: rawBytes),
        ),
      );
      if (croppedBytes == null || !mounted) return;

      // croppedBytes'ı direkt memory'de sakla — dosya yazmak yok, compression yok
      setState(() => _photos[index] = _PhotoEntry.local(croppedBytes));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.photo_upload_pick_error(e.toString())),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _removePhoto(int index) {
    setState(() => _photos[index] = _PhotoEntry.empty);
  }

  void _setPrimary(int index) {
    if (index == 0 || _photos[index].isEmpty) return;
    setState(() {
      final entry = _photos[index];
      for (int i = index; i > 0; i--) {
        _photos[i] = _photos[i - 1];
      }
      _photos[0] = entry;
    });
  }

  // Çakışmaya karşı güvenli 64-bit rastgele hex ID üretir (milisaniye race'i yok)
  String _uniqueId() {
    final rng = Random.secure();
    return List.generate(8, (_) => rng.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
  }

  // Supabase public URL'inden storage path'ini çıkarır
  // Örnek: .../object/public/profile-photos/uid/filename.jpg → uid/filename.jpg
  String? _storagePathFromUrl(String url) {
    const marker = '/object/public/${SupabaseConstants.profilePhotosBucket}/';
    final idx = url.indexOf(marker);
    if (idx == -1) return null;
    return url.substring(idx + marker.length);
  }

  Future<void> _save() async {
    setState(() => _isUploading = true);
    final client = Supabase.instance.client;
    // Rollback için: try dışında tanımlanır ki catch'ten erişilebilsin
    final uploadedPaths = <String>[];
    final insertedDbIds = <String>[];
    try {
      final uid = client.auth.currentUser?.id;
      if (uid == null) return;

      // Tutulacak remote ID'leri topla; tekrar eden remote'ları atla
      final keptIds = <String>[];
      final seenRemoteIds = <String>{};
      final filled = _photos.asMap().entries
          .where((e) => !e.value.isEmpty)
          .where((e) {
            if (e.value.isRemote) return seenRemoteIds.add(e.value.remoteId!);
            return true;
          })
          .toList();

      for (int orderIdx = 0; orderIdx < filled.length; orderIdx++) {
        final entry = filled[orderIdx].value;
        final isPrimary = orderIdx == 0;

        if (entry.isLocal) {
          // Yeni fotoğraf: dio ile storage'a yükle + DB'ye ekle
          // dart:io HttpClient Android 15'te büyük body'leri asla göndermiyor (408);
          // dio OkHttp kullandığı için bu sorunu yaşamıyor.
          final path = '$uid/${_uniqueId()}.png';
          final accessToken = client.auth.currentSession!.accessToken;

          final dio = Dio();
          await dio.put(
            '${SupabaseConstants.supabaseUrl}/storage/v1/object/${SupabaseConstants.profilePhotosBucket}/$path',
            data: Stream.fromIterable([entry.bytes!]),
            options: Options(
              headers: {
                'Authorization': 'Bearer $accessToken',
                'apikey': SupabaseConstants.supabaseAnonKey,
                'Content-Type': 'image/png',
                'Content-Length': entry.bytes!.length,
                'x-upsert': 'true',
              },
              sendTimeout: const Duration(minutes: 5),
              receiveTimeout: const Duration(minutes: 1),
            ),
          );
          uploadedPaths.add(path); // rollback: upload başarılı, izle

          final url = client.storage
              .from(SupabaseConstants.profilePhotosBucket)
              .getPublicUrl(path);

          final inserted = await client.from('user_photos').insert({
            'user_id': uid,
            'url': url,
            'is_primary': isPrimary,
            'is_selfie': false,
            'order_index': orderIdx,
            'moderation_status': 'approved',
          }).select('id').single();
          insertedDbIds.add(inserted['id'] as String); // rollback: DB kaydı izle
          keptIds.add(inserted['id'] as String);
        } else {
          // Mevcut fotoğraf: sıra ve primary güncelle
          await client
              .from('user_photos')
              .update({'order_index': orderIdx, 'is_primary': isPrimary})
              .eq('id', entry.remoteId!);
          keptIds.add(entry.remoteId!);
        }
      }

      // Storage cleanup: orijinal yüklenen remote fotoğraflardan artık tutulmayanlara ait
      // dosyaları storage'dan sil (DB'den silmeden önce)
      final keptRemoteIds = filled
          .where((e) => e.value.isRemote)
          .map((e) => e.value.remoteId!)
          .toSet();
      final storagePathsToDelete = _originalRemotePhotos
          .where((p) => !keptRemoteIds.contains(p.remoteId))
          .map((p) => _storagePathFromUrl(p.url!))
          .whereType<String>()
          .toList();
      if (storagePathsToDelete.isNotEmpty) {
        await client.storage
            .from(SupabaseConstants.profilePhotosBucket)
            .remove(storagePathsToDelete);
      }

      // Artık olmayan tüm fotoğrafları sil (selfie hariç) — NOT IN ile kesin temizlik
      if (keptIds.isEmpty) {
        await client.from('user_photos')
            .delete()
            .eq('user_id', uid)
            .eq('is_selfie', false);
      } else {
        await client.from('user_photos')
            .delete()
            .eq('user_id', uid)
            .eq('is_selfie', false)
            .not('id', 'in', '(${keptIds.join(',')})');
      }

      if (!mounted) return;
      ref.invalidate(userPhotosProvider(uid));
      ref.invalidate(userProfileProvider(uid));
      if (widget.isEditing) {
        context.pop();
      } else {
        context.go('/profile/selfie');
      }
    } catch (e) {
      // Rollback: loop ortasında hata çıktıysa yüklenen dosyaları geri al
      if (uploadedPaths.isNotEmpty) {
        await client.storage
            .from(SupabaseConstants.profilePhotosBucket)
            .remove(uploadedPaths)
            .catchError((_) {});
      }
      if (insertedDbIds.isNotEmpty) {
        await client.from('user_photos')
            .delete()
            .inFilter('id', insertedDbIds)
            .catchError((_) {});
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.photo_upload_error(e.toString())),
              backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      body: AmbientBackground(
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: AppColors.red))
              : Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
                        onPressed: () => context.pop(),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.isEditing
                            ? AppLocalizations.of(context)!.photo_upload_title_edit
                            : AppLocalizations.of(context)!.photo_upload_title_add,
                        style: AppTextStyles.displayMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)!.photo_upload_subtitle(AppConstants.minPhotos, AppConstants.maxPhotos, _filledCount, AppConstants.maxPhotos),
                        style: AppTextStyles.mono,
                      ),
                      const SizedBox(height: 32),
                      Expanded(
                        child: GridView.builder(
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 8,
                            mainAxisSpacing: 8,
                            childAspectRatio: 3 / 4,
                          ),
                          itemCount: AppConstants.maxPhotos,
                          itemBuilder: (_, i) => _PhotoSlot(
                            entry: _photos[i],
                            isPrimary: i == 0,
                            onTap: () => _pickPhoto(i),
                            onRemove: _photos[i].isEmpty ? null : () => _removePhoto(i),
                            onSetPrimary: (i == 0 || _photos[i].isEmpty) ? null : () => _setPrimary(i),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ScButton(
                        label: widget.isEditing ? AppLocalizations.of(context)!.photo_upload_btn_save : AppLocalizations.of(context)!.photo_upload_btn_continue,
                        onPressed: _canSave && !_isUploading ? _save : null,
                        isLoading: _isUploading,
                      ),
                    ],
                  ),
                ),
        ),
      ),
    );
  }
}

class _PhotoSlot extends StatelessWidget {
  final _PhotoEntry entry;
  final bool isPrimary;
  final VoidCallback onTap;
  final VoidCallback? onRemove;
  final VoidCallback? onSetPrimary;

  const _PhotoSlot({
    required this.entry,
    required this.isPrimary,
    required this.onTap,
    this.onRemove,
    this.onSetPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Fotoğraf (yerel file veya uzak URL)
            if (entry.isLocal)
              Image.memory(entry.bytes!, fit: BoxFit.cover)
            else if (entry.isRemote)
              CachedNetworkImage(
                imageUrl: entry.url!,
                fit: BoxFit.cover,
                placeholder: (_, __) => Container(
                  color: AppColors.glassBg,
                  child: const Center(
                      child: CircularProgressIndicator(
                          strokeWidth: 1.5, color: AppColors.red)),
                ),
                errorWidget: (_, __, ___) => Container(
                  color: AppColors.glassBg,
                  child: const Icon(Icons.broken_image_outlined,
                      color: AppColors.textTertiary),
                ),
              )
            else
              // Boş slot
              Container(
                decoration: BoxDecoration(
                  color: AppColors.glassBg,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isPrimary
                        ? AppColors.red.withOpacity(0.5)
                        : AppColors.glassBorder,
                  ),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_photo_alternate_outlined,
                      color: isPrimary ? AppColors.red : AppColors.textTertiary,
                      size: 28,
                    ),
                    if (isPrimary) ...[
                      const SizedBox(height: 6),
                      Text(AppLocalizations.of(context)!.photo_upload_primary_label,
                          style: AppTextStyles.monoSmall
                              .copyWith(color: AppColors.red)),
                    ],
                  ],
                ),
              ),

            // Sil butonu — ayrı GestureDetector, fotoğraf tapından bağımsız
            if (onRemove != null)
              Positioned(
                top: 6,
                right: 6,
                child: GestureDetector(
                  onTap: onRemove,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.bgBlack.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close,
                        size: 16, color: AppColors.textPrimary),
                  ),
                ),
              ),

            // Ana fotoğraf yap ikonu — sol üst, yalnızca dolu + ana değilse
            if (onSetPrimary != null)
              Positioned(
                top: 6,
                left: 6,
                child: GestureDetector(
                  onTap: onSetPrimary,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.bgBlack.withOpacity(0.8),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.star_outline,
                        size: 16, color: AppColors.textPrimary),
                  ),
                ),
              ),

            // "Ana" etiketi
            if (isPrimary && !entry.isEmpty)
              Positioned(
                bottom: 6,
                left: 6,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(AppLocalizations.of(context)!.photo_upload_primary_badge,
                      style: AppTextStyles.monoSmall
                          .copyWith(color: AppColors.textPrimary)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// Flutter tabanlı crop ekranı — Activity açılmıyor, request code çakışması yok
class _CropScreen extends StatefulWidget {
  final Uint8List imageBytes;
  const _CropScreen({required this.imageBytes});

  @override
  State<_CropScreen> createState() => _CropScreenState();
}

class _CropScreenState extends State<_CropScreen> {
  final _controller = CropController();
  bool _isCropping = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050709),
      appBar: AppBar(
        backgroundColor: const Color(0xFF050709),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(null),
        ),
        title: Text(
          AppLocalizations.of(context)!.photo_crop_title,
          style: const TextStyle(fontFamily: 'Manrope', color: Colors.white, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: _isCropping ? null : () {
              setState(() => _isCropping = true);
              _controller.crop();
            },
            child: Text(
              AppLocalizations.of(context)!.photo_crop_apply,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontWeight: FontWeight.w700,
                color: _isCropping ? Colors.white38 : const Color(0xFFFF2D55),
              ),
            ),
          ),
        ],
      ),
      body: Crop(
              controller: _controller,
              image: widget.imageBytes,
              aspectRatio: 3 / 4,
              onCropped: (result) {
                if (result is CropSuccess) {
                  if (mounted) Navigator.of(context).pop(result.croppedImage);
                } else if (result is CropFailure) {
                  if (mounted) {
                    setState(() => _isCropping = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(AppLocalizations.of(context)!.photo_crop_error(result.cause.toString())),
                        backgroundColor: AppColors.error,
                      ),
                    );
                  }
                }
              },
            ),
    );
  }
}
