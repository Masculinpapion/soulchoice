import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _selfieStatus = 'none';

  @override
  void initState() {
    super.initState();
    _loadSelfieStatus();
  }

  Future<void> _loadSelfieStatus() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final row = await Supabase.instance.client
        .from('users')
        .select('selfie_status')
        .eq('id', uid)
        .maybeSingle();
    if (mounted) {
      setState(() =>
          _selfieStatus = row?['selfie_status'] as String? ?? 'none');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: Text('Ayarlar', style: AppTextStyles.titleMedium),
      ),
      body: AmbientBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Verification status card
            _VerificationCard(
              selfieStatus: _selfieStatus,
              onRetake: () {
                context.push('/profile/selfie').then((_) => _loadSelfieStatus());
              },
            ),
            const SizedBox(height: 20),
            _Section(title: 'Profil', icon: Icons.person_outline, items: [
              _SettingsTile(
                icon: Icons.edit_outlined,
                label: 'Profili düzenle',
                onTap: () => context.push('/profile/setup'),
              ),
              _SettingsTile(
                icon: Icons.add_photo_alternate_outlined,
                label: 'Fotoğrafları düzenle',
                onTap: () => context.push('/profile/photos'),
              ),
            ]),
            const SizedBox(height: 20),
            _Section(
                title: 'Bildirimler',
                icon: Icons.notifications_outlined,
                items: [
                  _SettingsTile(
                    icon: Icons.notifications_active_outlined,
                    label: 'Bildirim tercihleri',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.do_not_disturb_on_outlined,
                    label: 'Gece sessizliği',
                    onTap: () {},
                  ),
                ]),
            const SizedBox(height: 20),
            _Section(
                title: 'Hesap',
                icon: Icons.manage_accounts_outlined,
                items: [
                  _SettingsTile(
                    icon: Icons.language_outlined,
                    label: 'Dil',
                    value: 'Türkçe',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.devices_outlined,
                    label: 'Aktif cihazlar',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.download_outlined,
                    label: 'Verilerimi indir',
                    onTap: () {},
                  ),
                ]),
            const SizedBox(height: 20),
            _Section(
                title: 'Gizlilik & Güvenlik',
                icon: Icons.shield_outlined,
                items: [
                  _SettingsTile(
                    icon: Icons.location_on_outlined,
                    label: 'Konum izni',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.camera_alt_outlined,
                    label: 'Kamera izni',
                    onTap: () {},
                  ),
                ]),
            const SizedBox(height: 20),
            _Section(
                title: 'Destek',
                icon: Icons.help_outline,
                items: [
                  _SettingsTile(
                    icon: Icons.help_outline,
                    label: 'Yardım & Destek',
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.info_outline,
                    label: 'Hakkında',
                    onTap: () {},
                  ),
                ]),
            const SizedBox(height: 28),
            // Sign out
            _DangerButton(
              icon: Icons.logout,
              label: 'Çıkış yap',
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/splash');
              },
            ),
            const SizedBox(height: 12),
            // Delete account
            _DangerButton(
              icon: Icons.delete_forever_outlined,
              label: 'Hesabı sil',
              onTap: () => context.push('/settings/delete-account'),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<Widget> items;
  const _Section(
      {required this.title, required this.icon, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Row(
            children: [
              ShaderMask(
                shaderCallback: (b) =>
                    AppColors.primaryGradient.createShader(b),
                child: Icon(icon, color: Colors.white, size: 14),
              ),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: AppTextStyles.monoSmall.copyWith(letterSpacing: 1.5),
              ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.glassBgMedium,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                children: items.asMap().entries.map((e) {
                  final isLast = e.key == items.length - 1;
                  return Column(
                    children: [
                      e.value,
                      if (!isLast)
                        Container(
                          height: 1,
                          margin: const EdgeInsets.only(left: 52),
                          color: AppColors.glassBorder,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings Tile
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.glassBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.glassBorder),
                  ),
                  child: Icon(icon,
                      color: AppColors.textSecondary, size: 18),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(label, style: AppTextStyles.bodyLarge),
                ),
                if (value != null) ...[
                  Text(value!,
                      style: AppTextStyles.bodyMedium),
                  const SizedBox(width: 6),
                ],
                const Icon(Icons.arrow_forward_ios,
                    size: 13, color: AppColors.textTertiary),
              ],
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Danger Button
// ─────────────────────────────────────────────────────────────────────────────

class _DangerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _DangerButton(
      {required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AppColors.error.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  Icon(icon, color: AppColors.error, size: 20),
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: AppTextStyles.bodyLarge
                        .copyWith(color: AppColors.error),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Verification Status Card
// ─────────────────────────────────────────────────────────────────────────────

class _VerificationCard extends StatelessWidget {
  final String selfieStatus;
  final VoidCallback onRetake;
  const _VerificationCard({required this.selfieStatus, required this.onRetake});

  @override
  Widget build(BuildContext context) {
    String emoji;
    String label;
    Color color;
    bool showRetake = false;

    switch (selfieStatus) {
      case 'pending':
        emoji = '⏳';
        label = 'Selfie inceleniyor';
        color = AppColors.warning;
      case 'approved':
        emoji = '✅';
        label = 'Doğrulanmış hesap';
        color = AppColors.blue;
      case 'rejected':
        emoji = '❌';
        label = 'Selfie reddedildi — yeniden yükle';
        color = AppColors.error;
        showRetake = true;
      default:
        emoji = '🔲';
        label = 'Henüz selfie yüklenmedi';
        color = AppColors.textTertiary;
        showRetake = true;
    }

    return GlassCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 22)),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Doğrulama durumu',
                    style: AppTextStyles.labelLarge.copyWith(fontSize: 13)),
                const SizedBox(height: 2),
                Text(label,
                    style:
                        AppTextStyles.bodyMedium.copyWith(color: color)),
              ],
            ),
          ),
          if (showRetake)
            GestureDetector(
              onTap: onRetake,
              child: Text(
                'Yeniden Yükle',
                style: AppTextStyles.monoSmall.copyWith(
                  color: AppColors.gradientStart,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
