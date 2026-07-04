import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/services/native_uploader.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/sc_button.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

class SelfieScreen extends StatefulWidget {
  const SelfieScreen({super.key});

  @override
  State<SelfieScreen> createState() => _SelfieScreenState();
}

class _SelfieScreenState extends State<SelfieScreen> {
  File? _selfie;
  bool _isUploading = false;
  final _picker = ImagePicker();

  Future<void> _takeSelfie() async {
    final picked = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.front,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked != null) {
      setState(() => _selfie = File(picked.path));
    }
  }

  Future<void> _submit() async {
    setState(() => _isUploading = true);
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser?.id;
      final selfie = _selfie;
      if (uid == null || selfie == null) return;
      final path = '$uid/selfie_${DateTime.now().millisecondsSinceEpoch}.jpg';

      final bytes = await selfie.readAsBytes();
      final accessToken = client.auth.currentSession!.accessToken;
      await NativeUploader.uploadBytes(
        url: '${SupabaseConstants.supabaseUrl}/storage/v1/object/${SupabaseConstants.selfiesBucket}/$path',
        accessToken: accessToken,
        apiKey: SupabaseConstants.supabaseAnonKey,
        bytes: bytes,
        contentType: 'image/jpeg',
      );

      final url = client.storage.from(SupabaseConstants.selfiesBucket).getPublicUrl(path);

      await client.from('user_photos').insert({
        'user_id': uid,
        'url': url,
        'is_primary': false,
        'is_selfie': true,
        'order_index': 0,
        'moderation_status': 'pending',
      });

      if (mounted) context.go('/feed');
    } catch (e) {
      if (mounted) {
        _showAuroraSnack(
          '${AppLocalizations.of(context)!.error_generic}: $e',
          accentColor: AuroraTheme.auroraRed,
          icon: Icons.error_outline,
        );
        setState(() => _isUploading = false);
      }
    }
  }

  void _showAuroraSnack(String message,
      {required Color accentColor, required IconData icon}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
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
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AuroraTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      resizeToAvoidBottomInset: false,
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
                const SizedBox(height: 32),
                Center(
                  child: GestureDetector(
                    onTap: _takeSelfie,
                    child: Container(
                      width: 220,
                      height: 260,
                      decoration: BoxDecoration(
                        color: AuroraTheme.glassBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _selfie != null ? AuroraTheme.auroraRed : AuroraTheme.glassBorder,
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
                                Icon(Icons.camera_front, size: 48, color: AuroraTheme.textMuted),
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
                      _Tip(icon: Icons.light_mode_outlined, text: AppLocalizations.of(context)!.selfie_tip_lighting),
                      const SizedBox(height: 10),
                      _Tip(icon: Icons.face_outlined, text: AppLocalizations.of(context)!.selfie_tip_face),
                      const SizedBox(height: 10),
                      _Tip(icon: Icons.timer_outlined, text: AppLocalizations.of(context)!.selfie_tip_approval),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                ScButton(
                  label: AppLocalizations.of(context)!.selfie_submit_btn,
                  onPressed: _selfie != null ? _submit : null,
                  isLoading: _isUploading,
                ),
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
          Text(
            text,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              color: AuroraTheme.textSecondary,
              height: 1.5,
            ),
          ),
        ],
      );
}
