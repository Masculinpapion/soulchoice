import 'dart:async';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/invitation_model.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart';
import '../providers/invitation_provider.dart';

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
      backgroundColor: AppColors.bgDeep,
      body: AmbientBackground(
        child: invAsync.when(
          loading: () => const Center(
              child: CircularProgressIndicator(
                  color: AppColors.red)),
          error: (e, _) => Center(
              child: Text('$e',
                  style: const TextStyle(
                      color: AppColors.textSecondary))),
          data: (inv) {
            if (inv == null) {
              return const Center(
                  child: Text('Davet bulunamadı',
                      style: TextStyle(
                          color: AppColors.textSecondary)));
            }

            final owner = inv['owner'] as Map<String, dynamic>?;
            final ownerPhotos =
                (owner?['photos'] as List<dynamic>?) ?? [];
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

            return Stack(
              children: [
                SingleChildScrollView(
                  padding: EdgeInsets.only(
                    bottom:
                        MediaQuery.of(context).padding.bottom + 100,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── Hero ──────────────────────────────────────
                      _HeroBlock(
                        photoUrl: ownerPhotoUrl,
                        title: inv['title'] as String,
                        category: category,
                        venueName: inv['venue_name'] as String?,
                        eventDate: inv['event_date'] != null
                            ? DateTime.parse(
                                inv['event_date'] as String)
                            : null,
                        onBack: () => context.pop(),
                      ),

                      // ── Content ───────────────────────────────────
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            24, 24, 24, 0),
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            // Countdown strip
                            myAppAsync.when(
                              loading: () => const SizedBox.shrink(),
                              error: (_, __) =>
                                  const SizedBox.shrink(),
                              data: (myApp) => countAsync.maybeWhen(
                                data: (count) => _CountdownStrip(
                                  inv: inv,
                                  myApp: myApp,
                                  isOwner: isOwner,
                                  applicantCount: count,
                                ),
                                orElse: () => _CountdownStrip(
                                  inv: inv,
                                  myApp: myApp,
                                  isOwner: isOwner,
                                  applicantCount: 0,
                                ),
                              ),
                            ),
                            const SizedBox(height: 28),

                            // Description
                            if (inv['description'] != null) ...[
                              _DescriptionBlock(
                                text: inv['description'] as String,
                              ),
                              const SizedBox(height: 28),
                            ],

                            // Detail card (venue + date)
                            _DetailCard(
                              venueName:
                                  inv['venue_name'] as String?,
                              venueLat:
                                  inv['venue_lat'] as double?,
                              venueLng:
                                  inv['venue_lng'] as double?,
                              eventDate: inv['event_date'] != null
                                  ? DateTime.parse(
                                      inv['event_date'] as String)
                                  : null,
                            ),
                            const SizedBox(height: 28),

                            // Host card
                            if (owner != null) ...[
                              _SectionHeader(label: 'Davet Sahibi'),
                              const SizedBox(height: 14),
                              _HostCard(
                                owner: owner,
                                ownerPhotoUrl: ownerPhotoUrl,
                                onTap: () => context.push(
                                    '/profile/${owner['id']}'),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Sticky CTA ────────────────────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(
                      20,
                      18,
                      20,
                      MediaQuery.of(context).padding.bottom + 20,
                    ),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          Color(0xFF050709),
                          Color(0xCC050709),
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.55, 1.0],
                      ),
                    ),
                    child: isOwner
                        ? ScButton(
                            label: 'Başvuranları gör',
                            icon: Icons.people_outline,
                            onPressed: () => context.push(
                                '/invitation/$invitationId/applicants'),
                          )
                        : myAppAsync.when(
                            loading: () => const ScButton(
                                label: 'Yükleniyor...',
                                onPressed: null),
                            error: (_, __) => const ScButton(
                                label: 'Hata', onPressed: null),
                            data: (myApp) => _ApplyButton(
                              invitationId: invitationId,
                              existingApp: myApp,
                              onApplied: () => ref.invalidate(
                                  myApplicationProvider(
                                      invitationId)),
                            ),
                          ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Block
// ─────────────────────────────────────────────────────────────────────────────

class _HeroBlock extends StatelessWidget {
  final String? photoUrl;
  final String title;
  final InvitationCategory category;
  final String? venueName;
  final DateTime? eventDate;
  final VoidCallback onBack;

  const _HeroBlock({
    required this.photoUrl,
    required this.title,
    required this.category,
    required this.venueName,
    required this.eventDate,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final heroH = MediaQuery.of(context).size.height * 0.60;

    return SizedBox(
      height: heroH,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Photo
          if (photoUrl != null)
            CachedNetworkImage(
              imageUrl: photoUrl!,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorWidget: (_, __, ___) => Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.red.withOpacity(0.3),
                      AppColors.blue.withOpacity(0.2),
                    ],
                  ),
                ),
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.red.withOpacity(0.3),
                    AppColors.blue.withOpacity(0.2),
                  ],
                ),
              ),
            ),

          // Top scrim
          IgnorePointer(
            child: Container(
              height: 140,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x8C050709), Colors.transparent],
                ),
              ),
            ),
          ),

          // Bottom fade
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: heroH * 0.55,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Color(0xFF050709),
                      Color(0xCC050709),
                      Color(0x33050709),
                      Colors.transparent,
                    ],
                    stops: [0.0, 0.35, 0.65, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Aurora glow
          Positioned(
            left: 0,
            right: 0,
            bottom: -60,
            child: IgnorePointer(
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [
                      AppColors.blue.withOpacity(0.18),
                      AppColors.red.withOpacity(0.08),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 0.75],
                  ),
                ),
              ),
            ),
          ),

          // Top bar: back + category chip
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _GlassIconButton(
                      icon: Icons.arrow_back_ios_new,
                      onTap: onBack,
                    ),
                    _CategoryChip(category: category),
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    fontSize: 34,
                    height: 1.1,
                    letterSpacing: -0.68,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        color: Color(0xA6000000),
                        blurRadius: 24,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  width: 40,
                  height: 2,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 12),
                _HeroMeta(
                    venueName: venueName, eventDate: eventDate),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Hero Meta (venue · day time)
