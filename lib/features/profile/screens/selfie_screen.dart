import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/native_uploader.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../core/utils/selfie_reason_l10n.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/sc_button.dart';
import '../../../shared/widgets/sc_scaffold.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

class SelfieScreen extends StatefulWidget {
  /// İlk kayıt akışından (fotoğraf ekranı) gelindiğinde true — yalnız bu
  /// durumda "şimdilik atla" görünür; guard/ayarlar yollarında görünmez.
  final bool fromOnboarding;

  const SelfieScreen({super.key, this.fromOnboarding = false});

  @override
  State<SelfieScreen> createState() => _SelfieScreenState();
}

class _SelfieScreenState extends State<SelfieScreen> {
  File? _selfie;
  bool _isUploading = false;
  final _picker = ImagePicker();
  bool _wasRejected = false;
  String? _rejectedReason;
  bool _isPending = false;

  @override
  void initState() {
    super.initState();
    _loadRejection();
  }

  // Red bildirimi kaçmış olabilir — son red durumu ve preset sebebi
  // selfie ekranında da gösterilir (Mustafa kararı 16.07).
  Future<void> _loadRejection() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await client
          .from('users')
          .select('selfie_status, selfie_rejected_reason')
          .eq('id', uid)
          .maybeSingle();
      if (!mounted || row == null) return;
      final status = row['selfie_status'] as String?;
      // Onay bekleyen kullanıcı yeniden çekip kuyruğunu sıfırlamasın —
      // banner + çekim/gönder kilidi (29.07).
      if (status == 'pending') {
        setState(() => _isPending = true);
        return;
      }
      if (status != 'rejected') return;
      setState(() {
        _wasRejected = true;
        _rejectedReason = row['selfie_rejected_reason'] as String?;
      });
    } catch (_) {
      // Banner bilgilendirme amaçlı — hata ekranı bloklamaz
    }
  }

  Future<void> _takeSelfie() async {
    // 23.08: imageQuality/maxWidth picker'da re-encode yapıp EXIF Orientation
    // etiketini düşürüyor ama pikseli DÖNDÜRMÜYORDU → panele yan yatık selfie
    // (Samsung portrait). Ham çek; küçültme + açı düzeltme compress'te
    // (autoCorrectionAngle EXIF açısını piksele uygular).
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
    );
    if (picked == null) return;
    final upright = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      '${picked.path}_upright.jpg',
      quality: 80,
      minWidth: 1200,
      minHeight: 1200,
    );
    if (upright != null) {
      setState(() => _selfie = File(upright.path));
    }
  }

  Future<void> _submit() async {
    setState(() => _isUploading = true);
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      final selfie = _selfie;
      // 31.07 denetimi: sessiz return _isUploading'i kalıcı true bırakıyordu —
      // buton kilitlenip selfie hiç gönderilemiyordu. Hata görünür olsun.
      if (uid == null || selfie == null) throw Exception('no_session_or_photo');
      final path = '$uid/selfie_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final bytes = await selfie.readAsBytes();
      final accessToken = client.auth.currentSession!.accessToken;
      await NativeUploader.uploadBytes(
        url:
            '${SupabaseConstants.supabaseUrl}/storage/v1/object/${SupabaseConstants.selfiesBucket}/$path',
        accessToken: accessToken,
        apiKey: SupabaseConstants.supabaseAnonKey,
        bytes: bytes,
        contentType: 'image/jpeg',
      );

      final url = client.storage
          .from(SupabaseConstants.selfiesBucket)
          .getPublicUrl(path);

      await client.from('user_photos').insert({
        'user_id': uid,
        'url': url,
        'is_primary': false,
        'is_selfie': true,
        'order_index': 0,
        'moderation_status': 'pending',
      });

      if (mounted) context.go('/feed');
    } catch (_) {
      // Ham exception metni kullanıcıya sızdırılmaz (31.07)
      if (mounted) {
        _showAuroraSnack(
          AppLocalizations.of(context)!.error_generic,
          accentColor: AuroraTheme.auroraRed,
          icon: Icons.error_outline,
        );
        setState(() => _isUploading = false);
      }
    }
  }

  void _showAuroraSnack(
    String message, {
    required Color accentColor,
    required IconData icon,
  }) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        backgroundColor: AuroraTheme.bgDeep,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: accentColor.withOpacity(0.4)),
        ),
        content: Row(
          children: [
            Icon(icon, color: accentColor, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScScaffold(
      backgroundColor: AuroraTheme.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: AuroraTheme.textPrimary,
          ),
          // Onboarding go() zinciri — çıplak pop ölüydü (31.07 Y4); bir adım
          // geri: fotoğraf yükleme ekranı.
          onPressed: () => context.canPop()
              ? context.pop()
              : context.go('/profile/photos'),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.selfie_title,
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w700,
                    fontSize: 32,
                    color: AuroraTheme.textPrimary,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.selfie_subtitle,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    color: AuroraTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
                if (_isPending) ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.hourglass_top_rounded,
                          size: 18,
                          color: AuroraTheme.auroraBlue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!.selfie_pending_banner_title,
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AuroraTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!.selfie_pending_banner_body,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 13,
                                  color: AuroraTheme.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_wasRejected) ...[
                  const SizedBox(height: 16),
                  GlassCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 18,
                          color: AuroraTheme.auroraRed,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(
                                  context,
                                )!.notif_type_selfie_rejected_title,
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AuroraTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                selfieReasonL10n(
                                      AppLocalizations.of(context)!,
                                      _rejectedReason,
                                    ) ??
                                    AppLocalizations.of(
                                      context,
                                    )!.notif_type_selfie_rejected_body,
                                style: TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 13,
                                  color: AuroraTheme.textSecondary,
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                Center(
                  child: GestureDetector(
                    onTap: _isPending ? null : _takeSelfie,
                    child: Container(
                      width: 220,
                      height: 260,
                      decoration: BoxDecoration(
                        color: AuroraTheme.glassBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _selfie != null
                              ? AuroraTheme.auroraRed
                              : AuroraTheme.glassBorder,
                        ),
                      ),
                      child: _selfie != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(23),
                              child: Image.file(_selfie!, fit: BoxFit.cover),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.camera_front,
                                  size: 48,
                                  color: AuroraTheme.textMuted,
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  AppLocalizations.of(context)!.selfie_take_btn,
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 14,
                                    color: AuroraTheme.textSecondary,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                GlassCard(
                  child: Column(
                    children: [
                      _Tip(
                        icon: Icons.light_mode_outlined,
                        text: AppLocalizations.of(context)!.selfie_tip_lighting,
                      ),
                      const SizedBox(height: 10),
                      _Tip(
                        icon: Icons.face_outlined,
                        text: AppLocalizations.of(context)!.selfie_tip_face,
                      ),
                      const SizedBox(height: 10),
                      _Tip(
                        icon: Icons.timer_outlined,
                        text: AppLocalizations.of(context)!.selfie_tip_approval,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ScButton(
                  label: AppLocalizations.of(context)!.selfie_submit_btn,
                  onPressed: (_selfie != null && !_isPending) ? _submit : null,
                  isLoading: _isUploading,
                ),
                if (widget.fromOnboarding && !_isPending && !_wasRejected) ...[
                  const SizedBox(height: 12),
                  Center(
                    child: Column(
                      children: [
                        Text(
                          AppLocalizations.of(context)!.selfie_skip_note,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            color: AuroraTheme.textMuted,
                            height: 1.4,
                          ),
                        ),
                        TextButton(
                          onPressed:
                              _isUploading ? null : () => context.go('/feed'),
                          child: Text(
                            AppLocalizations.of(context)!.selfie_skip_btn,
                            style: TextStyle(
                              fontFamily: 'Manrope',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AuroraTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Tip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18, color: AuroraTheme.textSecondary),
      const SizedBox(width: 12),
      // 23.08 testçi vakası: Expanded'sız Text dar/büyük-yazı ekranda sağdan
      // kırpılıyordu — satır sar, kesme.
      Expanded(
        child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Manrope',
          fontSize: 14,
          color: AuroraTheme.textSecondary,
          height: 1.5,
        ),
        ),
      ),
    ],
  );
}
