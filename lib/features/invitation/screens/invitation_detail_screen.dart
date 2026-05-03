import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import '../../../core/theme/aurora_theme.dart';
import '../../../data/models/invitation_model.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../providers/invitation_provider.dart';
import '../../feed/providers/invitations_provider.dart';

class InvitationDetailScreen extends ConsumerStatefulWidget {
  final String invitationId;
  const InvitationDetailScreen({super.key, required this.invitationId});

  @override
  ConsumerState<InvitationDetailScreen> createState() =>
      _InvitationDetailScreenState();
}

class _InvitationDetailScreenState
    extends ConsumerState<InvitationDetailScreen> {
  final _photoCtrl = PageController();
  int _photoPage = 0;

  @override
  void dispose() {
    _photoCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              child: Text('$e',
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
                  child: Text('Davet bulunamadı',
                      style: TextStyle(
                          color: AuroraTheme.textSecondary,
                          fontFamily: 'Manrope')),
                ),
              ),
            );
          }

          final owner = inv['owner'] as Map<String, dynamic>?;
          final ownerPhotos = (owner?['photos'] as List<dynamic>?) ?? [];
          final sortedOwnerPhotos = ownerPhotos
              .cast<Map<String, dynamic>>()
              .where((p) => p['is_selfie'] == false)
              .toList()
            ..sort((a, b) => (a['order_index'] as int? ?? 99)
                .compareTo(b['order_index'] as int? ?? 99));
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
          final remaining = expiresAt.difference(DateTime.now());
          final invStatus = inv['status'] as String? ?? 'active';
          final appStatus =
              myAppAsync.asData?.value?['status'] as String?;
          final venueName = inv['venue_name'] as String?;
          final eventDate = inv['event_date'] != null
              ? DateTime.parse(inv['event_date'] as String)
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
                          // a. Fotoğraf carousel
                          Positioned.fill(
                            child: sortedOwnerPhotos.isEmpty
                                ? _FallbackBg()
                                : PageView.builder(
                                    controller: _photoCtrl,
                                    itemCount: sortedOwnerPhotos.length,
                                    onPageChanged: (i) =>
                                        setState(() => _photoPage = i),
                                    itemBuilder: (_, i) {
                                      final url = sortedOwnerPhotos[i]
                                          ['url'] as String?;
                                      return url != null
                                          ? CachedNetworkImage(
                                              imageUrl: url,
                                              fit: BoxFit.cover,
                                              alignment: Alignment.topCenter,
                                              errorWidget: (_, __, ___) =>
                                                  _FallbackBg(),
                                            )
                                          : _FallbackBg();
                                    },
                                  ),
                          ),
                          // a2. Foto sayfa noktaları
                          if (sortedOwnerPhotos.length > 1)
                            Positioned(
                              top: MediaQuery.of(context).padding.top + 56,
                              left: 0,
                              right: 0,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(
                                  sortedOwnerPhotos.length,
                                  (i) => AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.symmetric(horizontal: 3),
                                    width: i == _photoPage ? 16 : 5,
                                    height: 5,
                                    decoration: BoxDecoration(
                                      color: i == _photoPage
                                          ? Colors.white
                                          : Colors.white.withOpacity(0.35),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
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

                          // c. Alt fade → bgDeep (4 stop)
                          Positioned(
                            bottom: 0,
                            left: 0,
                            right: 0,
                            height: heroH * 0.55,
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

                          // d. Top bar
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
                                          Text(category.emoji,
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                          const SizedBox(width: 4),
                                          Text(
                                            category.label,
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
                                        onTap: () async {
                                          final confirm =
                                              await showDialog<bool>(
                                            context: context,
                                            builder: (ctx) => AlertDialog(
                                              backgroundColor:
                                                  AuroraTheme.bgDeep,
                                              shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(
                                                          20)),
                                              title: const Text(
                                                  'Daveti sil',
                                                  style: TextStyle(
                                                      fontFamily: 'Fraunces',
                                                      fontStyle:
                                                          FontStyle.italic,
                                                      color: Colors.white,
                                                      fontSize: 20)),
                                              content: Text(
                                                  'Bu daveti silmek istiyor musun? Geri alınamaz.',
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
                                                  child: Text('Vazgeç',
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
                                                  child: const Text('Sil',
                                                      style: TextStyle(
                                                          fontFamily:
                                                              'JetBrainsMono',
                                                          color: AuroraTheme
                                                              .auroraRed,
                                                          fontWeight:
                                                              FontWeight.w700)),
                                                ),
                                              ],
                                            ),
                                          );
                                          if (confirm == true &&
                                              context.mounted) {
                                            await Supabase.instance.client
                                                .from('invitations')
                                                .delete()
                                                .eq('id', invitationId);
                                            ref.invalidate(
                                                invitationDetailProvider);
                                            ref.invalidate(
                                                invitationsProvider);
                                            if (context.mounted) {
                                              context.pop();
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

                          // e. Başlık bloğu
                          Positioned(
                            left: 24,
                            right: 24,
                            bottom: 28,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  inv['title'] as String,
                                  style: const TextStyle(
                                    fontFamily: 'Fraunces',
                                    fontStyle: FontStyle.italic,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                    height: 1.15,
                                    shadows: [
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
                                        _formatDate(eventDate),
                                    ].join(' · '),
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
                            const _SectionHeader(label: 'DAVET'),
                            const SizedBox(height: 12),
                            IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment:
                                    CrossAxisAlignment.stretch,
                                children: [
                                  Container(
                                    width: 2,
                                    decoration: BoxDecoration(
                                      gradient:
                                          AuroraTheme.redBlueGradient,
                                      borderRadius:
                                          BorderRadius.circular(1),
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
                            const _SectionHeader(label: 'DETAYLAR'),
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
                                          icon:
                                              Icons.location_on_outlined,
                                          label: venueName,
                                          trailing: Text(
                                            'Yol Tarifi',
                                            style: TextStyle(
                                              fontFamily: 'JetBrainsMono',
                                              fontSize: 10,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  AuroraTheme.auroraBlue,
                                            ),
                                          ),
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
                                          label: _formatDate(eventDate),
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
                            const _SectionHeader(label: 'DAVET SAHİBİ'),
                            const SizedBox(height: 12),
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
                              label: 'Başvuranları Gör',
                              icon: Icons.people_outline,
                              onPressed: () => context.push(
                                  '/invitation/$invitationId/applicants'),
                            )
                          : myAppAsync.when(
                              loading: () => const _AuroraCTA(
                                  label: 'Yükleniyor...',
                                  onPressed: null),
                              error: (_, __) => const _AuroraCTA(
                                  label: 'Hata', onPressed: null),
                              data: (myApp) => _ApplyButton(
                                invitationId: invitationId,
                                existingApp: myApp,
                                isRequestFlow:
                                    inv['flow_type'] == 'request',
                                onApplied: () => ref.invalidate(
                                    myApplicationProvider(invitationId)),
                              ),
                            ),
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

  String _formatDate(DateTime dt) {
    const days = [
      'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe',
      'Cuma', 'Cumartesi', 'Pazar'
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

  String _label() {
    if (invStatus == 'closed' || invStatus == 'cancelled') {
      return 'Bu davet kapandı';
    }
    if (appStatus == 'accepted') return 'Buluşma';
    if (isOwner) return 'KARAR SÜRENİZ';
    if (appStatus != null) return 'SEÇİM BEKLENİYOR';
    return 'BAŞVURU İÇİN KALAN';
  }

  String _value() {
    if (invStatus == 'closed' || invStatus == 'cancelled') return '—';
    if (appStatus == 'accepted') {
      if (eventDate != null) {
        const days = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
        final d = eventDate!;
        return '${days[d.weekday - 1]} '
            '${d.hour.toString().padLeft(2, '0')}:'
            '${d.minute.toString().padLeft(2, '0')}';
      }
      return '—';
    }
    if (remaining.isNegative) return 'Sona erdi';
    if (remaining.inDays >= 1) {
      return '${remaining.inDays} gün ${remaining.inHours % 24} saat';
    }
    if (remaining.inHours >= 1) {
      return '${remaining.inHours} saat ${remaining.inMinutes % 60} dk';
    }
    return '${remaining.inMinutes} dk';
  }

  @override
  Widget build(BuildContext context) {
    final isClosed =
        invStatus == 'closed' || invStatus == 'cancelled';

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
                // Sol 3px gradient çizgi
                Container(
                  width: 3,
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
                              _value(),
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
                              _label(),
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
          Container(
            width: 40,
            height: 1,
            decoration: BoxDecoration(
              gradient: AuroraTheme.redBlueGradient,
            ),
          ),
          const SizedBox(width: 12),
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
class _HostCard extends StatelessWidget {
  final Map<String, dynamic> owner;
  final String? ownerPhotoUrl;

  const _HostCard({required this.owner, this.ownerPhotoUrl});

  @override
  Widget build(BuildContext context) {
    final verified = owner['verified'] == true ||
        (owner['selfie_status'] as String? ?? '') == 'approved';
    final job = owner['job'] as String?;
    final cityName =
        (owner['city'] as Map<String, dynamic>?)?['name'] as String?;
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
                            alignment: Alignment.topCenter,
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
                          if (verified) ...[
                            const SizedBox(width: 5),
                            Container(
                              width: 13,
                              height: 13,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: AuroraTheme.auroraBlue,
                              ),
                              child: const Icon(Icons.check,
                                  color: Colors.white, size: 8),
                            ),
                          ],
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
                              alignment: Alignment.topCenter,
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
                          'Davet sahibi',
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
                  if (owner['verified'] == true) ...[
                    Container(
                      width: 18,
                      height: 18,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AuroraTheme.auroraBlue,
                        boxShadow: [
                          BoxShadow(
                            color: AuroraTheme.auroraBlue.withOpacity(0.5),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check,
                          color: Colors.white, size: 11),
                    ),
                  ],
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

  const _AuroraCTA(
      {required this.label, required this.onPressed, this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: onPressed != null
            ? AuroraTheme.redBlueGradient
            : const LinearGradient(
                colors: [Color(0xFF444444), Color(0xFF333333)]),
        borderRadius: BorderRadius.circular(100),
        boxShadow: onPressed != null
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

  const _ApplyButton(
      {required this.invitationId,
      this.existingApp,
      this.isRequestFlow = false,
      required this.onApplied});

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
                      const Text(
                        'Başvurun Gönderildi',
                        style: TextStyle(
                          fontFamily: 'Fraunces',
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
                          fontFamily: 'Manrope',
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

  Future<void> _withdraw() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuroraTheme.bgDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Başvuruyu geri al',
            style: TextStyle(fontFamily: 'Fraunces', fontStyle: FontStyle.italic, color: Colors.white, fontSize: 18)),
        content: Text('Bu davete olan başvurunu geri almak istediğine emin misin?',
            style: TextStyle(fontFamily: 'Manrope', color: AuroraTheme.textSecondary, fontSize: 14)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('Vazgeç', style: TextStyle(fontFamily: 'JetBrainsMono', color: AuroraTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Geri Al', style: TextStyle(fontFamily: 'JetBrainsMono', color: AuroraTheme.auroraRed, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _loading = true);
    try {
      final appId = widget.existingApp!['id'] as String;
      await Supabase.instance.client.from('applications').delete().eq('id', appId);
      widget.onApplied();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e'), backgroundColor: AuroraTheme.auroraRed),
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
      return _AuroraCTA(label: '✓ Kabul edildi', onPressed: null);
    }
    // pending — geri çekme butonu
    return _AuroraCTA(
      label: _loading ? 'İptal ediliyor...' : 'Başvuruyu Geri Al',
      icon: Icons.undo_rounded,
      onPressed: _loading ? null : _withdraw,
    );
  }
}
