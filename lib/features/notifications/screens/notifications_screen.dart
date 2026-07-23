import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/aurora_theme.dart';
import '../../../core/providers/locale_provider.dart';
import '../../../core/utils/selfie_reason_l10n.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/gradient_italic_title.dart';
import '../providers/notifications_provider.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import '../../../core/services/photo_focus.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() =>
      _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  RealtimeChannel? _channel;
  List<NotificationItem>? _localItems; // dismiss için lokal kopya
  bool _isMarkingAll = false;
  bool _refreshedOnOpen = false;

  @override
  void initState() {
    super.initState();
    _subscribeRealtime();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ekran her açılışta taze liste çeker — çan rozeti provider'ı canlı
    // tuttuğu için cache açılış anına takılı kalıyordu (16.07 fix).
    // initState içinde ref kullanımı Flutter'ca yasak (ilk açılış çökmesi,
    // 16.07); ilk didChangeDependencies build'den hemen önce çalışır —
    // davranış birebir aynı kalır.
    if (!_refreshedOnOpen) {
      _refreshedOnOpen = true;
      ref.invalidate(notificationsProvider);
    }
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
          callback: (_) {
            _localItems = null; // lokal kopya taze veriyi maskelemesin
            ref.invalidate(notificationsProvider);
          },
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
          callback: (_) {
            _localItems = null; // lokal kopya taze veriyi maskelemesin
            ref.invalidate(notificationsProvider);
          },
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.notif_pref_all_read),
            behavior: SnackBarBehavior.floating,
            backgroundColor: AuroraTheme.glassStrong,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.error_with_detail(AppLocalizations.of(context)!.error_generic),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isMarkingAll = false);
    }
  }

  Future<void> _markRead(List<String> ids) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .update({'read_at': DateTime.now().toIso8601String()})
          .inFilter('id', ids)
          .isFilter('read_at', null);
      if (!mounted) return; // fire-and-forget: ekran kapanmış olabilir
      setState(() => _localItems = null);
      ref.invalidate(notificationsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.error_with_detail(AppLocalizations.of(context)!.error_generic),
            ),
          ),
        );
      }
    }
  }

  Future<void> _delete(List<String> ids) async {
    try {
      await Supabase.instance.client
          .from('notifications')
          .delete()
          .inFilter('id', ids);
      ref.invalidate(notificationsProvider);
      setState(() => _localItems = null);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.error_with_detail(AppLocalizations.of(context)!.error_generic),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(photoFocusProvider); // yüz odak haritası — gelince rebuild
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
                      child: const Icon(
                        Icons.arrow_back_ios_new,
                        size: 16,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Başlık
                    Flexible(
                      child: Builder(
                        builder: (ctx) => GradientItalicTitle(
                          AppLocalizations.of(ctx)!.notifications_title,
                          fontSize: 23,
                        ),
                      ),
                    ),
                    const Spacer(),
                    // Tümünü oku
                    GestureDetector(
                      onTap: _isMarkingAll ? null : _markAllRead,
                      child: Text(
                        AppLocalizations.of(
                          context,
                        )!.notifications_mark_all_read,
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
                          AuroraTheme.auroraRed,
                        ),
                      ),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text(
                      AppLocalizations.of(
                        context,
                      )!.notifications_error(AppLocalizations.of(context)!.error_generic),
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        color: AuroraTheme.textSecondary,
                      ),
                    ),
                  ),
                  data: (notifications) {
                    // Provider'dan gelen veriyi lokal kopyaya aktar
                    // (zaten varsa dokunma — dismiss sırasında lokal kopya kullanılıyor)
                    _localItems ??= List.of(notifications);
                    final items = _localItems!;
                    if (items.isEmpty) return const _EmptyState();
                    return RefreshIndicator(
                      color: AuroraTheme.auroraRed,
                      backgroundColor: AuroraTheme.bgDeep,
                      onRefresh: () async {
                        setState(() => _localItems = null);
                        ref.invalidate(notificationsProvider);
                        await ref.read(notificationsProvider.future);
                      },
                      child: ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
                        itemCount: items.length,
                        itemBuilder: (ctx, i) {
                          final n = items[i];
                          return _NotifTile(
                            item: n,
                            locale:
                                ref.watch(localeProvider)?.languageCode ?? 'tr',
                            onTap: () {
                              // Okundu işareti arka planda — geçişi ağ turu bekletmesin.
                              _markRead(n.allIds);
                              final path = n.routePath;
                              // Chat'e giderken bildirimin zaten bildiği isim+foto
                              // elden geçir — başlık sunucu cevabını beklemeden dolu
                              // açılır (mesaj listesiyle aynı desen, yaş sonradan gelir).
                              if (path.startsWith('/chat/') &&
                                  n.actorName != null) {
                                ctx.push(
                                  path,
                                  extra: {
                                    'name': n.actorName,
                                    'photoUrl': n.actorPhotoUrl,
                                  },
                                );
                              } else if (path == '/feed') {
                                // Shell-branch rotası push edilmez (siyah ekran
                                // bug'ı, 16.07) — sekme geçişiyle gidilir.
                                ctx.go(path);
                              } else {
                                ctx.push(path);
                              }
                            },
                            onDismiss: n.isRead
                                ? () {
                                    setState(
                                      () => _localItems!.removeWhere(
                                        (x) => x.id == n.id,
                                      ),
                                    );
                                    _delete(n.allIds);
                                  }
                                : null,
                          );
                        },
                      ),
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
  final name = item.actorName ?? '';
  switch (item.type) {
    case 'new_application':
      return l.notif_type_new_application_title;
    case 'selected':
      return l.notif_type_selected_title;
    case 'not_selected':
      return l.notif_type_not_selected_title;
    case 'new_message':
      return l.notif_type_new_message_title;
    case 'selfie_approved':
      return l.notif_type_selfie_approved_title;
    case 'premium_activated':
      return l.notif_type_premium_activated_title;
    case 'selfie_rejected':
      return l.notif_type_selfie_rejected_title;
    case 'meeting_reminder':
      return l.notif_type_meeting_reminder_title;
    case 'feedback_request':
      return l.notif_type_feedback_request_title;
    case 'selection_reminder':
      return l.notif_type_selection_reminder_title;
    default:
      return name.isNotEmpty ? name : item.type;
  }
}

String _notifBody(NotificationItem item, AppLocalizations l) {
  final name = item.actorName ?? '';
  switch (item.type) {
    // Aktör adı boşsa (silinmiş kullanıcı / eski kayıt) "… от" gibi sarkık
    // metin kalmasın — isimsiz gövde kullanılır.
    case 'new_application':
      return name.isEmpty
          ? l.notif_type_new_application_body_noname
          : l.notif_type_new_application_body(name);
    case 'selected':
      return l.notif_type_selected_body;
    case 'not_selected':
      return l.notif_type_not_selected_body;
    case 'new_message':
      return name.isEmpty
          ? l.notif_type_new_message_body_noname
          : l.notif_type_new_message_body(name);
    case 'selfie_approved':
      return l.notif_type_selfie_approved_body;
    case 'premium_activated':
      // Tarih sunucudan DD.MM.YYYY gelir; payload'sız eski kayıt için tarihsiz gövde
      final until = item.payload['until_date'] as String?;
      return until == null
          ? l.notif_type_premium_activated_body_nodate
          : l.notif_type_premium_activated_body(until);
    case 'selfie_rejected':
      // Preset red sebebi (slug) kullanıcının dilinde gösterilir (16.07)
      final reason = selfieReasonL10n(l, item.payload['reason'] as String?);
      return reason == null
          ? l.notif_type_selfie_rejected_body
          : '$reason — ${l.notif_type_selfie_rejected_body}';
    case 'meeting_reminder':
      return l.notif_type_meeting_reminder_body;
    case 'feedback_request':
      return l.notif_type_feedback_request_body;
    case 'selection_reminder':
      return l.notif_type_selection_reminder_body;
    default:
      return item.body;
  }
}

/// Instagram tarzı satırda avatarın yanında gösterilecek isimsiz aksiyon metni
/// ("{isim}" + bu metin birleşip tek satırda gösteriliyor). Sadece actor_id
/// olan (kişiye özel) türler için tanımlı — sistem bildirimlerinde null döner.
String? _notifActionText(NotificationItem item, AppLocalizations l) {
  // RU fiil çekimi aktörün cinsiyetine göre; bilinmiyorsa nötr "(а)" hali
  final g = item.actorGender ?? 'other';
  switch (item.type) {
    case 'new_message':
      return l.notif_action_new_message(g);
    case 'new_application':
      return l.notif_action_new_application(g);
    case 'selected':
      return l.notif_action_selected(g);
    case 'not_selected':
      return l.notif_action_not_selected(g);
    default:
      return null;
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

  Widget _buildLeading(List<Color> colors) {
    final hasActor = item.actorName != null && item.actorName!.isNotEmpty;
    if (hasActor) {
      final ring = item.isRead
          ? AuroraTheme.glassBorder
          : colors[0].withOpacity(0.7);
      final photoUrl = item.actorPhotoUrl;
      return Container(
        width: 38,
        height: 38,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: ring, width: item.isRead ? 1 : 2),
        ),
        child: ClipOval(
          child: photoUrl != null
              ? CachedNetworkImage(
                  imageUrl: photoUrl,
                  fit: BoxFit.cover,
                  memCacheWidth: 156,
                  fadeInDuration: const Duration(milliseconds: 150),
                  placeholder: (_, __) =>
                      _DefaultActorAvatar(name: item.actorName!),
                  alignment: PhotoFocus.of(
                    photoUrl,
                    fallback: Alignment.center,
                  ),
                  errorWidget: (_, __, ___) =>
                      _DefaultActorAvatar(name: item.actorName!),
                )
              : _DefaultActorAvatar(name: item.actorName!),
        ),
      );
    }
    // Sistem bildirimi (actor yok) — Aurora glow icon
    return Container(
      width: 38,
      height: 38,
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
          child: Icon(item.iconData, color: Colors.white, size: 19),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, String? actionText) {
    final l10n = AppLocalizations.of(context)!;
    if (actionText != null &&
        item.actorName != null &&
        item.actorName!.isNotEmpty) {
      // Instagram tarzı: "İsim aksiyon metni" tek satırda, isim kalın.
      final children = <Widget>[
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: item.actorName,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: Colors.white,
                ),
              ),
              TextSpan(
                text: ' $actionText',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w400,
                  fontSize: 13,
                  color: item.isRead
                      ? Colors.white.withOpacity(0.85)
                      : Colors.white,
                ),
              ),
            ],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ];
      // Yeni mesajlarda ikinci satır olarak mesaj önizlemesi anlamlı
      // (isim+aksiyon zaten "mesaj gönderdi" dediği için tekrar olmaz).
      if (item.type == 'new_message' && item.body.isNotEmpty) {
        // Gruplanmışsa: "5 новых сообщений · <son mesaj>" (temsilci en yenisi)
        final preview = item.groupCount > 1
            ? '${l10n.notif_grouped_messages(item.groupCount)} · ${item.body}'
            : item.body;
        children.addAll([
          const SizedBox(height: 3),
          Text(
            preview,
            style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 12,
              color: AuroraTheme.textSecondary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ]);
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      );
    }

    // Sistem bildirimi — eski iki satırlı (başlık/gövde) tasarım.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _notifTitle(item, l10n),
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: item.isRead ? Colors.white.withOpacity(0.85) : Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 3),
        Text(
          _notifBody(item, l10n),
          style: TextStyle(
            fontFamily: 'Manrope',
            fontSize: 12,
            color: AuroraTheme.textSecondary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = _iconGradient();
    final accentColor = item.isRead
        ? AuroraTheme.glassBorder
        : colors[0].withOpacity(0.5);
    final actionText = _notifActionText(item, AppLocalizations.of(context)!);
    // Okunmuş bildirim hafif soluk — okundu hissi kalsın ama liste komple
    // "sönük" görünmesin (13.07: 0.55 tüm ekranı ölü gösteriyordu → 0.78).
    final tile = Opacity(
      opacity: item.isRead ? 0.78 : 1.0,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: GestureDetector(
          onTap: onTap,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AuroraTheme.radiusInfoCard),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: item.isRead
                      ? AuroraTheme.glassBg
                      : colors[0].withOpacity(0.06),
                  borderRadius: BorderRadius.circular(
                    AuroraTheme.radiusInfoCard,
                  ),
                  border: Border.all(color: accentColor),
                ),
                child: Row(
                  children: [
                    _buildLeading(colors),
                    const SizedBox(width: 12),
                    Expanded(child: _buildContent(context, actionText)),
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
            borderRadius: BorderRadius.circular(AuroraTheme.radiusInfoCard),
          ),
          child: const Icon(
            Icons.delete_outline,
            color: AuroraTheme.auroraRed,
            size: 24,
          ),
        ),
        onDismissed: (_) => onDismiss!(),
        child: tile,
      );
    }
    return tile;
  }
}

class _DefaultActorAvatar extends StatelessWidget {
  final String name;
  const _DefaultActorAvatar({required this.name});

  @override
  Widget build(BuildContext context) => Container(
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: AuroraTheme.redBlueGradient,
    ),
    child: Center(
      child: Text(
        name.isNotEmpty ? name[0].toUpperCase() : '?',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  );
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
