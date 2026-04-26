import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../providers/profile_provider.dart';

class ProfileViewScreen extends ConsumerWidget {
  final String userId;
  const ProfileViewScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider(userId));
    final photosAsync = ref.watch(userPhotosProvider(userId));
    final promptsAsync = ref.watch(userPromptsProvider(userId));
    final currentUid =
        Supabase.instance.client.auth.currentUser?.id;
    final isOwnProfile = currentUid == userId;

    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        child: profileAsync.when(
          loading: () => Center(
            child: SizedBox(
              width: 30,
              height: 30,
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
                    fontFamily: 'Manrope',
                    color: AuroraTheme.textSecondary)),
          ),
          data: (user) {
            if (user == null) {
              return Center(
                child: Text('Profil bulunamadı',
                    style: TextStyle(
                        fontFamily: 'Manrope',
                        color: AuroraTheme.textSecondary)),
              );
            }

            final name = user['name'] as String? ?? '—';
            final age = user['age'] as int? ?? 0;
            final selfieStatus =
                user['selfie_status'] as String? ?? 'none';
            final verified = selfieStatus == 'approved' ||
                (user['verified'] as bool? ?? false);
            final bio = user['bio'] as String?;
            final job = user['job'] as String?;
            final education = user['education'] as String?;
            final city =
                user['city'] as Map<String, dynamic>?;
            final cityName = city?['name'] as String? ?? '';
            final interests =
                (user['interests'] as List?)?.cast<String>() ?? [];
            final photos = photosAsync.asData?.value ?? [];

            return CustomScrollView(
              slivers: [
                // ── Hero foto carousel ─────────────────────────────────
                SliverAppBar(
                  expandedHeight: 500,
                  pinned: true,
                  backgroundColor: AuroraTheme.bgDeep,
                  systemOverlayStyle: const SystemUiOverlayStyle(
                    statusBarColor: Colors.transparent,
                    statusBarIconBrightness: Brightness.light,
                  ),
                  leading: Padding(
                    padding: const EdgeInsets.all(8),
                    child: _GlassIconButton(
                      icon: Icons.arrow_back_ios_new,
                      onTap: () => context.pop(),
                    ),
                  ),
                  actions: [
                    if (!isOwnProfile && currentUid != null)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _FavoriteButton(targetUserId: userId),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: isOwnProfile
                          ? _GlassIconButton(
                              icon: Icons.settings_outlined,
                              onTap: () => context.push('/settings'),
                            )
                          : _GlassIconButton(
                              icon: Icons.more_horiz,
                              onTap: () =>
                                  _showActionSheet(context, userId),
                            ),
                    ),
                  ],
                  flexibleSpace: FlexibleSpaceBar(
                    background: _PhotoCarousel(photos: photos),
                  ),
                ),

                // ── Profil içerik ──────────────────────────────────────
                SliverToBoxAdapter(
                  child: Transform.translate(
                    offset: const Offset(0, -28),
                    child: Container(
                      decoration: BoxDecoration(
                        color: AuroraTheme.bgDeep,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Drag indicator — gradient
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(top: 12),
                              width: 36,
                              height: 4,
                              decoration: BoxDecoration(
                                gradient: AuroraTheme.redBlueGradient,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),

                          // İsim / yaş / verified
                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                                22, 20, 22, 0),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.center,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '$name, $age',
                                        style: const TextStyle(
                                          fontFamily: 'Fraunces',
                                          fontStyle: FontStyle.italic,
                                          fontSize: 34,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                          letterSpacing: -0.5,
                                          height: 1.1,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (verified) ...[
                                      const SizedBox(width: 10),
                                      Container(
                                        width: 24,
                                        height: 24,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AuroraTheme.auroraBlue,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AuroraTheme
                                                  .auroraBlue
                                                  .withOpacity(0.5),
                                              blurRadius: 12,
                                            ),
                                          ],
                                        ),
                                        child: const Icon(Icons.check,
                                            color: Colors.white,
                                            size: 14),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 10),
                                // Meta pills row
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    if (cityName.isNotEmpty)
                                      _MetaPill(
                                          icon: Icons.location_on_outlined,
                                          text: cityName),
                                    if (job != null && job.isNotEmpty)
                                      _MetaPill(
                                          icon: Icons.work_outline,
                                          text: job),
                                    if (education != null &&
                                        education.isNotEmpty)
                                      _MetaPill(
                                          icon: Icons.school_outlined,
                                          text: education),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Bio — Fraunces tırnak
                          if (bio != null && bio.isNotEmpty) ...[
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22),
                              child: _GlassInfoCard(
                                label: 'HAKKIMDA',
                                child: Text(
                                  '"$bio"',
                                  style: const TextStyle(
                                    fontFamily: 'Fraunces',
                                    fontStyle: FontStyle.italic,
                                    fontSize: 16,
                                    color: Colors.white,
                                    height: 1.55,
                                  ),
                                ),
                              ),
                            ),
                          ],

                          // Fotoğraflar
                          if (photos.length > 1) ...[
                            const SizedBox(height: 22),
                            Padding(
                              padding: const EdgeInsets.only(left: 22),
                              child: Text(
                                'FOTOĞRAFLAR',
                                style: AuroraTheme.monoLabel,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: 110,
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 22),
                                itemCount: photos.length,
                                itemBuilder: (_, i) {
                                  return Padding(
                                    padding:
                                        const EdgeInsets.only(right: 10),
                                    child: GestureDetector(
                                      onTap: () => _openPhotoViewer(
                                          context, photos, i),
                                      child: ClipRRect(
                                        borderRadius:
                                            BorderRadius.circular(14),
                                        child: Container(
                                          width: 82,
                                          height: 110,
                                          decoration: BoxDecoration(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            border: Border.all(
                                              color:
                                                  AuroraTheme.glassBorder,
                                            ),
                                          ),
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(14),
                                            child: CachedNetworkImage(
                                              imageUrl:
                                                  photos[i]['url'] as String,
                                              fit: BoxFit.cover,
                                              alignment:
                                                  Alignment.topCenter,
                                              errorWidget: (_, __, ___) =>
                                                  Container(
                                                color: AuroraTheme.glassBg,
                                                child: const Icon(
                                                    Icons.person_outline,
                                                    color: Colors.white24),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],

                          // İlgi alanları
                          if (interests.isNotEmpty) ...[
                            const SizedBox(height: 22),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 22),
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'İLGİ ALANLARI',
                                    style: AuroraTheme.monoLabel,
                                  ),
                                  const SizedBox(height: 10),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: interests
                                        .map((i) =>
                                            _InterestChip(label: i))
                                        .toList(),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Prompts
                          promptsAsync.maybeWhen(
                            data: (prompts) {
                              if (prompts.isEmpty) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(
                                    22, 22, 22, 0),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'İFADELER',
                                      style: AuroraTheme.monoLabel,
                                    ),
                                    const SizedBox(height: 12),
                                    ...prompts.map((p) => Padding(
                                          padding: const EdgeInsets.only(
                                              bottom: 12),
                                          child: _GlassInfoCard(
                                            label: _questionLabel(
                                                p['question_key']
                                                    as String),
                                            child: Text(
                                              p['answer'] as String? ?? '',
                                              style: const TextStyle(
                                                fontFamily: 'Fraunces',
                                                fontStyle: FontStyle.italic,
                                                fontSize: 18,
                                                color: Colors.white,
                                                height: 1.4,
                                              ),
                                            ),
                                          ),
                                        )),
                                  ],
                                ),
                              );
                            },
                            orElse: () => const SizedBox.shrink(),
                          ),

                          // CTA
                          Padding(
                            padding: EdgeInsets.fromLTRB(
                              22,
                              28,
                              22,
                              MediaQuery.of(context).padding.bottom +
                                  kBottomNavigationBarHeight +
                                  16,
                            ),
                            child: isOwnProfile
                                ? _OutlineCTA(
                                    label: 'Profili Düzenle',
                                    onTap: () =>
                                        context.push('/profile/setup'),
                                  )
                                : _AuroraCTA(
                                    label: 'Gelmek isterim',
                                    onTap: () => context.pop(),
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

  String _questionLabel(String key) {
    const labels = {
      'favorite_restaurant': 'Favori restoranım...',
      'last_book': 'Son okuduğum kitap...',
      'perfect_evening': 'Mükemmel bir akşam...',
      'travel_dream': 'Hayalimdeki seyahat...',
    };
    return labels[key] ?? key;
  }

  void _openPhotoViewer(
      BuildContext context,
      List<Map<String, dynamic>> photos,
      int index) {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black.withOpacity(0.92),
        pageBuilder: (_, __, ___) =>
            _PhotoViewerPage(photos: photos, initialIndex: index),
      ),
    );
  }

  void _showActionSheet(BuildContext context, String targetUserId) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          _ActionSheet(targetUserId: targetUserId, targetName: null),
    );
  }
}

// ── Meta Pill ─────────────────────────────────────────────────────────────────
class _MetaPill extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MetaPill({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(100),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            constraints: const BoxConstraints(maxWidth: 140),
            decoration: BoxDecoration(
              color: AuroraTheme.glassBg,
              borderRadius: BorderRadius.circular(100),
              border: Border.all(color: AuroraTheme.glassBorder),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 12, color: AuroraTheme.auroraRed),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AuroraTheme.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

// ── Glass Info Card ───────────────────────────────────────────────────────────
class _GlassInfoCard extends StatelessWidget {
  final String label;
  final Widget child;
  const _GlassInfoCard({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius:
            BorderRadius.circular(AuroraTheme.radiusInfoCard),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AuroraTheme.glassBg,
              borderRadius:
                  BorderRadius.circular(AuroraTheme.radiusInfoCard),
              border: Border.all(color: AuroraTheme.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AuroraTheme.monoLabel),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ),
      );
}

// ── Interest Chip ─────────────────────────────────────────────────────────────
class _InterestChip extends StatelessWidget {
  final String label;
  const _InterestChip({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: AuroraTheme.auroraBlue.withOpacity(0.10),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
              color: AuroraTheme.auroraBlue.withOpacity(0.35)),
          boxShadow: [
            BoxShadow(
              color: AuroraTheme.auroraBlue.withOpacity(0.15),
              blurRadius: 8,
            ),
          ],
        ),
        child: Text(
          label,
          style: TextStyle(
            fontFamily: 'Manrope',
            fontWeight: FontWeight.w500,
            fontSize: 12,
            color: AuroraTheme.textSecondary,
          ),
        ),
      );
}

// ── CTA'lar ───────────────────────────────────────────────────────────────────
class _AuroraCTA extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _AuroraCTA({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: AuroraTheme.redBlueGradient,
            borderRadius: BorderRadius.circular(100),
            boxShadow: [
              BoxShadow(
                color: AuroraTheme.auroraRed.withOpacity(0.40),
                blurRadius: 28,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
}

class _OutlineCTA extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineCTA({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AuroraTheme.auroraBlue.withOpacity(0.25),
                AuroraTheme.auroraRed.withOpacity(0.25),
              ],
            ),
            borderRadius: BorderRadius.circular(100),
            border: Border.all(
                color: AuroraTheme.auroraBlue.withOpacity(0.40), width: 1.5),
          ),
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w700,
                fontSize: 15,
                color: Colors.white,
              ),
            ),
          ),
        ),
      );
}

