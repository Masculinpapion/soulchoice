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
      body: AmbientBackground(
        child: invAsync.when(
          loading: () => Center(
            child: SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor:
                    AlwaysStoppedAnimation(AuroraTheme.auroraRed),
              ),
            ),
          ),
          error: (e, _) => Center(
            child: Text('$e',
                style: TextStyle(
                    color: AuroraTheme.textSecondary,
                    fontFamily: 'Manrope')),
          ),
          data: (inv) {
            if (inv == null) {
              return Center(
                child: Text('Davet bulunamadı',
                    style: TextStyle(
                        color: AuroraTheme.textSecondary,
                        fontFamily: 'Manrope')),
              );
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
            final expiresAt =
                DateTime.parse(inv['expires_at'] as String);
            final remaining = expiresAt.difference(DateTime.now());
            final hoursLeft = remaining.inHours;

            return Stack(
              children: [
                // ── 1. Fotoğraf — üst bölge ───────────────────────────
                // Fotoğraf ekranın üst %55'ini kaplar, altı kesilir.
                // Kesilen kenar gradient köprüsüyle tamamen gizlenir.
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  bottom: MediaQuery.of(context).size.height * 0.45,
                  child: ownerPhotoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: ownerPhotoUrl,
                          fit: BoxFit.cover,
                          alignment: Alignment.topCenter,
                          errorWidget: (_, __, ___) => _FallbackBg(),
                        )
                      : _FallbackBg(),
                ),

                // ── 2. İçerik zemini — Aurora glow ────────────────────
                // Solid + aurora glows. Fotoğraf bitişinin hemen altından
                // başlar; gradient köprü aralarını örter.
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.55,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Stack(
                    children: [
                      Container(color: AuroraTheme.bgDeep),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(-1.0, 1.2),
                              radius: 1.5,
                              colors: [
                                AuroraTheme.auroraRed.withOpacity(0.22),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.65],
                            ),
                          ),
                        ),
                      ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: RadialGradient(
                              center: const Alignment(1.2, 0.3),
                              radius: 1.2,
                              colors: [
                                AuroraTheme.auroraBlue.withOpacity(0.16),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.65],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── 3. Gradient köprüsü — seam'i tamamen örter ────────
                // Fotoğrafın bitiş noktası (%55) bu gradyanın tam ortasında.
                // %25'ten başlar, %70'te biter → 45% uzunluk → çizgi yok.
                Positioned(
                  top: MediaQuery.of(context).size.height * 0.25,
                  left: 0,
                  right: 0,
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AuroraTheme.bgDeep.withOpacity(0.45),
                          AuroraTheme.bgDeep.withOpacity(0.88),
                          AuroraTheme.bgDeep,
                        ],
                        stops: const [0.0, 0.42, 0.72, 1.0],
                      ),
                    ),
                  ),
                ),

                // ── 4. Üst koyulaştırma — geri butonu okunurluğu ──────
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 100,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.40),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Top bar — geri + kategori ──────────────────────────
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
                            child: const Icon(Icons.arrow_back_ios_new,
                                size: 16, color: Colors.white),
                          ),
                          const Spacer(),
                          _GlassPill(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(category.emoji,
                                    style: const TextStyle(fontSize: 13)),
                                const SizedBox(width: 4),
                                Text(
                                  category.label,
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.85),
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
                              child: const Icon(Icons.people_outline,
                                  size: 18, color: Colors.white),
                            ),
                            const SizedBox(width: 8),
                            _GlassPill(
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: AuroraTheme.bgDeep,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(20)),
                                    title: const Text('Daveti sil',
                                        style: TextStyle(
                                            fontFamily: 'Fraunces',
                                            fontStyle: FontStyle.italic,
                                            color: Colors.white,
                                            fontSize: 20)),
                                    content: Text(
                                        'Bu daveti silmek istiyor musun? Geri alınamaz.',
                                        style: TextStyle(
                                            fontFamily: 'Manrope',
                                            color: AuroraTheme.textSecondary,
                                            fontSize: 14)),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(false),
                                        child: Text('Vazgeç',
                                            style: TextStyle(
                                                fontFamily: 'JetBrainsMono',
                                                color: AuroraTheme.textMuted)),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(true),
                                        child: const Text('Sil',
                                            style: TextStyle(
                                                fontFamily: 'JetBrainsMono',
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
                              },
                              child: const Icon(Icons.delete_outline,
                                  size: 18,
                                  color: AuroraTheme.auroraRed),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),

                // ── Bottom content ─────────────────────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding:
                          const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // ── Title ──────────────────────────────────
                          Text(
                            inv['title'] as String,
                            style: const TextStyle(
                              fontFamily: 'Fraunces',
                              fontStyle: FontStyle.italic,
                              fontSize: 28,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.2,
                              shadows: [
                                Shadow(
                                    blurRadius: 24,
                                    color: Colors.black87),
                              ],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),

                          // ── Row 1: süre + başvuru ──────────────────
                          Row(
                            children: [
                              _InfoPill(
                                icon: Icons.schedule_rounded,
                                label: hoursLeft >= 0
                                    ? '${hoursLeft}s kaldı'
                                    : 'Sona erdi',
                                color: AuroraTheme.auroraBlue,
                              ),
                              const SizedBox(width: 8),
                              countAsync.maybeWhen(
                                data: (n) => _InfoPill(
                                  icon: Icons.people_outline_rounded,
                                  label: '$n başvuru',
                                  color: AuroraTheme.auroraViolet,
                                ),
                                orElse: () => const SizedBox.shrink(),
                              ),
                            ],
                          ),

                          // ── Row 2: yer + tarih ─────────────────────
                          if (inv['venue_name'] != null ||
                              inv['event_date'] != null) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                if (inv['venue_name'] != null)
                                  Flexible(
                                    child: _InfoPill(
                                      icon: Icons.location_on_outlined,
                                      label: inv['venue_name'] as String,
                                      color: AuroraTheme.auroraRed,
                                    ),
                                  ),
                                if (inv['venue_name'] != null &&
                                    inv['event_date'] != null)
                                  const SizedBox(width: 8),
                                if (inv['event_date'] != null)
                                  Flexible(
                                    child: _InfoPill(
                                      icon: Icons.calendar_today_outlined,
                                      label: _formatDate(DateTime.parse(
                                          inv['event_date'] as String)),
                                      color: AuroraTheme.auroraGold,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 10),

                          // ── Açıklama — glass card ──────────────────
                          if (inv['description'] != null) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                    sigmaX: 20, sigmaY: 20),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 11),
                                  decoration: BoxDecoration(
                                    color:
                                        Colors.white.withOpacity(0.07),
                                    borderRadius:
                                        BorderRadius.circular(14),
                                    border: Border.all(
                                        color: Colors.white
                                            .withOpacity(0.10)),
                                  ),
                                  child: Text(
                                    inv['description'] as String,
                                    style: TextStyle(
                                      fontFamily: 'Manrope',
                                      fontSize: 13,
                                      color:
                                          Colors.white.withOpacity(0.75),
                                      height: 1.55,
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],

                          // ── Davet sahibi ───────────────────────────
                          if (owner != null) ...[
                            _HostRow(
                              owner: owner,
                              ownerPhotoUrl: ownerPhotoUrl,
                              invitationId: invitationId,
                            ),
                            const SizedBox(height: 14),
                          ],

                          // ── CTA ────────────────────────────────────
                          isOwner
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
                                        myApplicationProvider(
                                            invitationId)),
                                  ),
                                ),
                        ],
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

// ── Fallback Background ───────────────────────────────────────────────────────
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

// ── Info Pill ─────────────────────────────────────────────────────────────────
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

// ── Host Row ──────────────────────────────────────────────────────────────────
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
                  // Avatar with gradient ring
                  Container(
                    width: 40,
                    height: 40,
                    padding: const EdgeInsets.all(1.5),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AuroraTheme.auroraRed,
                          AuroraTheme.auroraBlue,
                        ],
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
                            color:
                                AuroraTheme.auroraBlue.withOpacity(0.5),
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

// ── Glass Pill ────────────────────────────────────────────────────────────────
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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

// ─────────────────────────────────────────────────────────────────────────────
// Apply Button (mevcut mantık korundu)
// ─────────────────────────────────────────────────────────────────────────────

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
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
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
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
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

  @override
  Widget build(BuildContext context) {
    final app = widget.existingApp;
    if (app == null) {
      return _AuroraCTA(
        label: _loading ? 'Gönderiliyor...' : (widget.isRequestFlow ? 'Katılmak isterim' : 'Gelmek isterim'),
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
    return _AuroraCTA(label: 'Başvurdunuz', onPressed: null);
  }
}
