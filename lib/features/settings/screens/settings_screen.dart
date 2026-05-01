import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/aurora_theme.dart';
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
    if (locale == null) {
      return AppLocalizations.of(context)!.settings_language_system;
    }
    switch (locale.languageCode) {
      case 'tr': return 'Türkçe';
      case 'ru': return 'Русский';
      case 'en': return 'English';
      case 'de': return 'Deutsch';
      default:
        return AppLocalizations.of(context)!.settings_language_system;
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
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D12).withOpacity(0.85),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(
                  top: BorderSide(color: AuroraTheme.glassBorder),
                ),
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
                        color: AuroraTheme.glassBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      l10n.settings_language,
                      style: const TextStyle(
                        fontFamily: 'Fraunces',
                        fontStyle: FontStyle.italic,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...[
                      ('tr', '🇹🇷', 'Türkçe'),
                      ('ru', '🇷🇺', 'Русский'),
                      ('en', '🇬🇧', 'English'),
                      ('de', '🇩🇪', 'Deutsch'),
                    ].map((entry) {
                      final (code, flag, name) = entry;
                      final isSelected =
                          currentLocale?.languageCode == code;
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
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                child: Row(
                  children: [
                    _GlassPill(
                      onTap: () => context.pop(),
                      child: const Icon(Icons.arrow_back_ios_new,
                          size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    ShaderMask(
                      shaderCallback: (b) =>
                          AuroraTheme.redBlueGradient.createShader(b),
                      child: Text(
                        l10n.settings_title,
                        style: const TextStyle(
                          fontFamily: 'Fraunces',
                          fontStyle: FontStyle.italic,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // İçerik
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                  children: [
                    // Doğrulama kartı
                    _VerificationCard(
                      selfieStatus: _selfieStatus,
                      onRetake: () {
                        context.push('/profile/selfie').then(
                            (_) => _loadSelfieStatus());
                      },
                    ),
                    const SizedBox(height: 24),
                    // Profil
                    _Section(
                      title: l10n.settings_profile_section,
                      items: [
                        _SettingsTile(
                          icon: Icons.edit_outlined,
                          label: l10n.settings_edit_profile,
                          onTap: () => context.push('/profile/setup'),
                        ),
                        _SettingsTile(
                          icon: Icons.add_photo_alternate_outlined,
                          label: l10n.settings_edit_photos,
                          onTap: () =>
                              context.push('/profile/photos', extra: 'edit'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Dil
                    _Section(
                      title: l10n.settings_language,
                      items: [
                        _SettingsTile(
                          icon: Icons.language_outlined,
                          label: l10n.settings_language,
                          value: _currentLanguageLabel(context),
                          onTap: () => _showLanguagePicker(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Bildirimler
                    _Section(
                      title: l10n.settings_notifications,
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Hesap
                    _Section(
                      title: l10n.settings_account,
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
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Gizlilik
                    _Section(
                      title: 'GİZLİLİK & GÜVENLİK',
                      items: [
                        _SettingsTile(
                          icon: Icons.block_outlined,
                          label: 'Engellenen kullanıcılar',
                          onTap: () => context.push('/settings/blocked-users'),
                        ),
                        _SettingsTile(
                          icon: Icons.location_on_outlined,
                          label: 'Konum izni',
                          onTap: () => openAppSettings(),
                        ),
                        _SettingsTile(
                          icon: Icons.camera_alt_outlined,
                          label: 'Kamera izni',
                          onTap: () => openAppSettings(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Destek
                    _Section(
                      title: 'DESTEK',
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
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Çıkış yap
                    _DangerButton(
                      icon: Icons.logout,
                      label: l10n.settings_logout,
                      onTap: () async {
                        try {
                          await Supabase.instance.client.auth.signOut();
                          if (context.mounted) context.go('/splash');
                        } catch (_) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Çıkış yapılamadı. Lütfen tekrar deneyin.'),
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const SizedBox(height: 10),
                    _DangerButton(
                      icon: Icons.delete_forever_outlined,
                      label: l10n.settings_delete_account,
                      onTap: () => context.push('/settings/delete-account'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _GlassPill({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AuroraTheme.glassBg,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AuroraTheme.glassBorder),
              ),
              child: child,
            ),
          ),
        ),
      );
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
                child: Text(
                  name,
                  style: const TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ),
              if (isSelected)
                ShaderMask(
                  shaderCallback: (b) =>
                      AuroraTheme.redBlueGradient.createShader(b),
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
  final List<Widget> items;
  const _Section({required this.title, required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title.toUpperCase(),
            style: AuroraTheme.monoLabel,
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
            child: Container(
              decoration: BoxDecoration(
                color: AuroraTheme.glassBg,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AuroraTheme.glassBorder),
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
                          margin: const EdgeInsets.only(left: 54),
                          color: Colors.white.withOpacity(0.06),
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
                horizontal: 16, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AuroraTheme.auroraRed.withOpacity(0.20),
                        AuroraTheme.auroraBlue.withOpacity(0.20),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: Colors.white70, size: 17),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (value != null) ...[
                  Text(
                    value!,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      color: AuroraTheme.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Icon(Icons.arrow_forward_ios,
                    size: 13,
                    color: Colors.white.withOpacity(0.25)),
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
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 15),
              decoration: BoxDecoration(
                color: AuroraTheme.auroraRed.withOpacity(0.07),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: AuroraTheme.auroraRed.withOpacity(0.25)),
              ),
              child: Row(
                children: [
                  Icon(icon,
                      color: AuroraTheme.auroraRed, size: 20),
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AuroraTheme.auroraRed,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Verification Card
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
        color = const Color(0xFFF59E0B);
      case 'approved':
        emoji = '✅';
        label = 'Doğrulanmış hesap';
        color = AuroraTheme.auroraBlue;
      case 'rejected':
        emoji = '❌';
        label = 'Selfie reddedildi — yeniden yükle';
        color = AuroraTheme.auroraRed;
        showRetake = true;
      default:
        emoji = '🔲';
        label = 'Henüz selfie yüklenmedi';
        color = Colors.white.withOpacity(0.35);
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
                const Text(
                  'Doğrulama durumu',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          if (showRetake)
            GestureDetector(
              onTap: onRetake,
              child: const Text(
                'Yeniden Yükle',
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10,
                  color: AuroraTheme.auroraRed,
                  letterSpacing: 0.5,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