// ─────────────────────────────────────────────────────────────────────────────

class _HeroMeta extends StatelessWidget {
  final String? venueName;
  final DateTime? eventDate;
  const _HeroMeta({this.venueName, this.eventDate});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[
      if (venueName != null && venueName!.isNotEmpty) venueName!,
      if (eventDate != null) _formatEventMeta(eventDate!),
    ];
    if (parts.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 0,
      runSpacing: 4,
      children: () {
        final widgets = <Widget>[];
        for (var i = 0; i < parts.length; i++) {
          widgets.add(Text(
            parts[i].toUpperCase(),
            style: const TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.176,
              color: Color(0xD1FFFFFF),
            ),
          ));
          if (i < parts.length - 1) {
            widgets.add(Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '·',
                style: const TextStyle(
                  color: Color(0x80FFFFFF),
                  fontSize: 11,
                ),
              ),
            ));
          }
        }
        return widgets;
      }(),
    );
  }

  String _formatEventMeta(DateTime dt) {
    const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
    final dayName = days[dt.weekday - 1];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$dayName $h:$m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Chip
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChip extends StatelessWidget {
  final InvitationCategory category;
  const _CategoryChip({required this.category});

  IconData get _icon {
    switch (category) {
      case InvitationCategory.food:
        return Icons.restaurant_outlined;
      case InvitationCategory.concert:
        return Icons.music_note_outlined;
      case InvitationCategory.travel:
        return Icons.flight_outlined;
      case InvitationCategory.culture:
        return Icons.palette_outlined;
      case InvitationCategory.cinema:
        return Icons.movie_outlined;
      case InvitationCategory.theater:
        return Icons.theater_comedy_outlined;
      case InvitationCategory.coffee:
        return Icons.coffee_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(100),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 9, 14, 9),
          decoration: BoxDecoration(
            color: const Color(0x66000000),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icon, size: 14, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                category.label.toUpperCase(),
                style: const TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.16,
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

// ─────────────────────────────────────────────────────────────────────────────
// Countdown Strip — stateful, ticks every 30s
// ─────────────────────────────────────────────────────────────────────────────

enum _CountdownState {
  applyPeriod,     // A: not applied, not host, active
  waitingSelection, // B: applied pending, active
  hostDecision,    // C: host, active
  waitingApproval, // D: applicant was selected (app.status == selected)
  matched,         // E: invitation matched
  closed,          // F: closed / cancelled / expired
}

class _CountdownStrip extends StatefulWidget {
  final Map<String, dynamic> inv;
  final Map<String, dynamic>? myApp;
  final bool isOwner;
  final int applicantCount;

  const _CountdownStrip({
    required this.inv,
    required this.myApp,
    required this.isOwner,
    required this.applicantCount,
  });

  @override
  State<_CountdownStrip> createState() => _CountdownStripState();
}

class _CountdownStripState extends State<_CountdownStrip> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  _CountdownState get _state {
    final status = widget.inv['status'] as String? ?? 'active';
    if (status == 'matched') return _CountdownState.matched;
    if (status == 'closed' || status == 'cancelled') {
      return _CountdownState.closed;
    }
    final expiresAt =
        DateTime.parse(widget.inv['expires_at'] as String);
    if (_now.isAfter(expiresAt)) return _CountdownState.closed;
    if (widget.isOwner) return _CountdownState.hostDecision;
    if (widget.myApp == null) return _CountdownState.applyPeriod;
    final appStatus =
        widget.myApp!['status'] as String? ?? 'pending';
    if (appStatus == 'selected') return _CountdownState.waitingApproval;
    return _CountdownState.waitingSelection;
  }

  Duration get _remaining {
    final expiresAt =
        DateTime.parse(widget.inv['expires_at'] as String);
    return expiresAt.difference(_now);
  }

  String _formatDuration(Duration d) {
    if (d.isNegative || d.inSeconds <= 0) return 'Bitti';
    if (d.inMinutes <= 5) return 'Az kaldı';
    if (d.inHours < 1) return '${d.inMinutes} dk';
    if (d.inHours < 24) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      return m > 0 ? '$h saat $m dk' : '$h saat';
    }
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    return hours > 0 ? '$days gün $hours saat' : '$days gün';
  }

  String _formatEventDate(DateTime dt) {
    const days = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]}, $h:$m';
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;

    // State E — matched: show event date card
    if (state == _CountdownState.matched) {
      final eventDate = widget.inv['event_date'] != null
          ? DateTime.parse(widget.inv['event_date'] as String)
          : null;
      return _buildMatchedCard(eventDate);
    }

    // State F — closed
    if (state == _CountdownState.closed) {
      return _buildClosedCard();
    }

    // States A/B/C/D — countdown
    return _buildCountdownCard(state);
  }

  Widget _buildCountdownCard(_CountdownState state) {
    final String label;
    final String countdownValue;
    final Color accentColor;
    final Color iconBgColor;
    final Color iconColor;
    final Gradient leftBarGradient;
    final bool isGold = state == _CountdownState.waitingApproval;

    switch (state) {
      case _CountdownState.applyPeriod:
        label = 'BAŞVURU İÇİN KALAN';
        countdownValue = _formatDuration(_remaining);
        accentColor = AppColors.gradientStart;
        iconBgColor = AppColors.gradientStart.withOpacity(0.18);
        iconColor = AppColors.gradientStart;
        leftBarGradient = AppColors.primaryGradient;
        break;
      case _CountdownState.waitingSelection:
        label = 'SEÇİM BEKLENİYOR';
        countdownValue = _formatDuration(_remaining);
        accentColor = AppColors.gradientStart;
        iconBgColor = AppColors.gradientStart.withOpacity(0.12);
        iconColor = AppColors.gradientStart;
        leftBarGradient = AppColors.primaryGradient;
        break;
      case _CountdownState.hostDecision:
        label = 'KARAR SÜRENİZ';
        countdownValue = _formatDuration(_remaining);
        accentColor = AppColors.gradientStart;
        iconBgColor = AppColors.gradientStart.withOpacity(0.22);
        iconColor = AppColors.gradientStart;
        leftBarGradient = const LinearGradient(
          colors: [AppColors.gradientStart, AppColors.gradientStart],
        );
        break;
      case _CountdownState.waitingApproval:
        label = 'ONAY BEKLENİYOR';
        countdownValue = '< 1 saat';
        accentColor = AppColors.gold;
        iconBgColor = AppColors.gold.withOpacity(0.15);
        iconColor = AppColors.gold;
        leftBarGradient = LinearGradient(
          colors: [AppColors.gold, AppColors.gold.withOpacity(0.6)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        );
        break;
      default:
        label = '';
        countdownValue = '';
        accentColor = AppColors.gradientStart;
        iconBgColor = AppColors.glassBg;
        iconColor = AppColors.gradientStart;
        leftBarGradient = AppColors.primaryGradient;
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isGold
                  ? AppColors.gold.withOpacity(0.3)
                  : AppColors.glassBorder,
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left accent bar
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    gradient: leftBarGradient,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(17, 18, 20, 18),
                    child: Row(
                      children: [
                        // Icon box
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: iconBgColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: iconColor.withOpacity(0.25),
                            ),
                          ),
                          child: Icon(
                            state == _CountdownState.waitingApproval
                                ? Icons.verified_user_outlined
                                : Icons.access_time_rounded,
                            size: 18,
                            color: iconColor,
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Countdown text
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                countdownValue,
                                style: TextStyle(
                                  fontFamily: 'Fraunces',
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 22,
                                  height: 1.1,
                                  letterSpacing: -0.22,
                                  color: _remaining.inMinutes <= 5 &&
                                          state !=
                                              _CountdownState
                                                  .waitingApproval
                                      ? AppColors.gradientStart
                                      : Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                label,
                                style: const TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.18,
                                  color: Color(0x80FFFFFF),
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Applicant count
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${widget.applicantCount}',
                              style: const TextStyle(
                                fontFamily: 'Fraunces',
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w500,
                                fontSize: 22,
                                color: Colors.white,
                                letterSpacing: -0.22,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'BAŞVURU',
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 9.5,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.18,
                                color: Color(0x80FFFFFF),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchedCard(DateTime? eventDate) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 3,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      bottomLeft: Radius.circular(20),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(17, 18, 20, 18),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.calendar_today_outlined,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Text(
                                eventDate != null
                                    ? _formatEventDate(eventDate)
                                    : 'Yakında',
                                style: const TextStyle(
                                  fontFamily: 'Fraunces',
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 22,
                                  height: 1.1,
                                  letterSpacing: -0.22,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'BULUŞMA',
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: 0.18,
                                  color: Color(0x80FFFFFF),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildClosedCard() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: AppColors.glassBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.glassBorder),
          ),
          child: Row(
            children: [
              Icon(
                Icons.block_outlined,
                size: 20,
                color: Colors.white.withOpacity(0.4),
              ),
              const SizedBox(width: 14),
              Text(
                'Bu davet kapandı',
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withOpacity(0.45),
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
// Description Block
// ─────────────────────────────────────────────────────────────────────────────

class _DescriptionBlock extends StatelessWidget {
  final String text;
  const _DescriptionBlock({required this.text});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(label: 'Davet'),
        const SizedBox(height: 14),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 2,
                margin: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  text,
                  style: const TextStyle(
                    fontFamily: 'Fraunces',
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w400,
                    fontSize: 17,
                    height: 1.55,
                    color: Color(0xE0FFFFFF),
                    letterSpacing: -0.085,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Detail Card (venue + date)
// ─────────────────────────────────────────────────────────────────────────────

class _DetailCard extends StatelessWidget {
  final String? venueName;
  final double? venueLat;
  final double? venueLng;
  final DateTime? eventDate;

  const _DetailCard({
    this.venueName,
    this.venueLat,
    this.venueLng,
    this.eventDate,
  });

  String _formatDate(DateTime dt) {
    const months = [
      'Ocak',
      'Şubat',
      'Mart',
      'Nisan',
      'Mayıs',
      'Haziran',
      'Temmuz',
      'Ağustos',
      'Eylül',
      'Ekim',
      'Kasım',
      'Aralık'
    ];
    const days = [
      'Pazartesi',
      'Salı',
      'Çarşamba',
      'Perşembe',
      'Cuma',
      'Cumartesi',
      'Pazar'
    ];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '${days[dt.weekday - 1]}, ${dt.day} ${months[dt.month - 1]} · $h:$m';
  }

  bool get _hasContent => venueName != null || eventDate != null;

  @override
  Widget build(BuildContext context) {
    if (!_hasContent) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(label: 'Detaylar'),
        const SizedBox(height: 14),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.glassBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Column(
                children: [
                  if (venueName != null)
                    _DetailRow(
                      icon: Icons.location_on_outlined,
                      label: 'Mekan',
                      value: venueName!,
                      action:
                          (venueLat != null && venueLng != null)
                              ? 'Yol Tarifi'
                              : null,
                      hasDivider: eventDate != null,
                    ),
                  if (eventDate != null)
                    _DetailRow(
                      icon: Icons.calendar_today_outlined,
                      label: 'Tarih & Saat',
                      value: _formatDate(eventDate!),
                      hasDivider: false,
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? action;
  final bool hasDivider;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    this.action,
    required this.hasDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
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
                    size: 17,
                    color: Colors.white.withOpacity(0.7)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label.toUpperCase(),
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.18,
                        color: Color(0x73FFFFFF),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                        letterSpacing: -0.075,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null)
                Text(
                  action!,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.blue,
                    letterSpacing: -0.06,
                  ),
                ),
            ],
          ),
        ),
        if (hasDivider)
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.white.withOpacity(0.06),
          ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Host Card
// ─────────────────────────────────────────────────────────────────────────────

class _HostCard extends StatelessWidget {
  final Map<String, dynamic> owner;
  final String? ownerPhotoUrl;
  final VoidCallback onTap;

  const _HostCard({
    required this.owner,
    required this.ownerPhotoUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final verified = owner['verified'] == true;
    final selfieStatus = owner['selfie_status'] as String? ?? 'none';
    final isVerified = verified || selfieStatus == 'approved';
    final name = owner['name'] as String? ?? '—';
    final age = owner['age'] as int?;
    final job = owner['job'] as String?;
    final city = owner['city'] as Map<String, dynamic>?;
    final cityName = city?['name'] as String? ?? '';

    final metaParts = <String>[
      if (job != null && job.isNotEmpty) job,
      if (cityName.isNotEmpty) cityName,
    ];

    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 14, 16, 14),
            decoration: BoxDecoration(
              color: AppColors.glassBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.glassBorder),
            ),
            child: Row(
              children: [
                // Gradient ring avatar
                Container(
                  width: 56,
                  height: 56,
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppColors.primaryGradient,
                  ),
                  child: Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.bgDeep,
                    ),
                    child: ClipOval(
                      child: ownerPhotoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: ownerPhotoUrl!,
                              fit: BoxFit.cover,
                              alignment: Alignment.topCenter,
                              errorWidget: (_, __, ___) => Container(
                                color: AppColors.glassBg,
                                child: const Icon(
                                    Icons.person_outline,
                                    color: AppColors.textSecondary),
                              ),
                            )
                          : Container(
                              color: AppColors.glassBg,
                              child: const Icon(Icons.person_outline,
                                  color: AppColors.textSecondary),
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Name + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Text(
                            age != null ? '$name, $age' : name,
                            style: const TextStyle(
                              fontFamily: 'Fraunces',
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w500,
                              fontSize: 22,
                              color: Colors.white,
                              letterSpacing: -0.22,
                              height: 1.1,
                            ),
                          ),
                          if (isVerified) ...[
                            const SizedBox(width: 8),
                            Container(
                              width: 16,
                              height: 16,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: AppColors.primaryGradient,
                              ),
                              child: const Icon(Icons.check,
                                  size: 10, color: Colors.white),
                            ),
                          ],
                        ],
                      ),
                      if (metaParts.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Text(
                          metaParts.join(' · ').toUpperCase(),
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.16,
                            color: Color(0x8CFFFFFF),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 24,
                  color: Colors.white.withOpacity(0.4),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Section Header
// ─────────────────────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 1,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.gradientStart,
                AppColors.gradientEnd
              ],
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.198,
            color: Color(0x8CFFFFFF),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Glass Icon Button
// ─────────────────────────────────────────────────────────────────────────────

class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0x66000000),
                border: Border.all(color: AppColors.glassBorder),
              ),
              child: Icon(icon, size: 18, color: Colors.white),
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Apply Button
// ─────────────────────────────────────────────────────────────────────────────

class _ApplyButton extends ConsumerStatefulWidget {
  final String invitationId;
  final Map<String, dynamic>? existingApp;
  final VoidCallback onApplied;

  const _ApplyButton({
    required this.invitationId,
    this.existingApp,
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
          const SnackBar(
              content: Text('Başvurunuz gönderildi!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Hata: $e'),
              backgroundColor: AppColors.error),
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
      return ScButton(
          label: 'Gelmek isterim',
          onPressed: _loading ? null : _apply,
          isLoading: _loading);
    }
    final status = app['status'] as String;
    if (status == 'selected') {
      return ScButton(
        label: 'Seçildiniz — Kararınızı verin',
        icon: Icons.favorite_outline,
        onPressed: () => context.push(
            '/invitation/${widget.invitationId}/decision',
            extra: {'applicationId': app['id']}),
      );
    }
    if (status == 'accepted') {
      return ScButton(
          label: '✓ Kabul edildi',
          onPressed: null,
          variant: ScButtonVariant.secondary);
    }
    return ScButton(
        label: 'Başvurdunuz',
        onPressed: null,
        variant: ScButtonVariant.secondary);
  }
}
