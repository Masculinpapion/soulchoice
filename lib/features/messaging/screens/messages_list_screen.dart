import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
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
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildTabBar(),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          ShaderMask(
            shaderCallback: (b) =>
                AppColors.primaryGradient.createShader(b),
            child: Text(
              'Mesajlar',
              style: AppTextStyles.headingLarge.copyWith(
                fontStyle: FontStyle.italic,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.glassBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.glassBorder),
      ),
      child: TabBar(
        controller: _tabController,
        indicator: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(10),
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        dividerColor: Colors.transparent,
        labelStyle: AppTextStyles.labelLarge.copyWith(fontSize: 14),
        unselectedLabelStyle:
            AppTextStyles.labelMedium.copyWith(fontSize: 14),
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textTertiary,
        tabs: const [
          Tab(text: 'Aktif'),
          Tab(text: 'Geçmiş'),
        ],
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
            const Icon(Icons.wifi_off,
                color: AppColors.textTertiary, size: 40),
            const SizedBox(height: 12),
            Text('Bağlantı hatası', style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
      data: (matches) {
        if (matches.isEmpty) return _EmptyState(isArchived: isArchived);
        return RefreshIndicator(
          color: AppColors.gradientStart,
          backgroundColor: AppColors.bgCard,
          onRefresh: () async {
            ref.invalidate(matchesProvider);
            await Future.delayed(const Duration(milliseconds: 300));
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            itemCount: matches.length,
            separatorBuilder: (_, __) =>
                const Divider(color: AppColors.glassBorder, height: 1),
            itemBuilder: (ctx, i) => _MatchTile(match: matches[i]),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Match Tile
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

    return InkWell(
      onTap: () => context.push('/chat/${match.matchId}'),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            _Avatar(
              photoUrl: match.otherPhotoUrl,
              name: match.otherName,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${match.otherName}, ${match.otherAge}',
                    style: AppTextStyles.labelLarge.copyWith(fontSize: 16),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    preview,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: match.unreadCount > 0
                          ? AppColors.textPrimary.withOpacity(0.85)
                          : AppColors.textTertiary,
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
                  Text(timeStr, style: AppTextStyles.monoSmall),
                const SizedBox(height: 6),
                if (match.unreadCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      match.unreadCount > 99
                          ? '99+'
                          : '${match.unreadCount}',
                      style: AppTextStyles.monoSmall.copyWith(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Avatar
// ─────────────────────────────────────────────────────────────────────────────

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
          width: 60,
          height: 60,
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
        width: 60,
        height: 60,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          gradient: AppColors.primaryGradient,
        ),
        child: Center(
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: AppTextStyles.titleLarge
                .copyWith(color: Colors.white, fontSize: 22),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────────────────────────────────────

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
              Text(
                isArchived ? '📚' : '💬',
                style: const TextStyle(fontSize: 56),
              ),
              const SizedBox(height: 20),
              Text(
                isArchived
                    ? 'Geçmiş sohbetin yok'
                    : 'Henüz aktif sohbetin yok',
                style: AppTextStyles.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (!isArchived) ...[
                const SizedBox(height: 8),
                Text(
                  'Bir davet aç veya mevcut davete başvur',
                  style: AppTextStyles.bodyMedium,
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

// ─────────────────────────────────────────────────────────────────────────────
// Skeleton loader
// ─────────────────────────────────────────────────────────────────────────────

class _SkeletonList extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        itemCount: 6,
        separatorBuilder: (_, __) =>
            const Divider(color: AppColors.glassBorder, height: 1),
        itemBuilder: (_, __) => const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              _SkeletonCircle(size: 60),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SkeletonBar(width: 120, height: 14),
                    SizedBox(height: 6),
                    _SkeletonBar(width: 200, height: 12),
                  ],
                ),
              ),
              SizedBox(width: 8),
              _SkeletonBar(width: 36, height: 11),
            ],
          ),
        ),
      );
}

class _SkeletonCircle extends StatelessWidget {
  final double size;
  const _SkeletonCircle({required this.size});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.glassBgMedium,
        ),
      );
}

class _SkeletonBar extends StatelessWidget {
  final double width;
  final double height;
  const _SkeletonBar({required this.width, required this.height});
  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: AppColors.glassBgMedium,
          borderRadius: BorderRadius.circular(6),
        ),
      );
}
