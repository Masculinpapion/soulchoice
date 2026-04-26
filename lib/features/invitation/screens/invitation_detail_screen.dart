import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:ui';
import '../../../core/theme/aurora_theme.dart';
import '../../../data/models/invitation_model.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
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
                CustomScrollView(
                  slivers: [
                    // ── Hero ───────────────────────────────────────────
                    SliverAppBar(
                      expandedHeight: 380,
                      pinned: true,
                      backgroundColor: AuroraTheme.bgDeep,
                      leading: Padding(
                        padding: const EdgeInsets.all(8),
                        child: _GlassPill(
                          onTap: () => context.pop(),
                          child: const Icon(Icons.arrow_back_ios_new,
                              size: 16, color: Colors.white),
                        ),
                      ),
                      actions: [
                        if (isOwner) ...[
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _GlassPill(
                              onTap: () => context.push(
                                  '/invitation/$invitationId/applicants'),
                              child: const Icon(Icons.people_outline,
                                  size: 18, color: Colors.white),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _GlassPill(
                              onTap: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: AuroraTheme.bgDeep,
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20)),
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
                                        onPressed: () => Navigator.of(ctx).pop(false),
                                        child: Text('Vazgeç',
                                            style: TextStyle(
                                                fontFamily: 'JetBrainsMono',
                                                color: AuroraTheme.textMuted)),
                                      ),
                                      TextButton(
                                        onPressed: () => Navigator.of(ctx).pop(true),
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
                                  ref.invalidate(invitationProvider);
                                  ref.invalidate(invitationsProvider);
                                  if (context.mounted) context.pop();
                                }
                              },
                              child: const Icon(Icons.delete_outline,
                                  size: 18, color: AuroraTheme.auroraRed),
                            ),
                          ),
                        ],
                        // Kategori pill
                        Padding(
                          padding:
                              const EdgeInsets.only(right: 12, top: 8),
                          child: _GlassPill(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  category.emoji,
                                  style: TextStyle(
                                    fontSize: category == InvitationCategory.concert ? 18 : 14,
                                    color: category == InvitationCategory.concert ? AuroraTheme.auroraRed : null,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  category.label,
                                  style: TextStyle(
                                    fontFamily: 'JetBrainsMono',
                                    fontSize: 10,
                                    color: Colors.white.withOpacity(0.8),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                      flexibleSpace: FlexibleSpaceBar(
                        background: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (ownerPhotoUrl != null)
                              CachedNetworkImage(
                                imageUrl: ownerPhotoUrl,
                                fit: BoxFit.cover,
                                alignment: Alignment.topCenter,
                                errorWidget: (_, __, ___) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        AuroraTheme.auroraRed
                                            .withOpacity(0.3),
                                        AuroraTheme.auroraBlue
                                            .withOpacity(0.2),
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
                                      AuroraTheme.auroraRed
                                          .withOpacity(0.3),
                                      AuroraTheme.auroraBlue
                                          .withOpacity(0.2),
                                    ],
                                  ),
                                ),
                              ),
                            // Alt gradient
                            Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Colors.transparent,
                                    AuroraTheme.bgDeep,
                                  ],
                                  stops: const [0.45, 1.0],
                                ),
                              ),
                            ),
                            // Başlık — Fraunces italic overlay
                            Positioned(
                              bottom: 24,
                              left: 20,
                              right: 20,
                              child: Text(
                                inv['title'] as String,
                                style: const TextStyle(
                                  fontFamily: 'Fraunces',
                                  fontStyle: FontStyle.italic,
                                  fontSize: 28,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  height: 1.2,
                                ),
                                maxLines: 3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 160),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          // ── Stats row ─────────────────────────────────
                          Row(
                            children: [
                              Expanded(
                                child: _StatCard(
                                  icon: '⏱',
                                  label: 'KALAN',
                                  value: hoursLeft >= 0
                                      ? '${hoursLeft}s'
                                      : 'Sona erdi',
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: countAsync.maybeWhen(
                                  data: (n) => _StatCard(
                                    icon: '👥',
                                    label: 'BAŞVURU',
                                    value: '$n kişi',
                                  ),
                                  orElse: () => _StatCard(
                                    icon: '👥',
                                    label: 'BAŞVURU',
                                    value: '—',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _StatCard(
                                  icon: '📍',
                                  label: 'YER',
                                  value: inv['venue_name'] as String? ??
                                      category.label,
                                  small: true,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          // ── Açıklama ──────────────────────────────────
                          if (inv['description'] != null) ...[
                            _SectionLabel('ETKİNLİK'),
                            const SizedBox(height: 8),
                            GlassCard(
                              child: Text(
                                inv['description'] as String,
                                style: const TextStyle(
                                  fontFamily: 'Manrope',
                                  fontSize: 14,
                                  color: Colors.white,
                                  height: 1.6,
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // ── Yer & Zaman ───────────────────────────────
                          if (inv['venue_name'] != null ||
                              inv['event_date'] != null) ...[
                            _SectionLabel('YER · ZAMAN'),
                            const SizedBox(height: 8),
                            GlassCard(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  if (inv['venue_name'] != null)
                                    Row(children: [
                                      Icon(Icons.location_on_outlined,
                                          size: 15,
                                          color: AuroraTheme.auroraRed),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          inv['venue_name'] as String,
                                          style: const TextStyle(
                                            fontFamily: 'Manrope',
                                            fontSize: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ]),
                                  if (inv['event_date'] != null) ...[
                                    const SizedBox(height: 6),
                                    Row(children: [
                                      Icon(
                                          Icons.calendar_today_outlined,
                                          size: 15,
                                          color: AuroraTheme.auroraBlue),
                                      const SizedBox(width: 8),
                                      Text(
                                        _formatDate(DateTime.parse(
                                            inv['event_date'] as String)),
                                        style: const TextStyle(
                                          fontFamily: 'Manrope',
                                          fontSize: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ]),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 14),
                          ],

                          // ── Davet sahibi ──────────────────────────────
                          if (owner != null) ...[
                            _SectionLabel('DAVET SAHİBİ'),
                            const SizedBox(height: 8),
                            GlassCard(
                              onTap: () => context
                                  .push('/profile/${owner['id']}'),
                              child: Row(
                                children: [
                                  ClipOval(
                                    child: SizedBox(
                                      width: 48,
                                      height: 48,
                                      child: ownerPhotoUrl != null
                                          ? CachedNetworkImage(
                                              imageUrl: ownerPhotoUrl,
                                              fit: BoxFit.cover,
                                              alignment:
                                                  Alignment.topCenter,
                                              errorWidget: (_, __, ___) =>
                                                  Container(
                                                color: AuroraTheme
                                                    .glassBg,
                                                child: const Icon(
                                                    Icons.person_outline,
                                                    color: Colors.white54),
                                              ),
                                            )
                                          : Container(
                                              color: AuroraTheme.glassBg,
                                              child: const Icon(
                                                  Icons.person_outline,
                                                  color: Colors.white54),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(children: [
                                          Text(
                                            '${owner['name']}, ${owner['age']}',
                                            style: const TextStyle(
                                              fontFamily: 'Manrope',
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: Colors.white,
                                            ),
                                          ),
                                          if (owner['verified'] ==
                                              true) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              width: 18,
                                              height: 18,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: AuroraTheme
                                                    .auroraBlue,
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AuroraTheme
                                                        .auroraBlue
                                                        .withOpacity(0.5),
                                                    blurRadius: 8,
                                                  ),
                                                ],
                                              ),
                                              child: const Icon(
                                                  Icons.check,
                                                  color: Colors.white,
                                                  size: 11),
                                            ),
                                          ],
                                        ]),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.arrow_forward_ios,
                                      size: 14,
                                      color:
                                          Colors.white.withOpacity(0.25)),
                                ],
                              ),
                            ),
                          ],
                        ]),
                      ),
                    ),
                  ],
                ),

                // ── CTA buton ─────────────────────────────────────────
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: EdgeInsets.fromLTRB(20, 14, 20,
                        MediaQuery.of(context).viewPadding.bottom + 20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          AuroraTheme.bgDeep,
                          AuroraTheme.bgDeep.withOpacity(0.0),
                        ],
                      ),
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
                              onPressed: null,
                            ),
                            error: (_, __) => const _AuroraCTA(
                              label: 'Hata',
                              onPressed: null,
                            ),
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

// ── Section Label ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: AuroraTheme.monoLabel,
      );
}

// ── Stat Card ─────────────────────────────────────────────────────────────────
class _StatCard extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final bool small;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
    this.small = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: AuroraTheme.glassBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AuroraTheme.glassBorder),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(icon, style: const TextStyle(fontSize: 20)),
              const SizedBox(height: 4),
              Text(
                label,
                style: AuroraTheme.monoLabel
                    .copyWith(fontSize: 8, letterSpacing: 1),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontWeight: FontWeight.w700,
                  fontSize: small ? 11 : 14,
                  color: Colors.white,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
          const SnackBar(content: Text('Başvurunuz gönderildi! 🎉')),
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
