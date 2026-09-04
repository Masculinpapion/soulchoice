import 'package:soulchoice/core/services/error_reporter.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/gradient_italic_title.dart';
import '../../../shared/widgets/sc_button.dart';
import '../providers/matches_provider.dart';
import '../../../core/providers/locale_provider.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import '../../../core/services/photo_focus.dart';

class MessagesListScreen extends ConsumerStatefulWidget {
  const MessagesListScreen({super.key});

  @override
  ConsumerState<MessagesListScreen> createState() =>
      _MessagesListScreenState();
}

class _MessagesListScreenState extends ConsumerState<MessagesListScreen>
    with WidgetsBindingObserver {
  RealtimeChannel? _channel;
  bool _channelDropped = false;
  // 03.09 (kalite teşhisi B2): mesaj aboneliği match_id in (sohbetlerim) ile
  // SUNUCUDA süzülür; sohbet listesi değişince kanal yenilenir.
  RealtimeChannel? _msgChannel;
  List<String> _msgIds = const [];
  ProviderSubscription<AsyncValue<List<MatchPreview>>>? _msgSub;
  // 30.08: sistem bildirim izni kapalıysa tek satırlık uyarı bandı (Tinder
  // standardı) — X ile kalıcı kapatılabilir, izin açılınca kendiliğinden gider.
  bool _showNotifBanner = false;
  static const _kNotifBannerDismissedKey = 'notif_off_banner_dismissed';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _subscribeRealtime();
    _checkNotifBanner();
  }

  Future<void> _checkNotifBanner() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_kNotifBannerDismissedKey) == true) return;
      final st = await Permission.notification.status;
      if (mounted) {
        setState(() => _showNotifBanner = !(st.isGranted || st.isLimited));
      }
    } catch (_) {
      // Durum okunamazsa band gösterilmez — liste normal çalışır
    }
  }

  Future<void> _dismissNotifBanner() async {
    setState(() => _showNotifBanner = false);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kNotifBannerDismissedKey, true);
    } catch (e, st) {
      ErrorReporter.report(e, stack: st, screen: 'messages_list');
    }
  }

  // Arka plandan dönüşte liste tazelenir — soket sessizce koptuysa realtime
  // olayları kaçmış olabilir (11.08 denetim; chat_screen deseniyle aynı).
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      ref.invalidate(matchesProvider);
      _checkNotifBanner(); // Ayarlar'dan izinle dönüldüyse band kalksın
    }
  }

  void _resubscribeMessages(List<String> ids) {
    if (!mounted) return;
    if (ids.length == _msgIds.length &&
        ids.asMap().entries.every((e) => _msgIds[e.key] == e.value)) {
      return;
    }
    _msgIds = ids;
    if (_msgChannel != null) {
      Supabase.instance.client.removeChannel(_msgChannel!);
      _msgChannel = null;
    }
    if (ids.isEmpty) return;
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    _msgChannel = Supabase.instance.client
        .channel('messages_list_msgs:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.inFilter,
            column: 'match_id',
            value: ids,
          ),
          callback: (_) => ref.invalidate(matchesProvider),
        )
        .subscribe();
  }

  void _subscribeRealtime() {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (uid.isEmpty) return;
    // Yeni eşleşme (kabul) anlık listeye düşsün. 03.09: filtre sunucuda —
    // eskiden filtresiz abonelik TÜM matches olaylarını her açık listeye taşıyordu.
    _channel = Supabase.instance.client
        .channel('messages_list:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user1_id',
            value: uid,
          ),
          callback: (_) => ref.invalidate(matchesProvider),
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'matches',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'user2_id',
            value: uid,
          ),
          callback: (_) => ref.invalidate(matchesProvider),
        )
        .subscribe((status, [_]) {
          // Kopma sonrası yeniden bağlanınca kaçan olaylar telafi edilir.
          if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut ||
              status == RealtimeSubscribeStatus.closed) {
            _channelDropped = true;
          } else if (status == RealtimeSubscribeStatus.subscribed &&
              _channelDropped) {
            _channelDropped = false;
            if (mounted) ref.invalidate(matchesProvider);
          }
        });
    _msgSub = ref.listenManual<AsyncValue<List<MatchPreview>>>(
      matchesProvider,
      (_, next) {
        final ids = (next.valueOrNull ?? const <MatchPreview>[])
            .map((m) => m.matchId)
            .toList()
          ..sort();
        _resubscribeMessages(ids);
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _msgSub?.close();
    if (_channel != null) {
      _channel!.unsubscribe();
      Supabase.instance.client.removeChannel(_channel!);
    }
    if (_msgChannel != null) {
      Supabase.instance.client.removeChannel(_msgChannel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(photoFocusProvider); // yüz odak haritası — gelince rebuild
    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        // Üstte durum çubuğu, altta YALNIZ sistem gezinme şeridi kadar pay:
        // içerik uygulama pill'inin arkasından akar (Profil mantığı) ama
        // sistem şeridinin arkasına taşmaz.
        child: Padding(
          // Ham pencere insets'i (View): Scaffold extendBody gövde
          // MediaQuery'sini değiştirdiği için oradan okunan pay 0 dönebiliyor.
          padding: EdgeInsets.only(
            top: MediaQueryData.fromView(View.of(context)).padding.top,
            bottom: MediaQueryData.fromView(View.of(context)).padding.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Builder(
                  builder: (ctx) => GradientItalicTitle(
                    AppLocalizations.of(ctx)!.messages_title,
                    fontSize: MediaQuery.of(ctx).size.width < 360 ? 20 : 23,
                  ),
                ),
              ),
              if (_showNotifBanner)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                    decoration: BoxDecoration(
                      color: AuroraTheme.glassBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AuroraTheme.glassBorder),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_off_outlined,
                            size: 16, color: AuroraTheme.auroraRed),
                        const SizedBox(width: 10),
                        Expanded(
                          child: GestureDetector(
                            onTap: openAppSettings,
                            child: Text(
                              AppLocalizations.of(context)!
                                  .notif_system_off_banner,
                              style: const TextStyle(
                                fontFamily: 'Manrope',
                                fontSize: 12,
                                color: Colors.white,
                                height: 1.3,
                              ),
                            ),
                          ),
                        ),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close,
                              size: 16, color: Colors.white38),
                          onPressed: _dismissNotifBanner,
                        ),
                      ],
                    ),
                  ),
                ),
              const Expanded(child: _MatchesTab()),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Matches Tab
