import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/gradient_italic_title.dart';

/// Bildirim tercihleri — 4 push türü toggle + sessiz saatler.
/// Tek kaynak: public.notification_preferences (send-notification bunu okur).
/// Kayıt yoksa varsayılan: tüm push açık, sessiz saatler kapalı.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> with WidgetsBindingObserver {
  bool _loading = true;
  // 30.08: sistem bildirim izni kapalıysa toggle'lar "açık" görünüp push
  // gelmiyordu — kullanıcıya kapalı olduğu ve Ayarlar yolu gösterilir.
  bool _sysNotifOff = false;
  bool _newApplication = true;
  bool _selected = true;
  bool _message = true;
  bool _match = true;
  bool _quietEnabled = false;
  TimeOfDay _quietStart = const TimeOfDay(hour: 22, minute: 0);
  TimeOfDay _quietEnd = const TimeOfDay(hour: 8, minute: 0);

  // Bu ekrana AİT yerel messenger. Snackbar buraya bağlanır; ekran ağaçtan
  // çıkınca (geri) snackbar da compositing dahil onunla gider — root'a
  // (Настройки) taşamaz, casper imkansız.
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _checkSysPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Ayarlar'dan dönüşte (resumed) banner kendini günceller — izni açan
  // kullanıcı ekrana dönünce bandı bir daha görmez.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkSysPermission();
  }

  Future<void> _checkSysPermission() async {
    try {
      final st = await Permission.notification.status;
      if (mounted) {
        setState(() => _sysNotifOff = !(st.isGranted || st.isLimited));
      }
    } catch (_) {
      // Durum okunamazsa banner gösterilmez — ekran çalışmaya devam eder
    }
  }

  TimeOfDay _parseTime(String? s, TimeOfDay fallback) {
    if (s == null) return fallback;
    final parts = s.split(':');
    if (parts.length < 2) return fallback;
    return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? fallback.hour,
        minute: int.tryParse(parts[1]) ?? fallback.minute);
  }

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _load() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    // 31.07 denetimi: korumasız await hatada spinner'ı sonsuza kilitliyordu.
    // Hata halinde varsayılanlarla açılır (kayıt yokmuş gibi) — ekran çalışır.
    Map<String, dynamic>? row;
    try {
      row = await Supabase.instance.client
          .from('notification_preferences')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
    } catch (_) {
      row = null;
    }
    if (!mounted) return;
    setState(() {
      if (row != null) {
        _newApplication = row['push_new_application'] as bool? ?? true;
        _selected = row['push_selected'] as bool? ?? true;
        _message = row['push_message'] as bool? ?? true;
        _match = row['push_match'] as bool? ?? true;
        _quietEnabled = row['quiet_hours_enabled'] as bool? ?? false;
        _quietStart =
            _parseTime(row['quiet_hours_start'] as String?, _quietStart);
        _quietEnd = _parseTime(row['quiet_hours_end'] as String?, _quietEnd);
      }
      _loading = false;
    });
  }

  Future<void> _save() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    // 31.07 denetimi: hata yutulup "Kaydedildi" gösteriliyordu — kullanıcı
    // kapattığını sandığı push'u almaya devam ediyordu. Hata görünür + UI
    // sunucudaki gerçek duruma geri döndürülür.
    try {
      if (uid == null) throw Exception('no_session');
      await Supabase.instance.client.from('notification_preferences').upsert({
        'user_id': uid,
        'push_new_application': _newApplication,
        'push_selected': _selected,
        'push_message': _message,
        'push_match': _match,
        'quiet_hours_enabled': _quietEnabled,
        'quiet_hours_start': '${_fmt(_quietStart)}:00',
        'quiet_hours_end': '${_fmt(_quietEnd)}:00',
      }, onConflict: 'user_id');
    } catch (_) {
      if (mounted) {
        _messengerKey.currentState
          ?..removeCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text(AppLocalizations.of(context)!.error_generic),
          ));
        _load(); // anahtarları sunucudaki gerçek konuma geri çek
      }
      return;
    }
    // Anlık "kaydedildi" onayı — ama casper yok: önceki snackbar silinir
    // (kuyruk birikmez), kısa süre, ekran kapanınca dispose temizler.
    if (mounted) {
      _messengerKey.currentState
        ?..removeCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: Color(0xFF34D399), size: 20),
              const SizedBox(width: 10),
              Text(AppLocalizations.of(context)!.notif_pref_saved,
                  style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Colors.white)),
            ],
          ),
          // Global SnackBar teması kullanılır (31.07: tema dışı gri + elevation
          // kaldırıldı — 6c60d9f standardı)
          duration: const Duration(milliseconds: 1600),
        ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ScaffoldMessenger(
      key: _messengerKey,
      child: Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        child: Padding(
          padding: EdgeInsets.only(
            top: MediaQueryData.fromView(View.of(context)).padding.top,
            bottom: MediaQueryData.fromView(View.of(context)).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: Colors.white, size: 20),
                      onPressed: () => Navigator.of(context).maybePop(),
                    ),
                    const SizedBox(width: 4),
                    GradientItalicTitle(l10n.settings_notification_prefs,
                        fontSize: 23),
                  ],
                ),
              ),
              if (_loading)
                const Expanded(
                    child: Center(
                        child: CircularProgressIndicator(
                            color: AuroraTheme.auroraRed)))
              else
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    children: [
                      if (_sysNotifOff) ...[
                        _card([
                          Padding(
                            padding:
                                const EdgeInsets.fromLTRB(16, 12, 16, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(Icons.notifications_off_outlined,
                                    size: 18, color: AuroraTheme.auroraRed),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(l10n.notif_system_off_banner,
                                          style: const TextStyle(
                                              fontFamily: 'Manrope',
                                              fontSize: 13,
                                              color: Colors.white,
                                              height: 1.4)),
                                      const SizedBox(height: 4),
                                      GestureDetector(
                                        onTap: openAppSettings,
                                        child: Text(
                                          l10n.perm_go_to_settings,
                                          style: const TextStyle(
                                              fontFamily: 'Manrope',
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                              color: AuroraTheme.auroraRed),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ]),
                        const SizedBox(height: 20),
                      ],
                      _sectionLabel(l10n.notif_pref_push_section),
                      _card([
                        _toggle(l10n.notif_pref_new_application,
                            l10n.notif_pref_new_application_sub, _newApplication,
                            (v) {
                          setState(() => _newApplication = v);
                          _save();
                        }),
                        _divider(),
                        _toggle(l10n.notif_pref_selected,
                            l10n.notif_pref_selected_sub, _selected, (v) {
                          setState(() => _selected = v);
                          _save();
                        }),
                        _divider(),
                        _toggle(l10n.notif_pref_message,
                            l10n.notif_pref_message_sub, _message, (v) {
                          setState(() => _message = v);
                          _save();
                        }),
                        _divider(),
                        _toggle(l10n.notif_pref_match, l10n.notif_pref_match_sub,
                            _match, (v) {
                          setState(() => _match = v);
                          _save();
                        }),
                      ]),
                      const SizedBox(height: 20),
                      _sectionLabel(l10n.settings_quiet_hours_title),
                      _card([
                        _toggle(l10n.settings_quiet_active, null, _quietEnabled,
                            (v) {
                          setState(() => _quietEnabled = v);
                          _save();
                        }),
                        if (_quietEnabled) ...[
                          _divider(),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            child: Row(
                              children: [
                                Expanded(
                                    child: _timeButton(l10n.settings_quiet_start,
                                        _quietStart, (t) {
                                  setState(() => _quietStart = t);
                                  _save();
                                })),
                                const SizedBox(width: 12),
                                Expanded(
                                    child: _timeButton(l10n.settings_quiet_end,
                                        _quietEnd, (t) {
                                  setState(() => _quietEnd = t);
                                  _save();
                                })),
                              ],
                            ),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
        child: Text(t.toUpperCase(),
            style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 11,
                letterSpacing: 1.5,
                color: Colors.white38)),
      );

  Widget _card(List<Widget> children) => ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: AuroraTheme.glassBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AuroraTheme.glassBorder),
          ),
          child: Column(children: children),
        ),
      );

  Widget _divider() =>
      Divider(height: 1, color: Colors.white.withOpacity(0.06), indent: 16, endIndent: 16);

  Widget _toggle(
          String label, String? sub, bool value, ValueChanged<bool> onChanged) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          color: Colors.white)),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub,
                        style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            color: Colors.white38)),
                  ],
                ],
              ),
            ),
            Switch(
              value: value,
              activeColor: AuroraTheme.auroraRed,
              onChanged: onChanged,
            ),
          ],
        ),
      );

  Widget _timeButton(String label, TimeOfDay time, ValueChanged<TimeOfDay> onPick) =>
      InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () async {
          final t = await showTimePicker(context: context, initialTime: time);
          if (t != null) onPick(t);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AuroraTheme.glassStrong,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AuroraTheme.glassBorder),
          ),
          child: Column(
            children: [
              Text(label,
                  style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 11,
                      color: Colors.white38)),
              const SizedBox(height: 4),
              Text(_fmt(time),
                  style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 18,
                      color: Colors.white)),
            ],
          ),
        ),
      );
}
