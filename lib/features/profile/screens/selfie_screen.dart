import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/supabase_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
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
      await client.storage
          .from(SupabaseConstants.selfiesBucket)
          .uploadBinary(path, bytes, fileOptions: const FileOptions(upsert: true, contentType: 'image/jpeg'));

      final url = client.storage.from(SupabaseConstants.selfiesBucket).getPublicUrl(path);

      await client.from('user_photos').insert({
        'user_id': uid,
        'url': url,
        'is_primary': false,
        'is_selfie': true,
        'order_index': 0,
        'moderation_status': 'pending',
      });

      if (mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/permissions');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.error_generic}: $e'), backgroundColor: AppColors.error),
        );
        setState(() => _isUploading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
      ),
      body: AmbientBackground(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!.selfie_title, style: AppTextStyles.displayMedium),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.selfie_subtitle,
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: 32),
                Center(
                  child: GestureDetector(
                    onTap: _takeSelfie,
                    child: Container(
                      width: 220,
                      height: 280,
                      decoration: BoxDecoration(
                        color: AppColors.glassBg,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: _selfie != null ? AppColors.red : AppColors.glassBorder,
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
                                const Icon(Icons.camera_front, size: 48, color: AppColors.textTertiary),
                                const SizedBox(height: 12),
                                Text(AppLocalizations.of(context)!.selfie_take_btn, style: AppTextStyles.bodyMedium),
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
                const Spacer(),
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
          Icon(icon, size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 12),
          Text(text, style: AppTextStyles.bodyMedium),
        ],
      );
}