// ── Glass Icon Button ─────────────────────────────────────────────────────────
class _GlassIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _GlassIconButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.40),
                border: Border.all(
                    color: Colors.white.withOpacity(0.18)),
              ),
              child: Icon(icon, size: 17, color: Colors.white),
            ),
          ),
        ),
      );
}

// ── Favorite Button ───────────────────────────────────────────────────────────
class _FavoriteButton extends StatefulWidget {
  final String targetUserId;
  const _FavoriteButton({required this.targetUserId});

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton>
    with SingleTickerProviderStateMixin {
  bool? _isFavorite;
  late final AnimationController _scaleCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _scaleCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 180));
    _scaleAnim = Tween(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _scaleCtrl, curve: Curves.elasticOut),
    );
    _scaleCtrl.value = 1.0;
    _loadState();
  }

  @override
  void dispose() {
    _scaleCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadState() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final result = await Supabase.instance.client
        .from('favorites')
        .select('id')
        .eq('user_id', uid)
        .eq('favorited_user_id', widget.targetUserId)
        .maybeSingle();
    if (mounted) setState(() => _isFavorite = result != null);
  }

  Future<void> _toggle() async {
    if (_isFavorite == null) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    HapticFeedback.lightImpact();
    _scaleCtrl.reverse().then((_) => _scaleCtrl.forward());
    final next = !_isFavorite!;
    setState(() => _isFavorite = next);
    if (next) {
      await Supabase.instance.client.from('favorites').insert({
        'user_id': uid,
        'favorited_user_id': widget.targetUserId,
      });
    } else {
      await Supabase.instance.client
          .from('favorites')
          .delete()
          .eq('user_id', uid)
          .eq('favorited_user_id', widget.targetUserId);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isFavorite == null) {
      return const SizedBox(width: 38, height: 38);
    }
    return ScaleTransition(
      scale: _scaleAnim,
      child: GestureDetector(
        onTap: _toggle,
        child: ClipOval(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isFavorite!
                    ? AuroraTheme.auroraRed.withOpacity(0.20)
                    : Colors.black.withOpacity(0.40),
                border: Border.all(
                  color: _isFavorite!
                      ? AuroraTheme.auroraRed.withOpacity(0.6)
                      : Colors.white.withOpacity(0.18),
                ),
              ),
              child: Icon(
                _isFavorite!
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                color: _isFavorite!
                    ? AuroraTheme.auroraRed
                    : Colors.white.withOpacity(0.7),
                size: 19,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Action Sheet ──────────────────────────────────────────────────────────────
class _ActionSheet extends StatelessWidget {
  final String targetUserId;
  final String? targetName;
  const _ActionSheet(
      {required this.targetUserId, this.targetName});

  Future<void> _block(BuildContext ctx) async {
    Navigator.pop(ctx); // sheet'i kapat
    final confirmed = await showDialog<bool>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: const Color(0xFF0D0D12),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Kullanıcıyı engelle',
          style: TextStyle(
              fontFamily: 'Fraunces',
              fontStyle: FontStyle.italic,
              fontSize: 18,
              color: Colors.white),
        ),
        content: Text(
          'Bu kullanıcıyı engellemek istediğine emin misin?',
          style: TextStyle(
              fontFamily: 'Manrope',
              fontSize: 14,
              color: AuroraTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç',
                style: TextStyle(
                    fontFamily: 'Manrope',
                    color: AuroraTheme.textMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Engelle',
                style: TextStyle(
                    fontFamily: 'Manrope',
                    color: AuroraTheme.auroraRed,
                    fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true || !ctx.mounted) return;
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    await Supabase.instance.client.from('blocks').upsert({
      'blocker_id': uid,
      'blocked_id': targetUserId,
    });
    if (ctx.mounted) {
      ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
        content: Text(
            '${targetName ?? 'Kullanıcı'} engellendi'),
        backgroundColor: const Color(0xFF10B981),
      ));
      ctx.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 30, sigmaY: 30),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF0D0D12).withOpacity(0.90),
            borderRadius:
                const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(color: AuroraTheme.glassBorder),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AuroraTheme.glassBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.block,
                      color: AuroraTheme.auroraRed),
                  title: const Text('🚫 Kullanıcıyı engelle',
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          color: Colors.white)),
                  onTap: () => _block(context),
                ),
                ListTile(
                  leading: Icon(Icons.flag_outlined,
                      color: AuroraTheme.auroraGold),
                  title: const Text('⚠️ Rapor et',
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          color: Colors.white)),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/report/$targetUserId');
                  },
                ),
                ListTile(
                  leading: Icon(Icons.close,
                      color: AuroraTheme.textMuted),
                  title: Text('İptal',
                      style: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 15,
                          color: AuroraTheme.textSecondary)),
                  onTap: () => Navigator.pop(context),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Photo Carousel ────────────────────────────────────────────────────────────
