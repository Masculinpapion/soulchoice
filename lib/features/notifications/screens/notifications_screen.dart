import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState
    extends ConsumerState<NotificationsScreen> {
  RealtimeChannel? _channel;

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
    await Supabase.instance.client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('user_id', uid)
        .isFilter('read_at', null);
    ref.invalidate(notificationsProvider);
  }

  Future<void> _markRead(String id) async {
    await Supabase.instance.client
        .from('notifications')
        .update({'read_at': DateTime.now().toIso8601String()})
        .eq('id', id)
        .isFilter('read_at', null);
    ref.invalidate(notificationsProvider);
  }

  Future<void> _delete(String id) async {
    await Supabase.instance.client
        .from('notifications')
        .delete()
        .eq('id', id);
    ref.invalidate(notificationsProvider);
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
                      shaderCallback: (b) =>
                          AuroraTheme.redBlueGradient.createShader(b),
                      child: const Text(
                        'Bildirimler',
                        style: TextStyle(
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
                    TextButton(
                      onPressed: _markAllRead,
                      child: const Text(
                        'Tümünü oku',
                        style: TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: AuroraTheme.auroraRed,
                          letterSpacing: 0.5,
                        ),
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
                      'Hata: $e',
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          color: AuroraTheme.textSecondary),
                    ),
                  ),
                  data: (notifications) {
                    if (notifications.isEmpty) {
                      return const _EmptyState();
                    }
                    return ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                      itemCount: notifications.length,
                      itemBuilder: (ctx, i) {
                        final n = notifications[i];
                        return _NotifTile(
                          item: n,
                          onTap: () async {
                            await _markRead(n.id);
                            if (ctx.mounted) ctx.push(n.routePath);
                          },
                          onDismiss:
                              n.isRead ? () => _delete(n.id) : null,
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

class _NotifTile extends StatelessWidget {
  final NotificationItem item;
  final VoidCallback onTap;
  final VoidCallback? onDismiss;

  const _NotifTile({
    required this.item,
    required this.onTap,
    this.onDismiss,
  });

  // Bildirim tipine göre gradient renk
  List<Color> _iconGradient() {
    switch (item.type) {
      case 'application':
        return [AuroraTheme.auroraRed, const Color(0xFFFF6B7A)];
      case 'message':
        return [AuroraTheme.auroraBlue, const Color(0xFF74B3F5)];
      case 'match':
        return [AuroraTheme.auroraGold, const Color(0xFFFFD700)];
      default:
        return [AuroraTheme.auroraViolet, AuroraTheme.auroraBlue];
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = _iconGradient();
    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(AuroraTheme.radiusInfoCard),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: item.isRead
                    ? AuroraTheme.glassBg
                    : AuroraTheme.auroraRed.withOpacity(0.07),
                borderRadius:
                    BorderRadius.circular(AuroraTheme.radiusInfoCard),
                border: Border.all(
                  color: item.isRead
                      ? AuroraTheme.glassBorder
                      : AuroraTheme.auroraRed.withOpacity(0.35),
                ),
              ),
              child: Row(
                children: [
                  // Icon container — gradient bg
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: colors[0].withOpacity(0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        item.iconData,
                        color: Colors.white,
                        size: 22,
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
                          item.title,
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
                          item.body,
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
                    timeago.format(item.createdAt, locale: 'tr'),
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
            const Text(
              'Henüz bildirimin yok',
              style: TextStyle(
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
