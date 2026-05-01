import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart';
import '../providers/matches_provider.dart';

class MessagesListScreen extends ConsumerStatefulWidget {
  const MessagesListScreen({super.key});

  @override
  ConsumerState<MessagesListScreen> createState() =>
      _MessagesListScreenState();
}

class _MessagesListScreenState extends ConsumerState<MessagesListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _subscribeRealtime();
  }

  void _subscribeRealtime() {
    final uid = Supabase.instance.client.auth.currentUser?.id ?? '';
    if (uid.isEmpty) return;
    _channel = Supabase.instance.client
        .channel('messages_list:$uid')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          callback: (_) => ref.invalidate(matchesProvider),
        )
        .subscribe();
  }

  @override
  void dispose() {
    _tabController.dispose();
    if (_channel != null) {
      _channel!.unsubscribe();
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Başlık
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: ShaderMask(
                  shaderCallback: (b) =>
                      AuroraTheme.redBlueGradient.createShader(b),
                  child: const Text(
                    'Mesajlar',
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontStyle: FontStyle.italic,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              // Tab bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AuroraTheme.glassBg,
                        borderRadius: BorderRadius.circular(12),
                        border:
                            Border.all(color: AuroraTheme.glassBorder),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicator: BoxDecoration(
                          gradient: AuroraTheme.redBlueGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelStyle: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                        unselectedLabelStyle: const TextStyle(
                          fontFamily: 'JetBrainsMono',
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        labelColor: Colors.white,
                        unselectedLabelColor:
                            Colors.white.withOpacity(0.35),
                        tabs: const [
                          Tab(text: 'Aktif'),
                          Tab(text: 'Geçmiş'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: const [
                    _MatchesTab(isArchived: false),
                    _MatchesTab(isArchived: true),
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

// ─────────────────────────────────────────────────────────────────────────────
// Matches Tab
// ─────────────────────────────────────────────────────────────────────────────

class _MatchesTab extends ConsumerWidget {
  final bool isArchived;
  const _MatchesTab({required this.isArchived});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = isArchived
        ? ref.watch(archivedMatchesProvider)
        : ref.watch(activeMatchesProvider);

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
              'Bağlantı hatası',
              style: TextStyle(
                  fontFamily: 'Manrope',
                  color: AuroraTheme.textSecondary),
            ),
          ],
        ),
      ),
      data: (matches) {
        if (matches.isEmpty) return _EmptyState(isArchived: isArchived);
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
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MatchTile(match: matches[i]),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Match Tile — Aurora glass card
// ─────────────────────────────────────────────────────────────────────────────

class _MatchTile extends StatelessWidget {
  final MatchPreview match;
  const _MatchTile({required this.match});

  @override
  Widget build(BuildContext context) {
    final timeStr = match.lastMessageTime != null
        ? timeago.format(match.lastMessageTime!, locale: 'tr')
        : '';
    final preview = match.lastMessage != null
        ? (match.lastMessage!.length > 35
            ? '${match.lastMessage!.substring(0, 35)}…'
            : match.lastMessage!)
        : 'Henüz mesaj yok';
    final hasUnread = match.unreadCount > 0;

    return ClipRRect(
      borderRadius: BorderRadius.circular(AuroraTheme.radiusInfoCard),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => context.push('/chat/${match.matchId}'),
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
                          '${match.otherName}, ${match.otherAge}',
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
                            color: hasUnread
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
                            match.unreadCount > 99
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
  final bool isArchived;
  const _EmptyState({required this.isArchived});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _EmptyStateIcon(isArchived: isArchived),
              const SizedBox(height: 24),
              Text(
                isArchived
                    ? 'Geçmiş sohbetin yok'
                    : 'Henüz aktif sohbetin yok',
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontStyle: FontStyle.italic,
                  fontSize: 20,
                  color: Colors.white,
                ),
                textAlign: TextAlign.center,
              ),
              if (!isArchived) ...[
                const SizedBox(height: 8),
                Text(
                  'Bir davet aç veya mevcut davete başvur',
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    color: AuroraTheme.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ScButton(
                  label: 'Davet Aç',
                  onPressed: () => context.push('/invitation/create'),
                ),
              ],
            ],
          ),
        ),
      );
}

// ── Empty State Icon ──────────────────────────────────────────────────────────
class _EmptyStateIcon extends StatelessWidget {
  final bool isArchived;
  const _EmptyStateIcon({required this.isArchived});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 104,
        height: 104,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer glow halo
            Container(
              width: 104,
              height: 104,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    (isArchived
                            ? AuroraTheme.auroraViolet
                            : AuroraTheme.auroraRed)
                        .withOpacity(0.22),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
            // Glass ring
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                child: Container(
                  width: 78,
                  height: 78,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withOpacity(0.05),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.11),
                    ),
                  ),
                ),
              ),
            ),
            // Icon
            if (isArchived)
              _ArchiveIconLayers()
            else
              _ActiveIconLayers(),
          ],
        ),
      );
}

class _ArchiveIconLayers extends StatelessWidget {
  @override
  Widget build(BuildContext context) => SizedBox(
        width: 54,
        height: 54,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // Back bubble — upper-right, violet, muted
            Positioned(
              right: 0,
              top: 2,
              child: Icon(
                Icons.chat_bubble_rounded,
                size: 34,
                color: AuroraTheme.auroraViolet.withOpacity(0.36),
              ),
            ),
            // Front bubble — lower-left, aurora gradient
            Positioned(
              left: 0,
              bottom: 0,
              child: ShaderMask(
                shaderCallback: (b) =>
                    AuroraTheme.redBlueGradient.createShader(b),
                child: const Icon(
                  Icons.chat_bubble_rounded,
                  size: 40,
                  color: Colors.white,
                ),
              ),
            ),
            // Tiny clock badge — bottom-right
            Positioned(
              right: 1,
              bottom: 1,
              child: Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AuroraTheme.bgDeep,
                  border: Border.all(
                    color: AuroraTheme.auroraViolet.withOpacity(0.50),
                    width: 1,
                  ),
                ),
                child: Icon(
                  Icons.schedule_rounded,
                  size: 11,
                  color: AuroraTheme.auroraViolet.withOpacity(0.80),
                ),
              ),
            ),
          ],
        ),
      );
}

class _ActiveIconLayers extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Main bubble — aurora gradient
          ShaderMask(
            shaderCallback: (b) =>
                AuroraTheme.redBlueGradient.createShader(b),
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
