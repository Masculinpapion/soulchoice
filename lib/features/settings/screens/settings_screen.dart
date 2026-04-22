import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

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
          padding: const EdgeInsets.all(16),
          children: [
            _Section(title: 'Bildirimler', items: [
              _SettingsTile(icon: Icons.notifications_outlined, label: 'Bildirim tercihleri', onTap: () {}),
              _SettingsTile(icon: Icons.do_not_disturb_on_outlined, label: 'Gece sessizliği', onTap: () {}),
            ]),
            const SizedBox(height: 16),
            _Section(title: 'Hesap', items: [
              _SettingsTile(icon: Icons.language_outlined, label: 'Dil', value: 'Türkçe', onTap: () {}),
              _SettingsTile(icon: Icons.lock_outline, label: 'Aktif cihazlar', onTap: () {}),
              _SettingsTile(icon: Icons.download_outlined, label: 'Verilerimi indir', onTap: () {}),
            ]),
            const SizedBox(height: 16),
            _Section(title: 'Gizlilik & Güvenlik', items: [
              _SettingsTile(icon: Icons.location_on_outlined, label: 'Konum izni', onTap: () {}),
              _SettingsTile(icon: Icons.camera_alt_outlined, label: 'Kamera izni', onTap: () {}),
            ]),
            const SizedBox(height: 16),
            _Section(title: 'Destek', items: [
              _SettingsTile(icon: Icons.help_outline, label: 'Yardım & Destek', onTap: () {}),
              _SettingsTile(icon: Icons.info_outline, label: 'Hakkında', onTap: () {}),
            ]),
            const SizedBox(height: 16),
            GlassCard(
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/splash');
              },
              child: Row(
                children: [
                  const Icon(Icons.logout, color: AppColors.error),
                  const SizedBox(width: 14),
                  Text('Çıkış yap', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.error)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              onTap: () => context.push('/settings/delete-account'),
              child: Row(
                children: [
                  const Icon(Icons.delete_forever_outlined, color: AppColors.error),
                  const SizedBox(width: 14),
                  Text('Hesabı sil', style: AppTextStyles.bodyLarge.copyWith(color: AppColors.error)),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> items;
  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(title.toUpperCase(), style: AppTextStyles.monoSmall),
        ),
        GlassCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: items.asMap().entries.map((e) {
              final isLast = e.key == items.length - 1;
              return Column(
                children: [
                  e.value,
                  if (!isLast) const Divider(height: 1, color: AppColors.glassBorder, indent: 52),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback onTap;

  const _SettingsTile({required this.icon, required this.label, this.value, required this.onTap});

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon, color: AppColors.textSecondary, size: 22),
        title: Text(label, style: AppTextStyles.bodyLarge),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null) Text(value!, style: AppTextStyles.bodyMedium),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textTertiary),
          ],
        ),
        onTap: onTap,
      );
}