class _PhotoCarousel extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  const _PhotoCarousel({required this.photos});

  @override
  State<_PhotoCarousel> createState() => _PhotoCarouselState();
}

class _PhotoCarouselState extends State<_PhotoCarousel> {
  int _current = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.photos.isEmpty) {
      return Container(
        color: AuroraTheme.bgDeep,
        child: const Center(
          child: Icon(Icons.person_outline,
              size: 80, color: Colors.white12),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        PageView.builder(
          itemCount: widget.photos.length,
          onPageChanged: (i) => setState(() => _current = i),
          itemBuilder: (_, i) {
            final url = widget.photos[i]['url'] as String;
            return Image.network(
              url,
              fit: BoxFit.cover,
              alignment: Alignment.topCenter,
              errorBuilder: (_, __, ___) => Container(
                color: AuroraTheme.bgDeep,
                child: const Icon(Icons.person_outline,
                    size: 60, color: Colors.white12),
              ),
            );
          },
        ),
        // Alt gradient
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.center,
              colors: [AuroraTheme.bgDeep, Colors.transparent],
              stops: const [0.0, 0.6],
            ),
          ),
        ),
        // Üst glow
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment(0, -0.3),
              colors: [
                AuroraTheme.auroraRed.withOpacity(0.15),
                Colors.transparent,
              ],
            ),
          ),
        ),
        // Photo dots
        if (widget.photos.length > 1)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 10),
                child: Row(
                  children: List.generate(widget.photos.length, (i) {
                    final isActive = i == _current;
                    return Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(
                            right: i < widget.photos.length - 1 ? 4 : 0),
                        child: Container(
                          height: 3,
                          decoration: BoxDecoration(
                            gradient: isActive
                                ? AuroraTheme.redBlueGradient
                                : null,
                            color: isActive
                                ? null
                                : Colors.white.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Full-screen Photo Viewer ──────────────────────────────────────────────────
class _PhotoViewerPage extends StatefulWidget {
  final List<Map<String, dynamic>> photos;
  final int initialIndex;
  const _PhotoViewerPage(
      {required this.photos, required this.initialIndex});

  @override
  State<_PhotoViewerPage> createState() => _PhotoViewerPageState();
}

class _PhotoViewerPageState extends State<_PhotoViewerPage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.pop(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: PageView.builder(
          controller: _pageController,
          itemCount: widget.photos.length,
          itemBuilder: (_, i) {
            final url = widget.photos[i]['url'] as String;
            return InteractiveViewer(
              minScale: 0.8,
              maxScale: 4.0,
              child: Center(
                child: CachedNetworkImage(
                  imageUrl: url,
                  fit: BoxFit.contain,
                  errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: Colors.white54,
                      size: 60),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
