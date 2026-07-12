import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
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

class _MessagesListScreenState extends ConsumerState<MessagesListScreen> {
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
    if (_channel != null) {
      _channel!.unsubscribe();
      Supabase.instance.client.removeChannel(_channel!);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(photoFocusProvider); // yüz odak haritası — gelince rebuild
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
                child: Builder(
                  builder: (ctx) => GradientItalicTitle(
                    AppLocalizations.of(ctx)!.messages_title,
                    fontSize: MediaQuery.of(ctx).size.width < 360 ? 23.8 : 28,
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

class _MatchesTab extends ConsumerWidget {
  const _MatchesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(activeMatchesProvider);

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
      data: (matches) {
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
            itemBuilder: (ctx, i) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _MatchTile(match: matches[i], locale: ref.watch(localeProvider)?.languageCode ?? 'tr'),
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
  final String locale;
  const _MatchTile({required this.match, required this.locale});

  @override
  Widget build(BuildContext context) {
    final timeStr = match.lastMessageTime != null
        ? timeago.format(match.lastMessageTime!, locale: locale)
        : '';
    final preview = match.lastMessage != null
        ? (match.lastMessage!.length > 35
            ? '${match.lastMessage!.substring(0, 35)}…'
            : match.lastMessage!)
        : AppLocalizations.of(context)!.messages_no_preview;
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
