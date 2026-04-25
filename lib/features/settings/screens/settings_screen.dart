import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
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

  String _currentLanguageLabel(BuildContext context) {
    final locale = ref.read(localeProvider);
    if (locale == null) return AppLocalizations.of(context)!.settings_language_system;
    switch (locale.languageCode) {
      case 'tr': return 'Türkçe';
      case 'ru': return 'Русский';
      case 'en': return 'English';
      case 'de': return 'Deutsch';
      default: return AppLocalizations.of(context)!.settings_language_system;
    }
  }

  void _showLanguagePicker(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentLocale = ref.read(localeProvider);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.glassBgMedium,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border(
                    top: BorderSide(color: AppColors.glassBorder)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.glassBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(l10n.settings_language,
                        style: AppTextStyles.titleMedium),
                    const SizedBox(height: 16),
                    ...[
                      ('tr', '🇹🇷', 'Türkçe'),
                      ('ru', '🇷🇺', 'Русский'),
                      ('en', '🇬🇧', 'English'),
                      ('de', '🇩🇪', 'Deutsch'),
                    ].map((entry) {
                      final (code, flag, name) = entry;
                      final isSelected = currentLocale?.languageCode == code;
                      return _LangTile(
                        flag: flag,
                        name: name,
                        isSelected: isSelected,
                        onTap: () {
                          ref
                              .read(localeProvider.notifier)
                              .setLocale(code);
                          Navigator.of(context).pop();
                          setState(() {});
                        },
                      );
                    }),
                    _LangTile(
                      flag: '🌐',
                      name: l10n.settings_language_system,
                      isSelected: currentLocale == null,
                      onTap: () {
                        ref
                            .read(localeProvider.notifier)
                            .useSystemLocale();
                        Navigator.of(context).pop();
                        setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => context.pop(),
        ),
        title: Text(l10n.settings_title, style: AppTextStyles.titleMedium),
      ),
      body: AmbientBackground(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _VerificationCard(
              selfieStatus: _selfieStatus,
              onRetake: () {
                context.push('/profile/selfie').then((_) => _loadSelfieStatus());
              },
            ),
            const SizedBox(height: 20),
            _Section(title: l10n.settings_profile_section, icon: Icons.person_outline, items: [
              _SettingsTile(
                icon: Icons.edit_outlined,
                label: l10n.settings_edit_profile,
                onTap: () => context.push('/profile/setup'),
              ),
              _SettingsTile(
                icon: Icons.add_photo_alternate_outlined,
                label: l10n.settings_edit_photos,
                onTap: () => context.push('/profile/photos'),
              ),
            ]),
            const SizedBox(height: 20),
            // ── Dil ─────────────────────────────────────────────────────────
            _Section(
                title: l10n.settings_language,
                icon: Icons.language_outlined,
                items: [
                  _SettingsTile(
                    icon: Icons.language_outlined,
                    label: l10n.settings_language,
                    value: _currentLanguageLabel(context),
                    onTap: () => _showLanguagePicker(context),
                  ),
                ]),
            const SizedBox(height: 20),
            _Section(
                title: l10n.settings_notifications,
                icon: Icons.notifications_outlined,
                items: [
                  _SettingsTile(
                    icon: Icons.notifications_active_outlined,
                    label: l10n.settings_notification_prefs,
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.do_not_disturb_on_outlined,
                    label: l10n.settings_do_not_disturb,
                    onTap: () {},
                  ),
                ]),
            const SizedBox(height: 20),
            _Section(
                title: l10n.settings_account,
                icon: Icons.manage_accounts_outlined,
                items: [
                  _SettingsTile(
                    icon: Icons.devices_outlined,
                    label: l10n.settings_active_devices,
                    onTap: () {},
                  ),
                  _SettingsTile(
                    icon: Icons.download_outlined,
                    label: l10n.settings_download_data,
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
            _DangerButton(
              icon: Icons.logout,
              label: l10n.settings_logout,
              onTap: () async {
                await Supabase.instance.client.auth.signOut();
                if (context.mounted) context.go('/splash');
              },
            ),
            const SizedBox(height: 12),
            _DangerButton(
              icon: Icons.delete_forever_outlined,
              label: l10n.settings_delete_account,
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
// Language Tile
// ─────────────────────────────────────────────────────────────────────────────

class _LangTile extends StatelessWidget {
  final String flag;
  final String name;
  final bool isSelected;
  final VoidCallback onTap;

  const _LangTile({
    required this.flag,
    required this.name,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          child: Row(
            children: [
              Text(flag, style: const TextStyle(fontSize: 22)),
              const SizedBox(width: 16),
              Expanded(
                child: Text(name, style: AppTextStyles.bodyLarge),
              ),
              if (isSelected)
                ShaderMask(
                  shaderCallback: (b) =>
                      AppColors.primaryGradient.createShader(b),
                  child: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 20),
                ),
            ],
          ),
        ),
      );
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
                  Text(value!, style: AppTextStyles.bodyMedium),
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
  const _VerificationCard(
      {required this.selfieStatus, required this.onRetake});

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
