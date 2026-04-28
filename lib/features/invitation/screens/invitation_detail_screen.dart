import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import '../../../core/theme/aurora_theme.dart';
import '../../../data/models/invitation_model.dart';
import '../providers/invitation_provider.dart';
import '../../feed/providers/invitations_provider.dart';

class InvitationDetailScreen extends ConsumerWidget {
  final String invitationId;
  const InvitationDetailScreen({super.key, required this.invitationId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invAsync = ref.watch(invitationDetailProvider(invitationId));
    final myAppAsync = ref.watch(myApplicationProvider(invitationId));
    final countAsync = ref.watch(applicationCountProvider(invitationId));
    final uid = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: invAsync.when(
        loading: () => const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AuroraTheme.auroraRed),
            ),
          ),
        ),
        error: (e, _) => Center(
          child: Text('$e',
              style: TextStyle(
                  color: AuroraTheme.textSecondary,
                  fontFamily: AuroraTheme.fontBody)),
        ),
        data: (inv) {
          if (inv == null) {
            return Center(
              child: Text('Davet bulunamadı',
                  style: TextStyle(
                      color: AuroraTheme.textSecondary,
                      fontFamily: AuroraTheme.fontBody)),
            );
          }

          final owner = inv['owner'] as Map<String, dynamic>?;
          final ownerPhotos = (owner?['photos'] as List<dynamic>?) ?? [];
          final sortedOwnerPhotos = ownerPhotos
              .cast<Map<String, dynamic>>()
              .where((p) => p['is_selfie'] == false)
              .toList()
            ..sort((a, b) =>
                (a['order_index'] as int? ?? 99)
                    .compareTo(b['order_index'] as int? ?? 99));
          final ownerPhotoUrl =
              sortedOwnerPhotos.firstOrNull?['url'] as String?;
          final isOwner = uid == inv['owner_id'];
          final category = InvitationCategory.values.firstWhere(
            (c) => c.name == inv['category'],
            orElse: () => InvitationCategory.food,
          );
          final expiresAt = DateTime.parse(inv['expires_at'] as String);
          final remaining = expiresAt.difference(DateTime.now());
          final heroHeight = MediaQuery.of(context).size.height * 0.60;

          return Stack(
            children: [
              // ── Scrollable content ──────────────────────────────────
              SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // HERO
                    SizedBox(
                      height: heroHeight,
                      child: Stack(
                        children: [
                          // Photo
                          Positioned.fill(
                            child: ownerPhotoUrl != null
                                ? CachedNetworkImage(
                                    imageUrl: ownerPhotoUrl,
                                    fit: BoxFit.cover,
                                    alignment: Alignment.topCenter,
                                    errorWidget: (_, __, ___) =>
                                        const _FallbackBg(),
                                  )
                                : const _FallbackBg(),
                          ),
                          // Top scrim
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 140,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    const Color(0xFF050709).withOpacity(0.55),
                                    Colors.transparent,
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Bottom fade
                          Positioned(
                            left: 0,
                            right: 0,
                            bottom: 0,
                            height: 280,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    const Color(0xFF050709).withOpacity(0.20),
                                    const Color(0xFF050709).withOpacity(0.70),
                                    const Color(0xFF050709).withOpacity(0.95),
                                    AuroraTheme.bgDeep,
                                  ],
                                  stops: const [0.0, 0.30, 0.65, 0.90, 1.0],
                                ),
                              ),
                            ),
                          ),
                          // Aurora glow
                          Positioned(
                            left: -44,
                            right: -44,
                            bottom: -60,
                            height: 180,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment.center,
                                  radius: 0.7,
                                  colors: [
                                    AuroraTheme.auroraBlue.withOpacity(0.18),
                                    AuroraTheme.auroraRed.withOpacity(0.08),
                                    Colors.transparent,
                                  ],
                                  stops: const [0.0, 0.50, 0.75],
                                ),
                              ),
                            ),
                          ),
                          // Top bar
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            child: SafeArea(
                              bottom: false,
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 12, 20, 0),
                                child: Row(
                                  children: [
                                    _IconBtn(
                                      onTap: () => context.pop(),
                                      child: const Icon(
                                          Icons.arrow_back_ios_new,
                                          size: 18,
                                          color: Colors.white),
                                    ),
                                    const Spacer(),
                                    _CategoryChip(category: category),
                                    if (isOwner) ...[
                                      const SizedBox(width: 8),
                                      _IconBtn(
                                        onTap: () => context.push(
                                            '/invitation/$invitationId/applicants'),
                                        child: const Icon(
                                            Icons.people_outline,
                                            size: 18,
                                            color: Colors.white),
                                      ),
                                      const SizedBox(width: 8),
                                      _IconBtn(
                                        onTap: () =>
                                            _confirmDelete(context, ref),
                                        child: const Icon(
                                            Icons.delete_outline,
                                            size: 18,
                                            color: AuroraTheme.auroraRed),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ),
                          // Hero title block
                          Positioned(
                            left: 24,
                            right: 24,
                            bottom: 28,
                            child: _HeroTitleBlock(inv: inv),
                          ),
                        ],
                      ),
                    ),
                    // CONTENT
                    Container(
                      color: AuroraTheme.bgDeep,
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _CountdownStrip(
                            remaining: remaining,
                            countAsync: countAsync,
                          ),
                          if (inv['description'] != null) ...[
                            const _SectionHeader(label: 'Davet'),
                            const SizedBox(height: 14),
                            _DescriptionBlock(
                                text: inv['description'] as String),
                            const SizedBox(height: 28),
                          ],
                          if (inv['venue_name'] != null ||
                              inv['event_date'] != null) ...[
                            const _SectionHeader(label: 'Detaylar'),
                            const SizedBox(height: 14),
                            _DetailCard(inv: inv),
                            const SizedBox(height: 28),
                          ],
                          if (owner != null) ...[
                            const _SectionHeader(label: 'Davet Sahibi'),
                            const SizedBox(height: 14),
                            _HostCard(
                              owner: owner,
                              ownerPhotoUrl: ownerPhotoUrl,
                            ),
                          ],
                          const SizedBox(height: 120),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // ── Sticky CTA ──────────────────────────────────────────
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        AuroraTheme.bgDeep.withOpacity(0.85),
                        AuroraTheme.bgDeep,
                      ],
                      stops: const [0.0, 0.30, 0.70],
                    ),
                  ),
                  padding: EdgeInsets.only(
                    left: 20,
                    right: 20,
                    top: 18,
                    bottom: MediaQuery.of(context).padding.bottom + 20,
                  ),
                  child: isOwner
                      ? _AuroraCTA(
                          label: 'Başvuranları Gör',
                          icon: Icons.people_outline,
                          onPressed: () => context.push(
                              '/invitation/$invitationId/applicants'),
                        )
                      : myAppAsync.when(
                          loading: () => const _AuroraCTA(
                              label: 'Yükleniyor...', onPressed: null),
                          error: (_, __) => const _AuroraCTA(
                              label: 'Hata', onPressed: null),
                          data: (myApp) => _ApplyButton(
                            invitationId: invitationId,
                            existingApp: myApp,
                            isRequestFlow: inv['flow_type'] == 'request',
                            onApplied: () => ref.invalidate(
                                myApplicationProvider(invitationId)),
                          ),
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuroraTheme.bgDeep,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Daveti sil',
            style: TextStyle(
                fontFamily: AuroraTheme.fontDisplay,
                fontStyle: FontStyle.italic,
                color: Colors.white,
                fontSize: 20)),
        content: Text('Bu daveti silmek istiyor musun? Geri alınamaz.',
            style: TextStyle(
                fontFamily: AuroraTheme.fontBody,
                color: AuroraTheme.textSecondary,
                fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Vazgeç',
                style: TextStyle(
                    fontFamily: AuroraTheme.fontMono,
                    color: AuroraTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Sil',
                style: TextStyle(
                    fontFamily: AuroraTheme.fontMono,
                    color: AuroraTheme.auroraRed,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      await Supabase.instance.client
          .from('invitations')
          .delete()
          .eq('id', invitationId);
      ref.invalidate(invitationDetailProvider);
      ref.invalidate(invitationsProvider);
      if (context.mounted) context.pop();
    }
  }
}

// ── Fallback Background ───────────────────────────────────────────────────────
class _FallbackBg extends StatelessWidget {
  const _FallbackBg();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AuroraTheme.auroraRed.withOpacity(0.35),
              AuroraTheme.auroraBlue.withOpacity(0.20),
            ],
          ),
        ),
      );
}