// ─────────────────────────────────────────────────────────────────────────────

class _MatchesTab extends ConsumerStatefulWidget {
  const _MatchesTab();

  @override
  ConsumerState<_MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends ConsumerState<_MatchesTab> {
  // Kaydırarak silinenler: taze veri gelene kadar bayat provider verisi
  // dismissed satırı yeniden inşa etmesin (bildirimlerdeki "iki kez sil"
  // hatasının aynısını burada baştan önler — 01.08).
  final Set<String> _removedMatchIds = {};

  @override
  Widget build(BuildContext context) {
    final listAsync = ref.watch(matchesProvider);

    return listAsync.when(
      loading: () => _SkeletonList(),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off,
                color: AuroraTheme.textMuted, size: 40),
            const SizedBox(height: 12),
            Text(
              AppLocalizations.of(context)!.messages_connection_error,
              style: TextStyle(
                  fontFamily: 'Manrope',
                  color: AuroraTheme.textSecondary),
            ),
          ],
        ),
      ),
      data: (rawMatches) {
        final matches = rawMatches
            .where((m) => !_removedMatchIds.contains(m.matchId))
            .toList();
        if (matches.isEmpty) return const _EmptyState();
        return RefreshIndicator(
          color: AuroraTheme.auroraRed,
          backgroundColor: AuroraTheme.glassStrong,
          onRefresh: () async {
            ref.invalidate(matchesProvider);
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
            itemCount: matches.length,
            itemBuilder: (ctx, i) {
              final m = matches[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                // Sola kaydır → sil (tek taraflı clear_chat; onay diyaloğu ile)
                child: Dismissible(
                  key: ValueKey('match-${m.matchId}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 22),
                    decoration: BoxDecoration(
                      color: AuroraTheme.auroraRed.withOpacity(0.85),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Icon(Icons.delete_forever_outlined,
                        color: Colors.white, size: 26),
                  ),
                  confirmDismiss: (_) => _confirmClearChat(ctx),
                  onDismissed: (_) async {
                    setState(() => _removedMatchIds.add(m.matchId));
                    try {
                      await Supabase.instance.client.rpc('clear_chat',
                          params: {'p_match_id': m.matchId});
                      ref.invalidate(matchesProvider);
                      await ref.read(matchesProvider.future);
                    } catch (err, stk) {
                      ErrorReporter.report(err, stack: stk, screen: 'messages:delete'); // 04.09: sessiz hata Kovan'a
                      // Silme sunucuya işlenemedi — satırı geri getir
                      ref.invalidate(matchesProvider);
                    } finally {
                      if (mounted) {
                        setState(() => _removedMatchIds.remove(m.matchId));
                      }
                    }
                  },
                  child: _MatchTile(
                      match: m,
                      locale:
                          ref.watch(localeProvider)?.languageCode ?? 'tr'),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// Sola kaydırmada silme onayı — chat içi "Удалить чат" diyaloğuyla aynı dil.
Future<bool> _confirmClearChat(BuildContext context) async {
  final l10n = AppLocalizations.of(context)!;
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: const Color(0xFF14121E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        l10n.chat_delete_conversation,
        style: const TextStyle(
          fontFamily: 'Fraunces',
          fontStyle: FontStyle.italic,
          color: Colors.white,
          fontSize: 20,
        ),
      ),
      content: Text(
        l10n.chat_clear_confirm_body,
        style: TextStyle(
          fontFamily: 'Manrope',
          color: Colors.white.withOpacity(0.65),
          fontSize: 14,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: Text(l10n.btn_cancel,
              style: const TextStyle(
                  fontFamily: 'JetBrainsMono', color: Colors.white54)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(l10n.chat_delete,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                color: AuroraTheme.auroraRed,
                fontWeight: FontWeight.w700,
              )),
        ),
      ],
    ),
  );
  return ok ?? false;
}

// ─────────────────────────────────────────────────────────────────────────────
// Match Tile — Aurora glass card
// ─────────────────────────────────────────────────────────────────────────────

class _MatchTile extends StatelessWidget {
  final MatchPreview match;
  final String locale;
  const _MatchTile({required this.match, required this.locale});

  @override
  Widget build(BuildContext context) {
    final isNew = match.isNewMatch;
    final timeStr = match.lastMessageTime != null
        ? timeago.format(match.lastMessageTime!, locale: locale)
        : (isNew ? timeago.format(match.createdAt, locale: locale) : '');
    final preview = match.lastMessage != null
        ? (match.lastMessage!.length > 35
            ? '${match.lastMessage!.substring(0, 35)}…'
            : match.lastMessage!)
        : (isNew
            ? AppLocalizations.of(context)!.messages_new_match
            : AppLocalizations.of(context)!.messages_no_preview);
    // Yeni eşleşme, okunmamış mesaj gibi vurgulanır — seçildiğini kaçırmasın
    final hasUnread = match.unreadCount > 0 || isNew;
    final displayName = match.isDeleted
        ? AppLocalizations.of(context)!.chat_deleted_user
        : '${match.otherName}, ${match.otherAge}';

    return ClipRRect(
      borderRadius: BorderRadius.circular(AuroraTheme.radiusInfoCard),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push(
              '/chat/${match.matchId}',
              extra: {
                'name': match.isDeleted
                    ? AppLocalizations.of(context)!.chat_deleted_user
                    : match.otherName,
                'age': match.otherAge,
                'photoUrl': match.otherPhotoUrl,
              },
            ),
            borderRadius:
                BorderRadius.circular(AuroraTheme.radiusInfoCard),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: hasUnread
                    ? AuroraTheme.auroraRed.withOpacity(0.07)
                    : AuroraTheme.glassBg,
                borderRadius:
                    BorderRadius.circular(AuroraTheme.radiusInfoCard),
                border: Border.all(
                  color: hasUnread
                      ? AuroraTheme.auroraRed.withOpacity(0.35)
                      : AuroraTheme.glassBorder,
                ),
              ),
              child: Row(
                children: [
                  _Avatar(
                      photoUrl: match.otherPhotoUrl,
                      name: match.otherName),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: hasUnread
                                ? Colors.white
                                : Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          preview,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 13,
                            fontWeight:
                                isNew ? FontWeight.w700 : FontWeight.w400,
                            color: isNew
                                ? AuroraTheme.auroraRed
                                : hasUnread
                                    ? Colors.white.withOpacity(0.80)
                                    : AuroraTheme.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 9,
                            color: AuroraTheme.textMuted,
                            letterSpacing: 0.5,
                          ),
                        ),
                      if (hasUnread) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            gradient: AuroraTheme.redBlueGradient,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AuroraTheme.auroraRed
                                    .withOpacity(0.5),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: Text(
                            match.unreadCount == 0
                                ? '✨'
                                : match.unreadCount > 99
                                    ? '99+'
                                    : '${match.unreadCount}',
                            style: const TextStyle(
                              fontFamily: 'JetBrainsMono',
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Avatar ────────────────────────────────────────────────────────────────────
class _Avatar extends StatelessWidget {
  final String? photoUrl;
  final String name;
  const _Avatar({this.photoUrl, required this.name});

  @override
  Widget build(BuildContext context) {
    if (photoUrl != null) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: photoUrl!,
          width: 52,
          height: 52,
          fit: BoxFit.cover,
          // Küçük decode: tam boy foto avatar için çözülmesin — hem hızlı
          // hem bellek cache'inden düşmez (chat başlığıyla aynı key: 156).
          memCacheWidth: 156,
          fadeInDuration: const Duration(milliseconds: 150),
          placeholder: (_, __) => _InitialsAvatar(name: name),
          alignment: PhotoFocus.of(photoUrl, fallback: Alignment.center),
          errorWidget: (_, __, ___) => _InitialsAvatar(name: name),
        ),
      );
    }
    return _InitialsAvatar(name: name);
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String name;
  const _InitialsAvatar({required this.name});

  @override
  Widget build(BuildContext context) => Container(
        width: 52,
        height: 52,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [AuroraTheme.auroraRed, AuroraTheme.auroraBlue],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w700,
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
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActiveIconLayers(),
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)!.messages_empty_active,
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontStyle: FontStyle.italic,
                  fontSize: 20,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                AppLocalizations.of(context)!.messages_empty_hint,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 14,
                  color: AuroraTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ScButton(
                label: AppLocalizations.of(context)!.messages_btn_create,
                onPressed: () => context.push('/invitation/create'),
              ),
            ],
          ),
        ),
      );
}

// ── Empty State Icon ──────────────────────────────────────────────────────────
class _ActiveIconLayers extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Main bubble — aurora gradient
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (b) => AuroraTheme.redBlueGradient.createShader(b),
            child: const Icon(
              Icons.chat_bubble_rounded,
              size: 44,
              color: Colors.white,
            ),
          ),
          // Glowing spark dot — top-right
          Positioned(
            right: -2,
            top: -2,
            child: Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AuroraTheme.redBlueGradient,
                boxShadow: [
                  BoxShadow(
                    color: AuroraTheme.auroraRed.withOpacity(0.65),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 12,
                color: Colors.white,
              ),
            ),
          ),
        ],
      );
}

// ── Skeleton ──────────────────────────────────────────────────────────────────
class _SkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        itemCount: 6,
        itemBuilder: (_, __) => Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            height: 76,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.06),
              borderRadius:
                  BorderRadius.circular(AuroraTheme.radiusInfoCard),
            ),
          ),
        ),
      );
}
