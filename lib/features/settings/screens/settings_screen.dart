import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../feed/providers/invitations_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _selfieStatus = 'none';
  String _showGender = 'opposite';
  int _minAge = 21;
  int _maxAge = 60;
  bool _quietEnabled = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 8, minute: 0);

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadQuietHours();
  }

  Future<void> _loadUserData() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final row = await Supabase.instance.client
        .from('users')
        .select('selfie_status, show_gender, min_age, max_age')
        .eq('id', uid)
        .maybeSingle();
    if (mounted) {
      setState(() {
        _selfieStatus = row?['selfie_status'] as String? ?? 'none';
        _showGender = row?['show_gender'] as String? ?? 'opposite';
        _minAge = row?['min_age'] as int? ?? 21;
        _maxAge = row?['max_age'] as int? ?? 60;
      });
    }
  }

  Future<void> _loadSelfieStatus() => _loadUserData();

  Future<void> _loadQuietHours() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _quietEnabled = prefs.getBool('quiet_enabled') ?? false;
      _quietStart = TimeOfDay(
        hour: prefs.getInt('quiet_start_h') ?? 22,
        minute: prefs.getInt('quiet_start_m') ?? 0,
      );
      _quietEnd = TimeOfDay(
        hour: prefs.getInt('quiet_end_h') ?? 8,
        minute: prefs.getInt('quiet_end_m') ?? 0,
      );
    });
  }

  void _showComingSoon(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuroraTheme.bgDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontFamily: 'Fraunces', fontStyle: FontStyle.italic, color: Colors.white, fontSize: 18)),
        content: const Text('Bu özellik yakında geliyor.', style: TextStyle(fontFamily: 'Manrope', color: Colors.white54, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tamam', style: TextStyle(fontFamily: 'JetBrainsMono', color: AuroraTheme.auroraRed)),
          ),
        ],
      ),
    );
  }

  Future<void> _showAbout(BuildContext context) async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuroraTheme.bgDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('SoulChoice', style: TextStyle(fontFamily: 'Fraunces', fontStyle: FontStyle.italic, color: Colors.white, fontSize: 22)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('v${info.version} (${info.buildNumber})', style: const TextStyle(fontFamily: 'JetBrainsMono', color: Colors.white38, fontSize: 12)),
            const SizedBox(height: 8),
            const Text('Premium sosyal davet uygulaması.', style: TextStyle(fontFamily: 'Manrope', color: Colors.white54, fontSize: 13)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Tamam', style: TextStyle(fontFamily: 'JetBrainsMono', color: AuroraTheme.auroraRed)),
          ),
        ],
      ),
    );
  }

  Future<void> _downloadData(BuildContext context) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final client = Supabase.instance.client;
    try {
      final results = await Future.wait<dynamic>([
        client.from('users').select('name, age, gender, bio, job, education, interests').eq('id', uid).maybeSingle(),
        client.from('invitations').select('id, title, category, status, created_at').eq('owner_id', uid),
        client.from('applications').select('id, invitation_id, status, created_at').eq('applicant_id', uid),
      ]);
      final data = {
        'profile': results[0],
        'invitations': results[1],
        'applications': results[2],
        'exported_at': DateTime.now().toIso8601String(),
      };
      final json = const JsonEncoder.withIndent('  ').convert(data);
      await Share.share(json, subject: 'SoulChoice Veri Dışa Aktarma');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AuroraTheme.auroraRed),
        );
      }
    }
  }

  Future<void> _showQuietHoursPicker(BuildContext context) async {
    bool localEnabled = _quietEnabled;
    TimeOfDay localStart = _quietStart;
    TimeOfDay localEnd = _quietEnd;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D12).withOpacity(0.92),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: AuroraTheme.glassBorder)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(width: 36, height: 4, decoration: BoxDecoration(color: AuroraTheme.glassBorder, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(height: 20),
                    const Text('Gece sessizliği', style: TextStyle(fontFamily: 'Fraunces', fontStyle: FontStyle.italic, fontSize: 20, color: Colors.white)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Aktif', style: TextStyle(fontFamily: 'Manrope', color: Colors.white, fontSize: 14)),
                        Switch(
                          value: localEnabled,
                          activeColor: AuroraTheme.auroraRed,
                          onChanged: (v) => setModalState(() => localEnabled = v),
                        ),
                      ],
                    ),
                    if (localEnabled) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _TimeButton(
                              label: 'Başlangıç',
                              time: localStart,
                              onTap: () async {
                                final t = await showTimePicker(context: ctx, initialTime: localStart);
                                if (t != null) setModalState(() => localStart = t);
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _TimeButton(
                              label: 'Bitiş',
                              time: localEnd,
                              onTap: () async {
                                final t = await showTimePicker(context: ctx, initialTime: localEnd);
                                if (t != null) setModalState(() => localEnd = t);
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('quiet_enabled', localEnabled);
                          await prefs.setInt('quiet_start_h', localStart.hour);
                          await prefs.setInt('quiet_start_m', localStart.minute);
                          await prefs.setInt('quiet_end_h', localEnd.hour);
                          await prefs.setInt('quiet_end_m', localEnd.minute);
                          if (mounted) setState(() {
                            _quietEnabled = localEnabled;
                            _quietStart = localStart;
                            _quietEnd = localEnd;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AuroraTheme.auroraRed,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Kaydet', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAgeRangePicker(BuildContext context) {
    int localMin = _minAge;
    int localMax = _maxAge;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setModalState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D12).withOpacity(0.92),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: AuroraTheme.glassBorder)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36, height: 4,
                      decoration: BoxDecoration(
                        color: AuroraTheme.glassBorder,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Yaş aralığı',
                      style: TextStyle(
                        fontFamily: 'Fraunces',
                        fontStyle: FontStyle.italic,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$localMin — $localMax yaş',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 13,
                        color: AuroraTheme.textMuted,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 16),
                    RangeSlider(
                      values: RangeValues(localMin.toDouble(), localMax.toDouble()),
                      min: 21,
                      max: 60,
                      divisions: 39,
                      activeColor: AuroraTheme.auroraRed,
                      inactiveColor: AuroraTheme.glassBorder,
                      labels: RangeLabels('$localMin', '$localMax'),
                      onChanged: (v) => setModalState(() {
                        localMin = v.start.round();
                        localMax = v.end.round();
                      }),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.of(ctx).pop();
                          final uid = Supabase.instance.client.auth.currentUser?.id;
                          if (uid == null) return;
                          await Supabase.instance.client
                              .from('users')
                              .update({'min_age': localMin, 'max_age': localMax})
                              .eq('id', uid);
                          if (mounted) {
                            setState(() { _minAge = localMin; _maxAge = localMax; });
                            ref.invalidate(invitationsProvider);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AuroraTheme.auroraRed,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text('Kaydet', style: TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w700, fontSize: 15, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _currentLanguageLabel(BuildContext context) {
    final locale = ref.read(localeProvider);
    if (locale == null) {
      return AppLocalizations.of(context)!.settings_language_system;
    }
    switch (locale.languageCode) {
      case 'ru': return 'Русский';
      case 'en': return 'English';
      default:
        return AppLocalizations.of(context)!.settings_language_system;
    }
  }

  static const _showGenderOptions = [
    ('opposite', 'Karşı cinsiyet'),
    ('all', 'Hepsi'),
    ('female', 'Kadınlar'),
    ('male', 'Erkekler'),
  ];

  String _showGenderLabel() {
    return _showGenderOptions
        .firstWhere((o) => o.$1 == _showGender, orElse: () => _showGenderOptions.first)
        .$2;
  }

  void _showShowGenderPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D12).withOpacity(0.85),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                border: Border(top: BorderSide(color: AuroraTheme.glassBorder)),
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
                    const Text(
                      'Gösterim tercihi',
                      style: TextStyle(
                        fontFamily: 'Fraunces',
                        fontStyle: FontStyle.italic,
                        fontSize: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ..._showGenderOptions.map((opt) => _LangTile(
                          flag: opt.$1 == 'opposite'
                              ? '⇄'
                              : opt.$1 == 'all'
                                  ? '👥'
                                  : opt.$1 == 'female'
                                      ? '♀'
                                      : '♂',
                          name: opt.$2,
                          isSelected: _showGender == opt.$1,
                          onTap: () async {
                            Navigator.of(context).pop();
                            final uid = Supabase.instance.client.auth.currentUser?.id;
                            if (uid == null) return;
                            await Supabase.instance.client
                                .from('users')
                                .update({'show_gender': opt.$1})
                                .eq('id', uid);
                            if (mounted) {
                              setState(() => _showGender = opt.$1);
                              ref.invalidate(invitationsProvider);
                            }
                          },
                        )),
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
                      ('ru', '🇷🇺', 'Русский'),
                      ('en', '🇬🇧', 'English'),
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
                        _SettingsTile(
                          icon: Icons.visibility_outlined,
                          label: 'Gösterim tercihi',
                          value: _showGenderLabel(),
                          onTap: () => _showShowGenderPicker(context),
                        ),
                        _SettingsTile(
                          icon: Icons.people_outline,
                          label: 'Yaş aralığı',
                          value: '$_minAge–$_maxAge',
                          onTap: () => _showAgeRangePicker(context),
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
                          onTap: () => _showComingSoon(context, l10n.settings_notification_prefs),
                        ),
                        _SettingsTile(
                          icon: Icons.do_not_disturb_on_outlined,
                          label: l10n.settings_do_not_disturb,
                          value: _quietEnabled
                              ? '${_quietStart.hour.toString().padLeft(2, '0')}:${_quietStart.minute.toString().padLeft(2, '0')} – ${_quietEnd.hour.toString().padLeft(2, '0')}:${_quietEnd.minute.toString().padLeft(2, '0')}'
                              : null,
                          onTap: () => _showQuietHoursPicker(context),
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
                          onTap: () => _showComingSoon(context, l10n.settings_active_devices),
                        ),
                        _SettingsTile(
                          icon: Icons.download_outlined,
                          label: l10n.settings_download_data,
                          onTap: () => _downloadData(context),
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
                          onTap: () => launchUrl(Uri.parse('mailto:support@soulchoice.app')),
                        ),
                        _SettingsTile(
                          icon: Icons.info_outline,
                          label: 'Hakkında',
                          onTap: () => _showAbout(context),
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

class _TimeButton extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onTap;
  const _TimeButton({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AuroraTheme.glassBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AuroraTheme.glassBorder),
          ),
          child: Column(
            children: [
              Text(label, style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 9, color: Colors.white38, letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text(
                '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                style: const TextStyle(fontFamily: 'Fraunces', fontStyle: FontStyle.italic, fontSize: 20, color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
}
