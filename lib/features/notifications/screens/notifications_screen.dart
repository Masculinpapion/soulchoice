import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/aurora_theme.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../providers/notifications_provider.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends ConsumerState<NotificationsScreen> {
  RealtimeChannel? _channel;
  List<NotificationItem>? _localItems; // dismiss için lokal kopya
  bool _isMarkingAll = false;

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (uid.isEmpty) return;
    _channel = Supabase.instance.client
        .channel('notifications:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (_) => ref.invalidate(notificationsProvider),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'notifications',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user_id',
            value: uid,
          ),
          callback: (_) => ref.invalidate(notificationsProvider),
        )
        .subscribe();
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  Future<void> _markAllRead() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    setState(() => _isMarkingAll = true);
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('user_id', uid)
          .isFilter('read_at', null);
      ref.invalidate(notificationsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.error_with_detail(e.toString()))),
        );
      }
    } finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }

  Future<void> _markRead(String id) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .eq('id', id)
          .isFilter('read_at', null);
      setState(() => _localItems = null);
      ref.invalidate(notificationsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.error_with_detail(e.toString()))),
        );
      }
    }
  }

  Future<void> _delete(String id) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .delete()
          .eq('id', id);
      ref.invalidate(notificationsProvider);
      setState(() => _localItems = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.error_with_detail(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifAsync = ref.watch(notificationsProvider);
    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // Başlık satırı
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 8),
                child: Row(
                  children: [
                    // Geri butonu
                    _GlassPill(
                      onTap: () => context.pop(),
                      child: const Icon(Icons.arrow_back_ios_new,
                          size: 16, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    // Başlık
                    ShaderMask(
                      blendMode: BlendMode.srcIn,
                      shaderCallback: (b) =>
                          AuroraTheme.redBlueGradient.createShader(b),
                      child: Text(
                        AppLocalizations.of(context)!.notifications_title,
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
                    const Spacer(),
                    // Tümünü oku
                    GestureDetector(
                      onTap: _isMarkingAll ? null : _markAllRead,
                      child: Text(
                        AppLocalizations.of(context)!.notifications_mark_all_read,
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AuroraTheme.auroraRed,
                          letterSpacing: 0.3,
                        ),
                        maxLines: 2,
                        textAlign: TextAlign.right,
                      ),
                    ),
                  ],
                ),
              ),
              // Liste
              Expanded(
                child: notifAsync.when(
                  loading: () => Center(
                    child: SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(
                            AuroraTheme.auroraRed),
                      ),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      AppLocalizations.of(context)!.notifications_error(e.toString()),
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          color: AuroraTheme.textSecondary),
                    ),
                  ),
                  data: (notifications) {
                    // Provider'dan gelen veriyi lokal kopyaya aktar
                    // (zaten varsa dokunma — dismiss sırasında lokal kopya kullanılıyor)
                    _localItems ??= List.of(notifications);
                    final items = _localItems!;
                    if (items.isEmpty) return const _EmptyState();
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      itemCount: items.length,
                      itemBuilder: (ctx, i) {
                        final n = items[i];
                        return _NotifTile(
                          item: n,
                          locale: ref.watch(localeProvider)?.languageCode ?? 'tr',
                          onTap: () async {
                            await _markRead(n.id);
                            if (ctx.mounted) ctx.push(n.routePath);
                          },
                          onDismiss: n.isRead ? () {
                            setState(() => _localItems!.removeWhere((x) => x.id == n.id));
                            _delete(n.id);
                          } : null,
                        );
                      },
                    );
                  },
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
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
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
// Notification Tile — Aurora glass card
// ─────────────────────────────────────────────────────────────────────────────

String _notifTitle(NotificationItem item, AppLocalizations l) {
  final name = (item.payload['name'] ?? item.payload['applicant_name'] ?? item.payload['sender_name'] ?? '') as String;
  switch (item.type) {
    case 'new_application': return l.notif_type_new_application_title;
    case 'selected':        return l.notif_type_selected_title;
    case 'not_selected':    return l.notif_type_not_selected_title;
    case 'new_message':     return l.notif_type_new_message_title;
    case 'selfie_approved': return l.notif_type_selfie_approved_title;
    case 'selfie_rejected': return l.notif_type_selfie_rejected_title;
    case 'meeting_reminder':return l.notif_type_meeting_reminder_title;
    case 'feedback_request':return l.notif_type_feedback_request_title;
    default:                return name.isNotEmpty ? name : item.type;
  }
}

String _notifBody(NotificationItem item, AppLocalizations l) {
  final name = (item.payload['name'] ?? item.payload['applicant_name'] ?? item.payload['sender_name'] ?? '') as String;
  switch (item.type) {
    case 'new_application': return l.notif_type_new_application_body(name);
    case 'selected':        return l.notif_type_selected_body;
    case 'not_selected':    return l.notif_type_not_selected_body;
    case 'new_message':     return l.notif_type_new_message_body(name);
    case 'selfie_approved': return l.notif_type_selfie_approved_body;
    case 'selfie_rejected': return l.notif_type_selfie_rejected_body;
    case 'meeting_reminder':return l.notif_type_meeting_reminder_body;
    case 'feedback_request':return l.notif_type_feedback_request_body;
    default:                return item.body;
  }
}

class _NotifTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;
  final String locale;

  const _NotifTile({
    required this.item,
    required this.onTap,
    required this.locale,
    this.onDismiss,
  });

  List<Color> _iconGradient() {
    switch (item.type) {
      case 'new_application':
        return [AuroraTheme.auroraRed, const Color(0xFFFF6B7A)];
      case 'selected':
        return [AuroraTheme.auroraGold, const Color(0xFFFFD700)];
      case 'not_selected':
        return [AuroraTheme.auroraViolet, AuroraTheme.auroraBlue];
      case 'new_message':
        return [AuroraTheme.auroraBlue, const Color(0xFF74B3F5)];
      case 'selfie_approved':
        return [AuroraTheme.auroraGold, const Color(0xFFFFEA70)];
      case 'selfie_rejected':
        return [AuroraTheme.auroraRed, AuroraTheme.auroraViolet];
      case 'meeting_reminder':
        return [AuroraTheme.auroraBlue, AuroraTheme.auroraViolet];
      case 'feedback_request':
        return [AuroraTheme.auroraViolet, const Color(0xFFA78BFA)];
      default:
        return [AuroraTheme.auroraViolet, AuroraTheme.auroraBlue];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _iconGradient();
    final accentColor = item.isRead ? AuroraTheme.glassBorder : colors[0].withOpacity(0.5);
    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AuroraTheme.radiusInfoCard),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: item.isRead
                    ? AuroraTheme.glassBg
                    : colors[0].withOpacity(0.06),
                borderRadius: BorderRadius.circular(AuroraTheme.radiusInfoCard),
                border: Border.all(color: accentColor),
              ),
              child: Row(
                children: [
                  // Aurora glow icon — daire bg + ShaderMask gradient icon
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: colors[0].withOpacity(0.12),
                      border: Border.all(color: colors[0].withOpacity(0.28)),
                      boxShadow: [
                        BoxShadow(
                          color: colors[0].withOpacity(0.30),
                          blurRadius: 14,
                          spreadRadius: 0,
                        ),
                      ],
                    ),
                    child: Center(
                      child: ShaderMask(
                        blendMode: BlendMode.srcIn,
                        shaderCallback: (b) => LinearGradient(
                          colors: colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ).createShader(b),
                        child: Icon(item.iconData, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // İçerik
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _notifTitle(item, AppLocalizations.of(context)!),
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: item.isRead
                                ? Colors.white.withOpacity(0.85)
                                : Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _notifBody(item, AppLocalizations.of(context)!),
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            color: AuroraTheme.textSecondary,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Zaman
                  Text(
                    timeago.format(item.createdAt, locale: locale),
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 9,
                      color: AuroraTheme.textMuted,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    if (onDismiss != null) {
      return Dismissible(
        key: Key(item.id),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AuroraTheme.auroraRed.withOpacity(0.15),
            borderRadius:
                BorderRadius.circular(AuroraTheme.radiusInfoCard),
          ),
          child: const Icon(Icons.delete_outline,
              color: AuroraTheme.auroraRed, size: 24),
        ),
        onDismissed: (_) => onDismiss!(),
        child: tile,
      );
    }
    return tile;
  }
}

// ── Empty State ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🔔', style: TextStyle(fontSize: 56)),
            const SizedBox(height: 20),
            Text(
              AppLocalizations.of(context)!.notifications_empty,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                fontSize: 20,
                color: Colors.white,
              ),
            ),
          ],
        ),
      );
}

