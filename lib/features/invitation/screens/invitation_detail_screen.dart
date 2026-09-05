import 'package:soulchoice/core/services/error_reporter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import '../../../core/utils/guard_errors.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../data/models/invitation_model.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../providers/invitation_provider.dart';
import '../providers/my_active_invitation_provider.dart';
import '../../feed/providers/invitations_provider.dart';
import '../providers/my_applications_provider.dart';
import '../../../core/services/funnel_events.dart';
import '../../profile/providers/profile_provider.dart';
import '../../../core/providers/locale_provider.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import '../../../shared/widgets/aurora_snackbar.dart';
import '../../../core/services/photo_focus.dart';

class InvitationDetailScreen extends ConsumerStatefulWidget {
  final String invitationId;
  const InvitationDetailScreen({super.key, required this.invitationId});

  @override
  ConsumerState<InvitationDetailScreen> createState() =>
      _InvitationDetailScreenState();
}

class _InvitationDetailScreenState
    extends ConsumerState<InvitationDetailScreen> {
  final PageController _photoCtrl = PageController();
  int _photoIndex = 0;

  // 24.07: cinsiyetli RU metinleri — provider soğukken 'other'a (eril)
  // düşüyordu (Natalia dialog vakası); cinsiyet bir kez yüklenip saklanır.
  String _myGender = 'other';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadMyGender());
  }

  Future<void> _loadMyGender() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final profile = await ref.read(userProfileProvider(uid).future);
      final g = profile?['gender'] as String?;
      if (mounted && g != null) setState(() => _myGender = g);
    } catch (e, st) {
      ErrorReporter.report(e, stack: st, screen: 'invitation_detail');
    }
  }

  String _currentUserGender() => _myGender;

  @override
  void dispose() {
    _photoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(photoFocusProvider); // yüz odak haritası — gelince rebuild
    final invitationId = widget.invitationId;
    final invAsync = ref.watch(invitationDetailProvider(invitationId));
    final myAppAsync = ref.watch(myApplicationProvider(invitationId));
    final countAsync = ref.watch(applicationCountProvider(invitationId));
    final uid = Supabase.instance.client.auth.currentUser?.id;

    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: invAsync.when(
        loading: () => AmbientBackground(
          child: SafeArea(
            child: Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(AuroraTheme.auroraRed),
                ),
              ),
            ),
          ),
        ),
        error: (e, _) => AmbientBackground(
          child: SafeArea(
            child: Center(
              child: Text(AppLocalizations.of(context)!.error_generic,
                  style: TextStyle(
                      color: AuroraTheme.textSecondary,
                      fontFamily: 'Manrope')),
            ),
          ),
        ),
        data: (inv) {
          if (inv == null) {
            return AmbientBackground(
              child: SafeArea(
                child: Center(
                  child: Text(AppLocalizations.of(context)!.inv_detail_not_found,
                      style: TextStyle(
                          color: AuroraTheme.textSecondary,
                          fontFamily: 'Manrope')),
                ),
              ),
            );
          }

          final owner = inv['owner'] as Map<String, dynamic>?;
          final sortedOwnerPhotos = (inv['owner_photos'] as List<dynamic>? ?? [])
              .cast<Map<String, dynamic>>()
              .toList();
          final ownerPhotoUrl =
              sortedOwnerPhotos.firstOrNull?['url'] as String?;
          final isOwner = uid == inv['owner_id'];
          final category = InvitationCategory.values.firstWhere(
            (c) => c.name == inv['category'],
            orElse: () => InvitationCategory.food,
          );
          final expiresAt = inv['expires_at'] != null
              ? DateTime.parse(inv['expires_at'] as String)
              : DateTime.now();
          final selectionDeadline = inv['selection_deadline'] != null
              ? DateTime.parse(inv['selection_deadline'] as String)
              : null;
          final invStatus = inv['status'] as String? ?? 'active';
          // selecting durumunda kalan süreyi seçim deadline'ına göre hesapla
          final remaining = invStatus == 'selecting' && selectionDeadline != null
              ? selectionDeadline.difference(DateTime.now())
              : expiresAt.difference(DateTime.now());
          final appStatus =
              myAppAsync.asData?.value?['status'] as String?;
          final venueName = inv['venue_name'] as String?;
          final eventDate = inv['event_date'] != null
              ? DateTime.parse(inv['event_date'] as String).toLocal()
              : null;
          final heroH = MediaQuery.of(context).size.height * 0.60;

          return Stack(
            children: [
              // ── Scrollable içerik ──────────────────────────────────
              SingleChildScrollView(
                padding: EdgeInsets.only(
                    bottom: MediaQuery.of(context).padding.bottom + 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── HERO %60 ────────────────────────────────────
                    SizedBox(
                      height: heroH,
                      child: Stack(
                        children: [
                          // a. Ana fotoğraf — PageView
                          if (sortedOwnerPhotos.isNotEmpty)
                            PageView.builder(
                              controller: _photoCtrl,
                              physics: const BouncingScrollPhysics(),
                              scrollDirection: Axis.horizontal,
                              itemCount: sortedOwnerPhotos.length,
                              onPageChanged: (i) => setState(() => _photoIndex = i),
                              itemBuilder: (context, i) {
                                final url = sortedOwnerPhotos[i]['url'] as String?;
                                return GestureDetector(
                                  onTapUp: (details) {
                                    final screenWidth = MediaQuery.of(context).size.width;
                                    if (details.globalPosition.dx < screenWidth / 2) {
                                      if (_photoIndex > 0) {
                                        _photoCtrl.previousPage(
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                      }
                                    } else {
                                      if (_photoIndex < sortedOwnerPhotos.length - 1) {
                                        _photoCtrl.nextPage(
                                          duration: const Duration(milliseconds: 300),
                                          curve: Curves.easeInOut,
                                        );
                                      }
                                    }
                                  },
                                  child: url != null
                                      ? CachedNetworkImage(
                                          imageUrl: url,
                                          fit: BoxFit.cover,
                                          alignment: PhotoFocus.of(url),
                                          errorWidget: (_, __, ___) => _FallbackBg(),
                                        )
                                      : _FallbackBg(),
                                );
                              },
                            )
                          else
                            _FallbackBg(),

                          // a2. Foto dots
                          if (sortedOwnerPhotos.length > 1)
                            Positioned(
                              top: 12,
                              left: 0,
                              right: 0,
                              child: IgnorePointer(
                                child: SafeArea(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(sortedOwnerPhotos.length, (i) {
                                      final active = i == _photoIndex;
                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        margin: const EdgeInsets.symmetric(horizontal: 3),
                                        width: active ? 20 : 5,
                                        height: 5,
                                        decoration: BoxDecoration(
                                          color: active ? Colors.white : Colors.white.withOpacity(0.4),
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                              ),
                            ),

                          // b. Üst scrim
                          Positioned(
                            top: 0,
                            left: 0,
                            right: 0,
                            height: 140,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withOpacity(0.55),
                                      Colors.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // c. Alt fade → bgDeep (4 stop)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: heroH * 0.55,
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [
                                      AuroraTheme.bgDeep,
                                      AuroraTheme.bgDeep.withOpacity(0.80),
                                      AuroraTheme.bgDeep.withOpacity(0.30),
                                      Colors.transparent,
                                    ],
                                    stops: const [0.0, 0.35, 0.65, 1.0],
                                  ),
                                ),
                              ),
                            ),
                          ),


                          // e. Başlık bloğu
                          Positioned(
                            left: 24,
                            right: 24,
                            bottom: 28,
                            child: IgnorePointer(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  inv['title'] as String,
                                  style: TextStyle(
                                    fontFamily: 'Fraunces',
                                    fontStyle: FontStyle.italic,
                                    fontSize: MediaQuery.of(context).size.width < 360 ? 29.0 : 34,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.15,
                                    shadows: const [
                                      Shadow(
                                          blurRadius: 24,
                                          color: Colors.black87)
                                    ],
                                  ),
                                  maxLines: 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 12),
                                Container(
                                  width: 40,
                                  height: 2,
                                  decoration: BoxDecoration(
                                    gradient: AuroraTheme.redBlueGradient,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                ),
                                if (venueName != null ||
                                    eventDate != null) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    [
                                      if (venueName != null) venueName,
                                      if (eventDate != null)
                                        _formatDate(context, eventDate),
                                    ].join(' ·\u00A0'), // nokta sonraki kelimeye yapışık: satır sonunda asılı kalmaz
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'JetBrainsMono',
                                      fontSize: 11,
                                      color:
                                          Colors.white.withOpacity(0.65),
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── CONTENT ─────────────────────────────────────
                    Padding(
                      padding:
                          const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // a. Countdown Strip
                          _CountdownStrip(
                            remaining: remaining,
                            invStatus: invStatus,
                            appStatus: appStatus,
                            isOwner: isOwner,
                            eventDate: eventDate,
                          ),

                          // b. Açıklama
                          if (inv['description'] != null &&
                              (inv['description'] as String)
                                  .isNotEmpty) ...[
                            const SizedBox(height: 28),
                            _SectionHeader(
                                // 11.08 Mustafa kararı: tür ayrımı kartta değil
                                // burada — istek akışında başlık "ЗАПРОС/İSTEK"
                                label: inv['flow_type'] == 'request'
                                    ? AppLocalizations.of(context)!
                                        .inv_detail_section_request
                                    : AppLocalizations.of(context)!
                                        .inv_detail_section_invitation),
                            const SizedBox(height: 12),
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  // D (12.08): çubuk yalnız ilk satır boyunda
                                  Container(
                                    width: 2,
                                    height: 24,
                                    margin:
                                        const EdgeInsets.only(top: 2),
                                    decoration: BoxDecoration(
                                      gradient:
                                          AuroraTheme.redBlueGradient,
                                      borderRadius:
                                          BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Text(
                                      inv['description'] as String,
                                      style: const TextStyle(
                                        fontFamily: 'Fraunces',
                                        fontStyle: FontStyle.italic,
                                        fontSize: 17,
                                        color: Colors.white,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // c. Detaylar
                          if (venueName != null ||
                              eventDate != null) ...[
                            const SizedBox(height: 28),
                            _SectionHeader(label: AppLocalizations.of(context)!.inv_detail_section_details),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                    sigmaX: 20, sigmaY: 20),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: AuroraTheme.glassBg,
                                    borderRadius:
                                        BorderRadius.circular(16),
                                    border: Border.all(
                                        color: AuroraTheme.glassBorder),
                                  ),
                                  child: Column(
                                    children: [
                                      if (venueName != null)
                                        _DetailRow(
                                          icon: Icons.location_on_outlined,
                                          label: venueName,
                                        ),
                                      if (venueName != null &&
                                          eventDate != null)
                                        Divider(
                                            height: 1,
                                            color:
                                                AuroraTheme.glassBorder),
                                      if (eventDate != null)
                                        _DetailRow(
                                          icon: Icons
                                              .calendar_today_outlined,
                                          label: _formatDate(context, eventDate),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // d. Davet Sahibi
                          if (owner != null) ...[
                            const SizedBox(height: 28),
                            if (!isOwner) ...[
                              _SectionHeader(
                                label: inv['flow_type'] == 'invite'
                                    ? AppLocalizations.of(context)!.inv_detail_section_with_whom
                                    : AppLocalizations.of(context)!.inv_detail_section_who,
                              ),
                              const SizedBox(height: 12),
                            ],
                            _HostCard(
                              owner: owner,
                              ownerPhotoUrl: ownerPhotoUrl,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // ── Sticky CTA ─────────────────────────────────────────
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: ClipRect(
                  child: BackdropFilter(
                    filter:
                        ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AuroraTheme.bgDeep.withOpacity(0.88),
                        border: Border(
                            top: BorderSide(
                                color: AuroraTheme.glassBorder)),
                      ),
                      padding: EdgeInsets.fromLTRB(
                        20,
                        12,
                        20,
                        MediaQuery.of(context).padding.bottom + 12,
                      ),
                      child: isOwner
                          ? _AuroraCTA(
                              label: AppLocalizations.of(context)!.inv_detail_applicants_btn,
                              icon: Icons.people_outline,
                              onPressed: () => context.push(
                                  '/invitation/$invitationId/applicants'),
                            )
                          : myAppAsync.when(
                              loading: () => _AuroraCTA(
                                  label: AppLocalizations.of(context)!.inv_detail_loading,
                                  onPressed: null),
                              // Geçici hata (ör. o anda süresi dolmuş oturum
                              // token'ı → 401): ölü "Ошибка" yerine tek
                              // dokunuşla yeniden dene.
                              error: (_, __) => _AuroraCTA(
                                  label: AppLocalizations.of(context)!.inv_detail_retry,
                                  onPressed: () => ref.invalidate(
                                      myApplicationProvider(invitationId))),
                              data: (myApp) => _ApplyButton(
                                invitationId: invitationId,
                                existingApp: myApp,
                                isRequestFlow:
                                    inv['flow_type'] == 'request',
                                invStatus: invStatus,
                                expiresAt: expiresAt,
                                onApplied: () {
                                  ref.invalidate(
                                      myApplicationProvider(invitationId));
                                  // Feed kartındaki CTA "beklemede"ye dönsün
                                  ref.refreshFeed();
                                  // Profildeki "Başvurularım" bayat kalmasın
                                  // (29.07: 5 başvurudan 1'i görünüyordu)
                                  ref.invalidate(myApplicationsListProvider);
                                  // Başlıktaki "N başvuru" sayacı da (31.07)
                                  ref.invalidate(
                                      applicationCountProvider(invitationId));
                                },
                              ),
                            ),
                    ),
                  ),
                ),
              ),
              // ── Pinned top bar (scroll ile kaybolmaz) ──────────
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        _GlassPill(
                          onTap: () => context.pop(),
                          child: const Icon(
                              Icons.arrow_back_ios_new,
                              size: 16,
                              color: Colors.white),
                        ),
                        const Spacer(),
                        _GlassPill(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              category == InvitationCategory.bar
                                  ? Image.asset('assets/icons/bar.png', width: 14, height: 14)
                                  : category == InvitationCategory.concert
                                      ? Image.asset('assets/icons/music.png',
                                          width: 11, height: 11,
                                          color: AuroraTheme.auroraRed)
                                      : Text(category.emoji,
                                          style: const TextStyle(fontSize: 13)),
                              const SizedBox(width: 4),
                              Text(
                                category.labelFor(AppLocalizations.of(context)!),
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 10,
                                  color: Colors.white
                                      .withOpacity(0.85),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isOwner) ...[
                          const SizedBox(width: 8),
                          _GlassPill(
                            onTap: () => context.push(
                                '/invitation/$invitationId/applicants'),
                            child: const Icon(
                                Icons.people_outline,
                                size: 18,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          _GlassPill(
                            onTap: () => context.push(
                              '/invitation/edit',
                              extra: {
                                'id': invitationId,
                                'flow_type': inv['flow_type'] as String?,
                                'category': inv['category'] as String?,
                                'title': inv['title'] as String? ?? '',
                                'description': inv['description'] as String?,
                                'venue_name': inv['venue_name'] as String?,
                                'event_date': inv['event_date'] as String?,
                              },
                            ),
                            child: const Icon(
                                Icons.edit_outlined,
                                size: 18,
                                color: Colors.white),
                          ),
                          const SizedBox(width: 8),
                          _GlassPill(
                            onTap: () async {
                              final confirm =
                                  await showDialog<bool>(
                                context: context,
                                builder: (ctx) {
                                  final l = AppLocalizations.of(ctx)!;
                                  return AlertDialog(
                                  backgroundColor:
                                      AuroraTheme.bgDeep,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(
                                              20)),
                                  title: Text(
                                      l.inv_detail_delete_title,
                                      style: const TextStyle(
                                          fontFamily: 'Fraunces',
                                          fontStyle:
                                              FontStyle.italic,
                                          color: Colors.white,
                                          fontSize: 20)),
                                  content: Text(
                                      l.inv_detail_delete_body(_currentUserGender()),
                                      style: TextStyle(
                                          fontFamily: 'Manrope',
                                          color: AuroraTheme
                                              .textSecondary,
                                          fontSize: 14)),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx)
                                              .pop(false),
                                      child: Text(l.inv_detail_delete_cancel,
                                          style: TextStyle(
                                              fontFamily:
                                                  'JetBrainsMono',
                                              color: AuroraTheme
                                                  .textMuted)),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.of(ctx)
                                              .pop(true),
                                      child: Text(l.inv_detail_delete_confirm,
                                          style: const TextStyle(
                                              fontFamily:
                                                  'JetBrainsMono',
                                              color: AuroraTheme
                                                  .auroraRed,
                                              fontWeight:
                                                  FontWeight.w700)),
                                    ),
                                  ],
                                );},
                              );
                              if (confirm == true &&
                                  context.mounted) {
                                try {
                                  await Supabase.instance.client
                                      .from('invitations')
                                      .delete()
                                      .eq('id', invitationId);
                                  ref.invalidate(
                                      invitationDetailProvider);
                                  ref.refreshFeed();
                                  ref.invalidate(
                                      myActiveInvitationsProvider);
                                  if (context.mounted) {
                                    context.pop();
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(auroraSnackBar(
                                            AppLocalizations.of(context)!
                                                .error_generic));
                                  }
                                }
                              }
                            },
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
            ],
          );
        },
      ),
    );
  }

  String _formatDate(BuildContext context, DateTime dt) {
    final l10n = AppLocalizations.of(context)!;
    final days = [
      l10n.inv_detail_weekday_mon_full, l10n.inv_detail_weekday_tue_full,
      l10n.inv_detail_weekday_wed_full, l10n.inv_detail_weekday_thu_full,
      l10n.inv_detail_weekday_fri_full, l10n.inv_detail_weekday_sat_full,
      l10n.inv_detail_weekday_sun_full,
    ];
    final day = days[dt.weekday - 1];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$day, $h:$m';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// YENİ: Countdown Strip
// ─────────────────────────────────────────────────────────────────────────────
class _CountdownStrip extends StatelessWidget {
  final Duration remaining;
  final String invStatus;
  final String? appStatus;
  final bool isOwner;
  final DateTime? eventDate;

  const _CountdownStrip({
    required this.remaining,
    required this.invStatus,
    required this.appStatus,
    required this.isOwner,
    this.eventDate,
  });

  String _label(AppLocalizations l10n) {
    if (invStatus == 'closed' || invStatus == 'cancelled') return l10n.inv_detail_status_closed;
    if (appStatus == 'accepted') return l10n.inv_detail_status_meeting;
    if (invStatus == 'selecting' && isOwner) return l10n.inv_detail_status_selecting;
    if (isOwner) return l10n.inv_detail_status_decision;
    if (appStatus != null) return l10n.inv_detail_status_awaiting;
    return l10n.inv_detail_status_remaining;
  }

  String _value(AppLocalizations l10n) {
    if (invStatus == 'closed' || invStatus == 'cancelled') {
      // Başvuran ve seçilmemiş (accepted değil) → "seçim yapılmadı" (product-logic §4)
      if (appStatus != null && appStatus != 'accepted') {
        return l10n.inv_detail_status_not_selected;
      }
      return '—';
    }
    if (appStatus == 'accepted') {
      if (eventDate != null) {
        final days = [
          l10n.inv_detail_day_mon, l10n.inv_detail_day_tue,
          l10n.inv_detail_day_wed, l10n.inv_detail_day_thu,
          l10n.inv_detail_day_fri, l10n.inv_detail_day_sat,
          l10n.inv_detail_day_sun,
        ];
        final d = eventDate!;
        return '${days[d.weekday - 1]} '
            '${d.hour.toString().padLeft(2, '0')}:'
            '${d.minute.toString().padLeft(2, '0')}';
      }
      return '—';
    }
    if (remaining.isNegative) return l10n.inv_detail_status_expired;
    if (remaining.inDays >= 1) return l10n.inv_detail_duration_days_hours(remaining.inDays, remaining.inHours % 24);
    if (remaining.inHours >= 1) return l10n.inv_detail_duration_hours_min(remaining.inHours, remaining.inMinutes % 60);
    return l10n.inv_detail_duration_min(remaining.inMinutes);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isClosed =
        invStatus == 'closed' || invStatus == 'cancelled';
    final label = _label(l10n);
    final value = _value(l10n);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: AuroraTheme.glassBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AuroraTheme.glassBorder),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Sol gradient kenar (D 12.08: incelt)
                Container(
                  width: 2,
                  decoration: BoxDecoration(
                    gradient:
                        isClosed ? null : AuroraTheme.redBlueGradient,
                    color: isClosed
                        ? Colors.white.withOpacity(0.12)
                        : null,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    child: Row(
                      children: [
                        // İkon kutusu
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: isClosed
                                ? Colors.white.withOpacity(0.05)
                                : AuroraTheme.auroraRed
                                    .withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            isClosed
                                ? Icons.block_outlined
                                : Icons.schedule_rounded,
                            size: 18,
                            color: isClosed
                                ? Colors.white.withOpacity(0.30)
                                : AuroraTheme.auroraRed,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              value,
                              style: TextStyle(
                                fontFamily: 'Fraunces',
                                fontStyle: FontStyle.italic,
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: isClosed
                                    ? Colors.white.withOpacity(0.30)
                                    : Colors.white,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              label,
                              style: TextStyle(
                                fontFamily: 'JetBrainsMono',
                                fontSize: 9,
                                color: Colors.white.withOpacity(
                                    isClosed ? 0.22 : 0.45),
                                letterSpacing: 0.3,
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
}

// ─────────────────────────────────────────────────────────────────────────────
// YENİ: Section Header
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          // D — Rafine İmza (12.08): kısa, radius'lu, zarif
          Container(
            width: 14,
            height: 2,
            decoration: BoxDecoration(
              gradient: AuroraTheme.redBlueGradient,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontFamily: 'JetBrainsMono',
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.18,
              color: Colors.white.withOpacity(0.55),
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// YENİ: Detail Row
// ─────────────────────────────────────────────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;

  const _DetailRow({
    required this.icon,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: [
            Icon(icon, size: 15, color: AuroraTheme.auroraRed),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// YENİ: Host Card
// ─────────────────────────────────────────────────────────────────────────────
class _HostCard extends ConsumerWidget {
  final Map<String, dynamic> owner;
  final String? ownerPhotoUrl;

  const _HostCard({required this.owner, this.ownerPhotoUrl});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final job = owner['job'] as String?;
    final city = owner['city'] as Map<String, dynamic>?;
    final lang = ref.watch(localeProvider)?.languageCode;
    String? cityName;
    if (lang == 'ru') cityName = city?['name_ru'] as String?;
    else if (lang == 'tr') cityName = city?['name_tr'] as String?;
    else cityName = city?['name_en'] as String?;
    cityName ??= city?['name'] as String?;
    final metaParts = [
      if (job != null && job.isNotEmpty) job,
      if (cityName != null && cityName.isNotEmpty) cityName,
    ].join(' · ');

    return GestureDetector(
      onTap: () => context.push('/profile/${owner['id']}'),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AuroraTheme.glassBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AuroraTheme.glassBorder),
            ),
            child: Row(
              children: [
                // Avatar + gradient halka
                Container(
                  width: 40,
                  height: 40,
                  padding: const EdgeInsets.all(1.5),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AuroraTheme.auroraRed, AuroraTheme.auroraBlue],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: ClipOval(
                    child: ownerPhotoUrl != null
                        ? CachedNetworkImage(
                            imageUrl: ownerPhotoUrl!,
                            fit: BoxFit.cover,
                            alignment: PhotoFocus.of(ownerPhotoUrl),
                            errorWidget: (_, __, ___) => Container(
                              color: AuroraTheme.glassBg,
                              child: const Icon(Icons.person_outline,
                                  color: Colors.white54, size: 20),
                            ),
                          )
                        : Container(
                            color: AuroraTheme.glassBg,
                            child: const Icon(Icons.person_outline,
                                color: Colors.white54, size: 20),
                          ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              owner['name'] as String? ?? '',
                              style: const TextStyle(
                                fontFamily: 'Fraunces',
                                fontStyle: FontStyle.italic,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (metaParts.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          metaParts,
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 9,
                            color: Colors.white.withOpacity(0.38),
                            letterSpacing: 0.3,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 18,
                    color: Colors.white.withOpacity(0.28)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mevcut widget'lar — değiştirilmedi
// ─────────────────────────────────────────────────────────────────────────────

class _FallbackBg extends StatelessWidget {
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

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoPill(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: color.withOpacity(0.30)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: color),
                const SizedBox(width: 5),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.90),
                      letterSpacing: 0.2,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

class _HostRow extends StatelessWidget {
  final Map<String, dynamic> owner;
  final String? ownerPhotoUrl;
  final String invitationId;
  const _HostRow(
      {required this.owner,
      this.ownerPhotoUrl,
      required this.invitationId});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => context.push('/profile/${owner['id']}'),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.38),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(1.5),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AuroraTheme.auroraRed, AuroraTheme.auroraBlue],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: ClipOval(
                      child: ownerPhotoUrl != null
                          ? CachedNetworkImage(
                              imageUrl: ownerPhotoUrl!,
                              fit: BoxFit.cover,
                              alignment: PhotoFocus.of(ownerPhotoUrl),
                              errorWidget: (_, __, ___) => Container(
                                color: AuroraTheme.glassBg,
                                child: const Icon(Icons.person_outline,
                                    color: Colors.white54, size: 20),
                              ),
                            )
                          : Container(
                              color: AuroraTheme.glassBg,
                              child: const Icon(Icons.person_outline,
                                  color: Colors.white54, size: 20),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${owner['name']}, ${owner['age']}',
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontWeight: FontWeight.w700,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          AppLocalizations.of(context)!.inv_detail_host_label,
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 9,
                            color: Colors.white.withOpacity(0.38),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_forward_ios,
                      size: 13,
                      color: Colors.white.withOpacity(0.25)),
                ],
              ),
            ),
          ),
        ),
      );
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
                color: Colors.black.withOpacity(0.4),
                borderRadius: BorderRadius.circular(100),
                border:
                    Border.all(color: Colors.white.withOpacity(0.18)),
              ),
              child: child,
            ),
          ),
        ),
      );
}

class _AuroraCTA extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  // Olumlu sonuç durumları (ör. "Принято"): tıklanmaz ama gri-disabled değil,
  // aura gradient'iyle gösterilir.
  final bool highlight;

  const _AuroraCTA(
      {required this.label,
      required this.onPressed,
      this.icon,
      this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final vivid = onPressed != null || highlight;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: vivid
            ? AuroraTheme.redBlueGradient
            : const LinearGradient(
                colors: [Color(0xFF444444), Color(0xFF333333)]),
        borderRadius: BorderRadius.circular(100),
        boxShadow: vivid
            ? [
                BoxShadow(
                  color: AuroraTheme.auroraRed.withOpacity(0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(100),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
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
                    fontFamily: 'Manrope',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ApplyButton extends ConsumerStatefulWidget {
  final String invitationId;
  final Map<String, dynamic>? existingApp;
  final bool isRequestFlow;
  final VoidCallback onApplied;
  final String invStatus;
  final DateTime? expiresAt;

  const _ApplyButton(
      {required this.invitationId,
      this.existingApp,
      this.isRequestFlow = false,
      required this.onApplied,
      this.invStatus = 'active',
      this.expiresAt});

  @override
  ConsumerState<_ApplyButton> createState() => _ApplyButtonState();
}

class _ApplyButtonState extends ConsumerState<_ApplyButton> {
  bool _loading = false;

  Future<void> _apply() async {
    if (widget.invStatus != 'active') return;
    if (widget.expiresAt != null && DateTime.now().isAfter(widget.expiresAt!)) return;
    setState(() => _loading = true);
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser!.id;
      // Owner self-apply guard
      final ownerRow = await client
          .from('invitations')
          .select('owner_id, status, expires_at')
          .eq('id', widget.invitationId)
          .maybeSingle();
      if (ownerRow == null ||
          ownerRow['owner_id'] == uid ||
          ownerRow['status'] != 'active' ||
          (ownerRow['expires_at'] != null &&
              DateTime.now()
                  .isAfter(DateTime.parse(ownerRow['expires_at'] as String)))) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      // Paywall gate: premium aktif değilse ve ücretsiz hak kullanıldıysa → /paywall
      final canApply = await client.rpc('can_user_apply', params: {'p_user_id': uid}) as bool? ?? false;
      if (!canApply) {
        if (mounted) {
          setState(() => _loading = false);
          context.push('/paywall');
        }
        return;
      }
      await client.from('applications').upsert({
        'invitation_id': widget.invitationId,
        'applicant_id': uid,
        'status': 'pending',
      }, onConflict: 'invitation_id,applicant_id');
      // Sahibin push'u sunucudan gider: trg_notify_new_application (26.07 madde X)
      funnelEventOnce('first_apply');

      // 19.08 (Mustafa): 3 ücretsiz hak — premium değilse kalan hakkı göster.
      int? freeLeft;
      try {
        // 03.09: free_applications_used özel kolon — kendi değeri RPC'den.
        final meRaw = await client.rpc('my_private_profile');
        final me = meRaw is Map ? Map<String, dynamic>.from(meRaw) : null;
        if (me != null) {
          final premiumUntil = DateTime.tryParse(me['premium_until'] as String? ?? '');
          final isPremium = me['subscription_status'] == 'active' ||
              (premiumUntil != null && premiumUntil.isAfter(DateTime.now()));
          if (!isPremium) {
            freeLeft = (3 - ((me['free_applications_used'] as int?) ?? 0)).clamp(0, 3);
          }
        }
      } catch (_) {
        freeLeft = null; // göstergesiz devam — başvuru zaten gitti
      }

      widget.onApplied();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.transparent,
            elevation: 0,
            // Özel tasarımlı içerik: global temanın çerçevesini devralma
            shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(18))),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 110),
            padding: EdgeInsets.zero,
            duration: const Duration(seconds: 3),
            content: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 18, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF0D0D14),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: AuroraTheme.auroraRed.withOpacity(0.38),
                ),
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
                      Text(
                        AppLocalizations.of(context)!.inv_detail_apply_sent_title,
                        style: const TextStyle(
                          fontFamily: 'Fraunces',
                          fontStyle: FontStyle.italic,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.isRequestFlow
                            ? AppLocalizations.of(context)!
                                .inv_detail_apply_sent_body_request
                            : AppLocalizations.of(context)!
                                .inv_detail_apply_sent_body,
                        style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.50),
                        ),
                      ),
                      if (freeLeft != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          AppLocalizations.of(context)!
                              .inv_detail_free_left(freeLeft),
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.78),
                          ),
                        ),
                      ],
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
        // Bilinen guard hataları (selfie/limit/askı/kapalı ilan) lokalize
        // mesaj + doğru CTA; ham e.toString() yalnız bilinmeyen hatada.
        final guard = await GuardError.resolve(context, e);
        if (!mounted) return;
        if (guard != null) {
          WidgetsBinding.instance
              .addPostFrameCallback((_) => guard.navigate(context));
        }
        showAuroraErrorSnack(
          context,
          guard?.message ??
              AppLocalizations.of(context)!
                  .inv_detail_error(AppLocalizations.of(context)!.error_generic),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // 24.07: provider soğukken 'other'a (eril) düşmesin — dialogdan önce await edilir.
  Future<String> _currentUserGender() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return 'other';
    try {
      final profile = await ref.read(userProfileProvider(uid).future);
      return profile?['gender'] as String? ?? 'other';
    } catch (_) {
      return 'other';
    }
  }

  Future<void> _withdraw() async {
    final gender = await _currentUserGender();
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final l = AppLocalizations.of(ctx)!;
        return AlertDialog(
        backgroundColor: AuroraTheme.bgDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.inv_detail_withdraw_title,
            style: const TextStyle(fontFamily: 'Fraunces', fontStyle: FontStyle.italic, color: Colors.white, fontSize: 18)),
        content: Text(l.inv_detail_withdraw_body(gender),
            style: TextStyle(fontFamily: 'Manrope', color: AuroraTheme.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(l.inv_detail_withdraw_cancel, style: TextStyle(fontFamily: 'JetBrainsMono', color: AuroraTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(l.inv_detail_withdraw_confirm, style: const TextStyle(fontFamily: 'JetBrainsMono', color: AuroraTheme.auroraRed, fontWeight: FontWeight.w700)),
          ),
        ],
      );},
    );
    if (confirm != true || !mounted) return;
    setState(() => _loading = true);
    try {
      final appId = widget.existingApp!['id'] as String;
      await Supabase.instance.client
          .from('applications')
          .update({'status': 'withdrawn'})
          .eq('id', appId);
      widget.onApplied();
    } catch (e) {
      if (mounted) {
        showAuroraErrorSnack(
          context,
          AppLocalizations.of(context)!
              .inv_detail_error(AppLocalizations.of(context)!.error_generic),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openChat() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      // 20.08 vakası: bir-çift-bir-sohbet rebind'i öncesinde eşleşme ters yönlü
      // olabilir (başvuran user1'de) — tek tarafa bakmak matchsiz sanıp yedek
      // yola düşürüyordu. İki yönü de ara.
      final row = await Supabase.instance.client
          .from('matches')
          .select('id')
          .eq('invitation_id', widget.invitationId)
          .or('user1_id.eq.$uid,user2_id.eq.$uid')
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (!mounted) return;
      final matchId = row?['id'] as String?;
      if (matchId != null) {
        context.push('/chat/$matchId');
      } else {
        // /messages bir shell-dalı rotası: push() root'a ikinci bir shell diker
        // (karanlık ekran + Mesajlar sekmesi kilidi, S24 kanıtlı) — go() şart.
        context.go('/messages');
      }
    } catch (err, stk) {
      ErrorReporter.report(err, stack: stk, screen: 'invitation_detail:apply'); // 04.09: sessiz hata Kovan'a
      if (mounted) context.go('/messages');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final app = widget.existingApp;
    // 24.07 denetim: süresi dolmuş/kapalı ilanda buton "Başvur" gibi durup
    // sessizce hiçbir şey yapmasın — pasif "Süresi doldu" göster
    final inactive = widget.invStatus != 'active' ||
        (widget.expiresAt != null &&
            DateTime.now().isAfter(widget.expiresAt!));
    if (app == null) {
      if (inactive) {
        return _AuroraCTA(
            label: l10n.inv_detail_status_expired, onPressed: null);
      }
      return _AuroraCTA(
        label: _loading
            ? l10n.inv_detail_apply_sending
            : (widget.isRequestFlow ? l10n.inv_detail_apply_request : l10n.inv_detail_apply_invite),
        onPressed: _loading ? null : _apply,
      );
    }
    final status = app['status'] as String;
    if (status == 'selected') {
      return _AuroraCTA(
        label: l10n.inv_detail_selected_btn,
        icon: Icons.favorite_outline,
        // applicantId eksikti → DecisionScreen'de Kabul sessiz no-op'tu (31.07 Y5)
        onPressed: () => context.push(
            '/invitation/${widget.invitationId}/decision',
            extra: {
              'applicationId': app['id'],
              'applicantId': Supabase.instance.client.auth.currentUser?.id,
            }),
      );
    }
    if (status == 'accepted') {
      // 11.08 (Mustafa, seçenek A): kabul sonrası buton ölü durmaz — sohbete
      // götürür. Match yoksa (engelleme ile silinmiş olabilir) Mesajlar'a düşer.
      return _AuroraCTA(
          label: l10n.inv_detail_accepted_chat_btn,
          onPressed: _openChat,
          highlight: true);
    }
    if (status == 'rejected') {
      // NİHAİ (Mustafa 11.08 gece): reddedilen net görsün, umutlanmasın —
      // profildeki gri ЗАВЕРШЕНО rozetiyle tutarlı, aksiyonsuz.
      return _AuroraCTA(label: l10n.app_status_closed, onPressed: null);
    }
    if (status == 'expired') {
      return _AuroraCTA(
          label: l10n.inv_detail_status_awaiting, onPressed: null);
    }
    return _AuroraCTA(
      label: _loading ? l10n.inv_detail_withdrawing : l10n.inv_detail_withdraw_btn,
      icon: Icons.undo_rounded,
      onPressed: _loading ? null : _withdraw,
    );
  }
}