// ── Icon Button (40×40 circle glass) ─────────────────────────────────────────
class _IconBtn extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  const _IconBtn({required this.child, this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(100),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.40),
                shape: BoxShape.circle,
                border:
                    Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Center(child: child),
            ),
          ),
        ),
      );
}

// ── Category Chip ─────────────────────────────────────────────────────────────
class _CategoryChip extends StatelessWidget {
  final InvitationCategory category;
  const _CategoryChip({required this.category});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.40),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(category.emoji,
                    style: const TextStyle(fontSize: 12)),
                const SizedBox(width: 8),
                Text(
                  category.label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AuroraTheme.fontMono,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.6,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ── Hero Title Block ──────────────────────────────────────────────────────────
class _HeroTitleBlock extends StatelessWidget {
  final Map<String, dynamic> inv;
  const _HeroTitleBlock({required this.inv});

  @override
  Widget build(BuildContext context) {
    final venueName = inv['venue_name'] as String?;
    final eventDate = inv['event_date'] != null
        ? DateTime.tryParse(inv['event_date'] as String)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          inv['title'] as String,
          style: const TextStyle(
            fontFamily: AuroraTheme.fontDisplay,
            fontStyle: FontStyle.italic,
            fontWeight: FontWeight.w500,
            fontSize: 34,
            height: 1.1,
            letterSpacing: -0.68,
            color: Colors.white,
            shadows: [
              Shadow(blurRadius: 24, color: Color(0xA6000000)),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // Gradient divider
        Container(
          width: 40,
          height: 2,
          decoration: const BoxDecoration(
            gradient: AuroraTheme.redBlueGradient,
            borderRadius: BorderRadius.all(Radius.circular(2)),
          ),
        ),
        const SizedBox(height: 12),
        // Meta row
        Row(
          children: [
            if (venueName != null)
              Flexible(
                child: Text(
                  venueName,
                  style: TextStyle(
                    fontFamily: AuroraTheme.fontMono,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 1.76,
                    color: Colors.white.withOpacity(0.82),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            if (venueName != null && eventDate != null) ...[
              const SizedBox(width: 10),
              Container(
                width: 3,
                height: 3,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.50),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
            ],
            if (eventDate != null)
              Text(
                _shortDate(eventDate),
                style: TextStyle(
                  fontFamily: AuroraTheme.fontMono,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.76,
                  color: Colors.white.withOpacity(0.82),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _shortDate(DateTime dt) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cts', 'Paz'];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]} $h:$m';
  }
}

// ── Section Header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Container(
            width: 40,
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AuroraTheme.auroraRed.withOpacity(0.60),
                  AuroraTheme.auroraBlue.withOpacity(0.60),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontFamily: AuroraTheme.fontMono,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.98,
              color: Colors.white.withOpacity(0.55),
            ),
          ),
        ],
      );
}

// ── Countdown Strip ───────────────────────────────────────────────────────────
class _CountdownStrip extends StatelessWidget {
  final Duration remaining;
  final AsyncValue countAsync;
  const _CountdownStrip(
      {required this.remaining, required this.countAsync});

  @override
  Widget build(BuildContext context) {
    final expired = remaining.isNegative;
    final hours = expired ? 0 : remaining.inHours;
    final mins = expired ? 0 : remaining.inMinutes % 60;
    final countdownText = expired ? 'Sona erdi' : '${hours}s ${mins}dk';
    final appCount = countAsync.valueOrNull ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 28),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(23, 18, 20, 18),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.06),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  // Clock icon square
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      gradient: AuroraTheme.redBlueSoftGradient,
                      border: Border.all(
                          color: AuroraTheme.auroraRed.withOpacity(0.25)),
                    ),
                    child: const Icon(Icons.schedule_rounded,
                        size: 18, color: AuroraTheme.auroraRed),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          countdownText,
                          style: const TextStyle(
                            fontFamily: AuroraTheme.fontDisplay,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                            fontSize: 22,
                            height: 1.1,
                            letterSpacing: -0.22,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'BAŞVURU İÇİN KALAN',
                          style: TextStyle(
                            fontFamily: AuroraTheme.fontMono,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.71,
                            color: Colors.white.withOpacity(0.50),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Applicants
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$appCount',
                        style: const TextStyle(
                          fontFamily: AuroraTheme.fontDisplay,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                          fontSize: 22,
                          height: 1.1,
                          letterSpacing: -0.22,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'BAŞVURU',
                        style: TextStyle(
                          fontFamily: AuroraTheme.fontMono,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.71,
                          color: Colors.white.withOpacity(0.50),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Left accent bar
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 3,
              child: const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AuroraTheme.redBlueGradient,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Description Pull-quote ────────────────────────────────────────────────────
class _DescriptionBlock extends StatelessWidget {
  final String text;
  const _DescriptionBlock({required this.text});

  @override
  Widget build(BuildContext context) => Stack(
        children: [
          Positioned(
            left: 0,
            top: 4,
            bottom: 4,
            width: 2,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: AuroraTheme.redBlueGradient,
                borderRadius: BorderRadius.all(Radius.circular(2)),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Text(
              text,
              style: TextStyle(
                fontFamily: AuroraTheme.fontDisplay,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w400,
                fontSize: 17,
                height: 1.55,
                letterSpacing: -0.085,
                color: Colors.white.withOpacity(0.88),
              ),
            ),
          ),
        ],
      );
}

// ── Detail Card ───────────────────────────────────────────────────────────────
class _DetailCard extends StatelessWidget {
  final Map<String, dynamic> inv;
  const _DetailCard({required this.inv});

  @override
  Widget build(BuildContext context) {
    final venueName = inv['venue_name'] as String?;
    final eventDate = inv['event_date'] != null
        ? DateTime.tryParse(inv['event_date'] as String)
        : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        children: [
          if (venueName != null)
            _DetailRow(
              icon: Icons.location_on_outlined,
              label: 'Mekan',
              value: venueName,
              action: 'Yol Tarifi',
              isLast: eventDate == null,
            ),
          if (eventDate != null)
            _DetailRow(
              icon: Icons.calendar_today_outlined,
              label: 'Tarih & Saat',
              value: _formatDate(eventDate),
              isLast: true,
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const days = [
      'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe',
      'Cuma', 'Cumartesi', 'Pazar'
    ];
    const months = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} · $h:$m';
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? action;
  final bool isLast;
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.action,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
        decoration: BoxDecoration(
          border: isLast
              ? null
              : Border(
                  bottom: BorderSide(
                      color: Colors.white.withOpacity(0.06))),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon,
                  size: 17, color: Colors.white.withOpacity(0.70)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: AuroraTheme.fontMono,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.71,
                      color: Colors.white.withOpacity(0.45),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontFamily: AuroraTheme.fontBody,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.075,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            if (action != null)
              Text(
                action!,
                style: const TextStyle(
                  fontFamily: AuroraTheme.fontBody,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AuroraTheme.auroraBlue,
                ),
              ),
          ],
        ),
      );
}

// ── Host Card ─────────────────────────────────────────────────────────────────
class _HostCard extends StatelessWidget {
  final Map<String, dynamic> owner;
  final String? ownerPhotoUrl;
  const _HostCard({required this.owner, this.ownerPhotoUrl});

  String _meta() {
    final job = owner['job'] as String?;
    final city = owner['city_name'] as String?;
    if (job != null && city != null) {
      return '${job.toUpperCase()} · ${city.toUpperCase()}';
    }
    if (job != null) return job.toUpperCase();
    if (city != null) return city.toUpperCase();
    return 'DAVET SAHİBİ';
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => context.push('/profile/${owner['id']}'),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.12)),
          ),
          child: Row(
            children: [
              // 48px avatar with gradient ring
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(
                        gradient: AuroraTheme.redBlueGradient,
                        shape: BoxShape.circle,
                      ),
                    ),
                    Positioned.fill(
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: ClipOval(
                          child: ownerPhotoUrl != null
                              ? CachedNetworkImage(
                                  imageUrl: ownerPhotoUrl!,
                                  fit: BoxFit.cover,
                                  alignment: Alignment.topCenter,
                                  errorWidget: (_, __, ___) => Container(
                                    color: AuroraTheme.bgDeep,
                                    child: const Icon(Icons.person_outline,
                                        color: Colors.white54, size: 24),
                                  ),
                                )
                              : Container(
                                  color: AuroraTheme.bgDeep,
                                  child: const Icon(Icons.person_outline,
                                      color: Colors.white54, size: 24),
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            '${owner['name']}, ${owner['age']}',
                            style: const TextStyle(
                              fontFamily: AuroraTheme.fontDisplay,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                              fontSize: 18,
                              height: 1.1,
                              letterSpacing: -0.18,
                              color: Colors.white,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (owner['verified'] == true) ...[
                          const SizedBox(width: 8),
                          Container(
                            width: 16,
                            height: 16,
                            decoration: const BoxDecoration(
                              gradient: AuroraTheme.redBlueGradient,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.check,
                                color: Colors.white, size: 10),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _meta(),
                      style: TextStyle(
                        fontFamily: AuroraTheme.fontMono,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.60,
                        color: Colors.white.withOpacity(0.55),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right,
                  size: 24, color: Colors.white.withOpacity(0.40)),
            ],
          ),
        ),
      );
}

// ── Aurora CTA ────────────────────────────────────────────────────────────────
class _AuroraCTA extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;

  const _AuroraCTA(
      {required this.label, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 58,
      decoration: BoxDecoration(
        gradient: onPressed != null
            ? AuroraTheme.redBlueGradient
            : const LinearGradient(
                colors: [Color(0xFF444444), Color(0xFF333333)]),
        borderRadius: BorderRadius.circular(100),
        boxShadow: onPressed != null
            ? [
                BoxShadow(
                  color: AuroraTheme.auroraRed.withOpacity(0.32),
                  blurRadius: 40,
                  offset: const Offset(0, 16),
                ),
                BoxShadow(
                  color: AuroraTheme.auroraBlue.withOpacity(0.22),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(100),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: const TextStyle(
                  fontFamily: AuroraTheme.fontBody,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  letterSpacing: 0.08,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Apply Button ──────────────────────────────────────────────────────────────
class _ApplyButton extends ConsumerStatefulWidget {
  final String invitationId;
  final Map<String, dynamic>? existingApp;
  final bool isRequestFlow;
  final VoidCallback onApplied;

  const _ApplyButton({
    required this.invitationId,
    this.existingApp,
    this.isRequestFlow = false,
    required this.onApplied,
  });

  @override
  ConsumerState<_ApplyButton> createState() => _ApplyButtonState();
}

class _ApplyButtonState extends ConsumerState<_ApplyButton> {
  bool _loading = false;

  Future<void> _apply() async {
    setState(() => _loading = true);
    try {
      final uid = Supabase.instance.client.auth.currentUser!.id;
      await Supabase.instance.client.from('applications').insert({
        'invitation_id': widget.invitationId,
        'applicant_id': uid,
        'status': 'pending',
      });
      widget.onApplied();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            padding: EdgeInsets.zero,
            duration: const Duration(seconds: 3),
            content: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                    color: AuroraTheme.auroraRed.withOpacity(0.38)),
                boxShadow: [
                  BoxShadow(
                    color: AuroraTheme.auroraRed.withOpacity(0.28),
                    blurRadius: 32,
                    spreadRadius: -4,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.65),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AuroraTheme.redBlueGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AuroraTheme.auroraRed.withOpacity(0.55),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.check_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Başvurun Gönderildi',
                        style: TextStyle(
                          fontFamily: AuroraTheme.fontDisplay,
                          fontStyle: FontStyle.italic,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Davet sahibinin seçim yapmasını bekle',
                        style: TextStyle(
                          fontFamily: AuroraTheme.fontBody,
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.50),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AuroraTheme.auroraRed),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = widget.existingApp;
    if (app == null) {
      return _AuroraCTA(
        label: _loading
            ? 'Gönderiliyor...'
            : (widget.isRequestFlow ? 'Katılmak isterim' : 'Gelmek isterim'),
        onPressed: _loading ? null : _apply,
      );
    }
    final status = app['status'] as String;
    if (status == 'selected') {
      return _AuroraCTA(
        label: 'Seçildiniz — Kararınızı verin',
        icon: Icons.favorite_outline,
        onPressed: () => context.push(
            '/invitation/${widget.invitationId}/decision',
            extra: {'applicationId': app['id']}),
      );
    }
    if (status == 'accepted') {
      return const _AuroraCTA(label: '✓ Kabul edildi', onPressed: null);
    }
    return const _AuroraCTA(label: 'Başvurdunuz', onPressed: null);
  }
}
