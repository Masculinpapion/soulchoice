import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/invitation_model.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../providers/invitations_provider.dart';
import '../../notifications/providers/notifications_provider.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

class FeedScreen extends ConsumerStatefulWidget {
  const FeedScreen({super.key});

  @override
  ConsumerState<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends ConsumerState<FeedScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  InvitationCategory? _selectedCategory;
  String? _selectedCityId;
  String? _selectedCityName;

  void _onTabChanged() => setState(() {});

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadMoskovaCityId();
  }

  Future<void> _loadMoskovaCityId() async {
    final data = await Supabase.instance.client
        .from('cities')
        .select('id')
        .eq('name_en', 'Moscow')
        .maybeSingle();
    if (!mounted || data == null) return;
    setState(() => _selectedCityId = data['id'] as String);
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _showCityPicker() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => _CityPickerSheet(
        selectedCityId: _selectedCityId,
        onCitySelected: (id, name) {
          Navigator.of(sheetCtx).pop();
          if (!mounted) return;
          setState(() {
            _selectedCityId = id;
            _selectedCityName = name ?? AppLocalizations.of(context)!.feed_all_cities;
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                cityName: _selectedCityName ?? AppLocalizations.of(context)!.feed_city_name_moscow,
                onCityTap: _showCityPicker,
                onNotificationTap: () => context.push('/notifications'),
              ),
              _StoryBar(
                flowType: _tabController.index == 0
                    ? InvitationFlowType.invite
                    : InvitationFlowType.request,
                cityId: _selectedCityId,
              ),
              _TabBar(controller: _tabController),
              _CategoryChips(
                selected: _selectedCategory,
                onSelected: (c) => setState(() {
                  _selectedCategory = _selectedCategory == c ? null : c;
                }),
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _InvitationList(
                      flowType: InvitationFlowType.invite,
                      category: _selectedCategory,
                      cityId: _selectedCityId,
                    ),
                    _InvitationList(
                      flowType: InvitationFlowType.request,
                      category: _selectedCategory,
                      cityId: _selectedCityId,
                    ),
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
// Header
// ─────────────────────────────────────────────────────────────────────────────

class _Header extends ConsumerWidget {
  final String cityName;
  final VoidCallback onCityTap;
  final VoidCallback onNotificationTap;

  const _Header({required this.cityName, required this.onCityTap, required this.onNotificationTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(unreadNotificationCountProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 12, 4),
      child: Row(
        children: [
          // Logo — gradient shimmer
          ShaderMask(
            shaderCallback: (bounds) =>
                AuroraTheme.redBlueGradient.createShader(bounds),
            child: Text(
              'SoulChoice',
              style: TextStyle(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                fontSize: MediaQuery.of(context).size.width < 360 ? 22.0 : 26,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const Spacer(),
          // City pill — bell'in hemen solunda
          _GlassPill(
            onTap: onCityTap,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.location_on,
                    size: 13, color: AuroraTheme.auroraRed),
                const SizedBox(width: 4),
                Text(cityName,
                    style: TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 11,
                      color: AuroraTheme.textSecondary,
                    )),
                Icon(Icons.expand_more,
                    size: 14, color: AuroraTheme.textMuted),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Notification bell
          Stack(
            clipBehavior: Clip.none,
            children: [
              _GlassPill(
                onTap: onNotificationTap,
                child: Icon(Icons.notifications_outlined,
                    color: Colors.white, size: 20),
              ),
              if (unreadCount > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AuroraTheme.auroraRed, AuroraTheme.auroraBlue],
                      ),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        fontFamily: 'JetBrainsMono',
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
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
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: AuroraTheme.glassBg,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: AuroraTheme.glassBorder),
              ),
              child: child,
            ),
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Story Bar
// ─────────────────────────────────────────────────────────────────────────────

class _StoryBar extends ConsumerWidget {
  final InvitationFlowType flowType;
  final String? cityId;
  const _StoryBar({required this.flowType, this.cityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = InvitationFilter(flowType: flowType, cityId: cityId);
    final async = ref.watch(invitationsProvider(filter));

    final seen = <String>{};
    final invitations = (async.asData?.value ?? [])
        .where((inv) {
          if (inv.ownerPhotoUrl == null) return false;
          final ownerId = inv.owner?.id ?? '';
          if (seen.contains(ownerId)) return false;
          seen.add(ownerId);
          return true;
        })
        .toList();
    if (invitations.isEmpty) {
      // Yükleme sırasında yüksekliği koru — layout zıplamasını engelle
      if (async.isLoading) return const SizedBox(height: 118);
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 118,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  flowType == InvitationFlowType.invite
                      ? AppLocalizations.of(context)!.feed_active_invitations
                      : AppLocalizations.of(context)!.feed_active_requests,
                  style: AuroraTheme.monoLabel.copyWith(
                    fontSize: 9,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: flowType == InvitationFlowType.invite
                          ? [AuroraTheme.auroraRed, AuroraTheme.auroraViolet]
                          : [AuroraTheme.auroraBlue, AuroraTheme.auroraViolet],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Text(
                    AppLocalizations.of(context)!.feed_24h_badge,
                    style: const TextStyle(
                      fontFamily: 'JetBrainsMono',
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: invitations.take(10).length,
              itemBuilder: (_, i) {
                final inv = invitations[i];
                final isLive =
                    DateTime.now().difference(inv.createdAt).inHours < 1;
                final ownerName = inv.owner?.name ?? '—';
                final storyLabel = ownerName.split(' ').first;

                return Padding(
                  padding: const EdgeInsets.only(right: 14),
                  child: GestureDetector(
                    onTap: () => context.push('/invitation/${inv.id}'),
                    child: _StoryAvatar(
                      photoUrl: inv.ownerPhotoUrl,
                      label: storyLabel,
                      isLive: isLive,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  final String? photoUrl;
  final String label;
  final bool isLive;
  const _StoryAvatar(
      {required this.photoUrl, required this.label, this.isLive = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 66,
              height: 66,
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AuroraTheme.auroraRed,
                    AuroraTheme.auroraViolet,
                    AuroraTheme.auroraBlue,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: AuroraTheme.bgDeep, width: 2),
                ),
                child: ClipOval(
                  child: photoUrl != null
                      ? CachedNetworkImage(
                          imageUrl: photoUrl!,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _AvatarFallback(name: label),
                        )
                      : _AvatarFallback(name: label),
                ),
              ),
            ),
            if (isLive)
              Positioned(
                bottom: -2,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: BoxDecoration(
                      color: AuroraTheme.auroraRed,
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: AuroraTheme.auroraRed.withOpacity(0.6),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: const Text(
                      'LIVE',
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 7,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 7),
        Text(
          label,
          style: TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 10,
            color: AuroraTheme.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final String name;
  const _AvatarFallback({this.name = ''});

  @override
  Widget build(BuildContext context) {
    final raw = name.trim();
    final initials = raw.isEmpty
        ? '✦'
        : raw
            .split(' ')
            .where((w) => w.isNotEmpty)
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase();
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AuroraTheme.auroraViolet,
            AuroraTheme.auroraRed,
            AuroraTheme.auroraBlue
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            fontFamily: 'JetBrainsMono',
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Tab Bar — Aurora pill toggle
// ─────────────────────────────────────────────────────────────────────────────

class _TabBar extends StatefulWidget {
  final TabController controller;
  const _TabBar({required this.controller});

  @override
  State<_TabBar> createState() => _TabBarState();
}

class _TabBarState extends State<_TabBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTabChanged);
  }

  void _onTabChanged() => setState(() {});

  @override
  void dispose() {
    widget.controller.removeListener(_onTabChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isInvite = widget.controller.index == 0;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => widget.controller.animateTo(0),
              child: _AuroraPillTab(
                label: AppLocalizations.of(context)!.feed_tab_invitations,
                color: AuroraTheme.auroraRed,
                active: isInvite,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: () => widget.controller.animateTo(1),
              child: _AuroraPillTab(
                label: AppLocalizations.of(context)!.feed_tab_requests,
                color: AuroraTheme.auroraBlue,
                active: !isInvite,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuroraPillTab extends StatelessWidget {
  final String label;
  final Color color;
  final bool active;

  const _AuroraPillTab({
    required this.label,
    required this.color,
    required this.active,
  });

  @override
  Widget build(BuildContext context) {
    const h = 46.0;
    const radius = 23.0;
    final dark = Color.lerp(color, Colors.black, 0.40)!;
    final darkEdge = Color.lerp(color, Colors.black, 0.26)!;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: active
            ? [
                BoxShadow(
                  color: color.withOpacity(0.50),
                  blurRadius: 22,
                  offset: const Offset(0, 5),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.20),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          fit: StackFit.expand,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              decoration: BoxDecoration(
                gradient: active
                    ? LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [dark, color, color, darkEdge],
                        stops: const [0.0, 0.28, 0.65, 1.0],
                      )
                    : LinearGradient(
                        colors: [
                          Colors.white.withOpacity(0.04),
                          Colors.white.withOpacity(0.08),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
              ),
            ),
            if (active)
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.25),
                    ],
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
            if (active)
              Positioned(
                top: 0,
                left: 10,
                right: 10,
                child: Container(
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Colors.transparent,
                        Colors.white.withOpacity(0.55),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            if (!active)
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(radius),
                  border: Border.all(
                    color: color.withOpacity(0.30),
                    width: 1,
                  ),
                ),
              ),
            Center(
              child: Text(
                label,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color:
                      active ? Colors.white : color.withOpacity(0.55),
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Category Chips
// ─────────────────────────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  final InvitationCategory? selected;
  final ValueChanged<InvitationCategory> onSelected;

  const _CategoryChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
        children: InvitationCategory.values.map((c) {
          final isSelected = selected == c;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(c),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [
                            AuroraTheme.auroraRed,
                            AuroraTheme.auroraBlue
                          ],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: isSelected ? null : AuroraTheme.glassBg,
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(
                    color: isSelected
                        ? Colors.transparent
                        : AuroraTheme.glassBorder,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AuroraTheme.auroraRed.withOpacity(0.3),
                            blurRadius: 12,
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (c == InvitationCategory.concert)
                      Text(
                        '♫',
                        style: TextStyle(
                          fontSize: 24,
                          height: 1.2,
                          color: isSelected ? Colors.white : AuroraTheme.auroraRed,
                        ),
                      )
                    else if (c == InvitationCategory.bar)
                      Image.asset('assets/icons/bar.png', width: 14, height: 14)
                    else
                      Text(c.emoji,
                          style: const TextStyle(fontSize: 13, height: 1.2)),
                    const SizedBox(width: 5),
                    Text(
                      c.labelFor(AppLocalizations.of(context)!),
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        height: 1.2,
                        color: isSelected
                            ? Colors.white
                            : AuroraTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invitation List
// ─────────────────────────────────────────────────────────────────────────────

class _InvitationList extends ConsumerStatefulWidget {
  final InvitationFlowType flowType;
  final InvitationCategory? category;
  final String? cityId;

  const _InvitationList(
      {required this.flowType, required this.category, this.cityId});

  @override
  ConsumerState<_InvitationList> createState() => _InvitationListState();
}

class _InvitationListState extends ConsumerState<_InvitationList> {
  late PageController _pageController;
  double _currentPage = 0;
  bool _ringInitialized = false;

  void _onPageScroll() {
    if (mounted) setState(() => _currentPage = _pageController.page ?? 0);
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(viewportFraction: 0.72);
    _pageController.addListener(_onPageScroll);
  }

  // Halka başlangıcı: listIndex 0'dan başla, ama ortada (500. tur)
  void _initRing(int length) {
    if (length == 0) return;
    final maxPage = length * 1000 - 1;
    final start = length * 500;
    if (!_ringInitialized) {
      _ringInitialized = true;
      _currentPage = start.toDouble();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(start);
        }
      });
    } else if (_currentPage > maxPage) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(start);
          setState(() => _currentPage = start.toDouble());
        }
      });
    } else {
      // autoDispose sonrası controller page 0'a döner — _currentPage'e geri zıpla
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        final cp = _pageController.page ?? 0;
        if ((_currentPage - cp).abs() > 2) {
          _pageController.jumpToPage(_currentPage.round());
        }
      });
    }
  }

  @override
  void didUpdateWidget(covariant _InvitationList oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.cityId != widget.cityId ||
        oldWidget.category != widget.category ||
        oldWidget.flowType != widget.flowType) {
      setState(() {
        _ringInitialized = false;
        _currentPage = 0;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _pageController.hasClients) {
          _pageController.jumpToPage(0);
        }
      });
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_onPageScroll);
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final flowType = widget.flowType;
    final filter = InvitationFilter(
        flowType: flowType, category: widget.category, cityId: widget.cityId);
    final async = ref.watch(invitationsProvider(filter));

    return async.when(
      loading: () => Center(
        child: SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation(AuroraTheme.auroraRed),
          ),
        ),
      ),
      error: (e, _) => Center(
        child: Text(AppLocalizations.of(context)!.feed_error(e.toString()),
            style: TextStyle(
                color: AuroraTheme.textSecondary,
                fontFamily: 'Manrope')),
      ),
      data: (invitations) {
        final l10n = AppLocalizations.of(context)!;
        if (invitations.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ShaderMask(
                  shaderCallback: (b) =>
                      AuroraTheme.redBlueGradient.createShader(b),
                  child: const Icon(Icons.explore_outlined,
                      color: Colors.white, size: 52),
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.feed_no_invitations,
                  style: TextStyle(
                    fontFamily: 'Fraunces',
                    fontStyle: FontStyle.italic,
                    fontSize: 22,
                    color: AuroraTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.feed_be_first,
                  style: AuroraTheme.monoLabel,
                ),
              ],
            ),
          );
        }
        _initRing(invitations.length);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(
                children: [
                  Text(
                    flowType == InvitationFlowType.invite
                        ? l10n.feed_todays_invitations
                        : l10n.feed_todays_requests,
                    style: AuroraTheme.monoLabel,
                  ),
                  const SizedBox(width: 6),
                  ShaderMask(
                    shaderCallback: (b) => AuroraTheme.redBlueGradient.createShader(b),
                    child: Text(l10n.feed_swipe_hint,
                        style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                padEnds: true,
                itemCount: invitations.length * 1000,
                itemBuilder: (_, i) {
                  final inv = invitations[i % invitations.length];
                  final currentUid = Supabase.instance.client.auth.currentUser?.id ?? '';
                  final isOwner = inv.ownerId == currentUid;
                  final absOffset = (_currentPage - i).abs().clamp(0.0, 1.0);
                  final scale = 1.0 - absOffset * 0.08;
                  final opacity = (1.0 - absOffset * 0.85).clamp(0.0, 1.0);
                  final shadowOpacity = (0.45 - absOffset * 0.35).clamp(0.0, 0.45);
                  final shadowBlur = 28.0 + absOffset * 12;
                  final shadowOffset = 16.0 - absOffset * 4;
                  return Transform.scale(
                    scale: scale,
                    child: Opacity(
                      opacity: opacity,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(shadowOpacity),
                                blurRadius: shadowBlur,
                                spreadRadius: -8,
                                offset: Offset(0, shadowOffset),
                              ),
                            ],
                          ),
                          child: InvitationCard(
                            title: inv.title,
                            category: inv.category,
                            venueName: inv.venueName ?? '',
                            ownerName: inv.owner?.name ?? '—',
                            ownerAge: inv.owner?.age ?? 0,
                            ownerPhotoUrl: inv.ownerPhotoUrl,
                            ownerCity: inv.cityName,
                            ownerVerified: inv.owner?.verified ?? false,
                            timeRemaining: inv.timeRemaining,
                            applicationCount: inv.applicationCount ?? 0,
                            applicantPhotoUrls: inv.applicantPhotoUrls,
                            eventDate: inv.eventDate,
                            flowType: flowType,
                            cardWidth: double.infinity,
                            isOwner: isOwner,
                            onTap: () => context.push('/invitation/${inv.id}'),
                            onCtaTap: isOwner
                                ? () => context.push('/invitation/${inv.id}/applicants')
                                : null,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Invitation Card — Aurora glass, cinematic full-bleed
// ─────────────────────────────────────────────────────────────────────────────

class InvitationCard extends StatelessWidget {
  final String title;
  final InvitationCategory category;
  final String venueName;
  final String ownerName;
  final int ownerAge;
  final String? ownerPhotoUrl;
  final String? ownerCity;
  final bool ownerVerified;
  final Duration timeRemaining;
  final int applicationCount;
  final List<String> applicantPhotoUrls;
  final DateTime? eventDate;
  final VoidCallback onTap;
  final VoidCallback? onCtaTap;
  final bool isOwner;
  final InvitationFlowType flowType;
  final double? cardWidth;

  const InvitationCard({
    super.key,
    required this.title,
    required this.category,
    required this.venueName,
    required this.ownerName,
    required this.ownerAge,
    this.ownerPhotoUrl,
    this.ownerCity,
    this.ownerVerified = false,
    required this.timeRemaining,
    required this.applicationCount,
    this.applicantPhotoUrls = const [],
    this.eventDate,
    required this.onTap,
    this.onCtaTap,
    this.isOwner = false,
    this.flowType = InvitationFlowType.invite,
    this.cardWidth,
  });

  String _formatTimer(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _metaLabel(AppLocalizations l10n, DateTime dt) {
    final days = [
      l10n.inv_detail_weekday_mon_full.toUpperCase(),
      l10n.inv_detail_weekday_tue_full.toUpperCase(),
      l10n.inv_detail_weekday_wed_full.toUpperCase(),
      l10n.inv_detail_weekday_thu_full.toUpperCase(),
      l10n.inv_detail_weekday_fri_full.toUpperCase(),
      l10n.inv_detail_weekday_sat_full.toUpperCase(),
      l10n.inv_detail_weekday_sun_full.toUpperCase(),
    ];
    final day = days[dt.weekday - 1];
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    final venue = venueName.isNotEmpty ? venueName.toUpperCase() : category.labelFor(l10n).toUpperCase();
    return '$day · $h:$m · $venue';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isInviteFlow = flowType == InvitationFlowType.invite;
    final glowColor = isInviteFlow ? AuroraTheme.auroraRed : AuroraTheme.auroraBlue;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth ?? 280,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 40,
              offset: const Offset(0, 16),
            ),
            BoxShadow(
              color: glowColor.withOpacity(0.20),
              blurRadius: 40,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Arka plan fotoğrafı — tam kapak, yüz üstte
              if (ownerPhotoUrl != null)
                CachedNetworkImage(
                  imageUrl: ownerPhotoUrl!,
                  fit: BoxFit.cover,
                  alignment: Alignment.topCenter,
                  placeholder: (_, __) => _CardFallbackGradient(ownerName: ownerName, category: category),
                  errorWidget: (_, __, ___) => _CardFallbackGradient(ownerName: ownerName, category: category),
                )
              else
                _CardFallbackGradient(ownerName: ownerName, category: category),

              // 2. Gradient overlay — alt %35, yüz temiz kalır, alt köşe net görünür
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      stops: const [0.0, 0.60, 0.82, 1.0],
                      colors: [
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.50),
                        Colors.black.withOpacity(0.84),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. Üst glass pill — avatar + isim/yaş (kategori badge ayrı)
              Positioned(
                top: 14,
                left: 14,
                right: 54,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(100),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(6, 5, 10, 5),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.38),
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Colors.white.withOpacity(0.18), width: 0.8),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withOpacity(0.30), width: 1.5),
                            ),
                            child: ClipOval(
                              child: ownerPhotoUrl != null
                                  ? CachedNetworkImage(imageUrl: ownerPhotoUrl!, fit: BoxFit.cover, errorWidget: (_, __, ___) => _AvatarFallback(name: ownerName))
                                  : _AvatarFallback(name: ownerName),
                            ),
                          ),
                          const SizedBox(width: 9),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // İsim + verified tik
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Flexible(
                                      child: Text(
                                        '$ownerName, $ownerAge',
                                        style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    if (ownerVerified) ...[
                                      const SizedBox(width: 4),
                                      Container(
                                        width: 14,
                                        height: 14,
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
                                        child: const Icon(Icons.check, size: 9, color: Colors.white),
                                      ),
                                    ],
                                  ],
                                ),
                                Text(
                                  ownerCity?.isNotEmpty == true ? ownerCity! : category.labelFor(l10n),
                                  style: TextStyle(fontFamily: 'JetBrainsMono', fontSize: 9, color: Colors.white.withOpacity(0.60)),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              // 3b. Kategori badge — sağ üst, yuvarlak glass pill
              Positioned(
                top: 14,
                right: 14,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.50),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                      ),
                      child: Center(
                        child: category == InvitationCategory.bar
                            ? Image.asset('assets/icons/bar.png', width: 14, height: 14)
                            : Text(
                                category.emoji,
                                style: TextStyle(
                                  fontSize: category == InvitationCategory.concert ? 18 : 14,
                                  color: category == InvitationCategory.concert ? AuroraTheme.auroraRed : null,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ),

              // 4. Alt içerik — timer + meta + başlık + full-width CTA
              Positioned(
                bottom: 18,
                left: 16,
                right: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Timer pill — soft glass
                    ClipRRect(
                      borderRadius: BorderRadius.circular(100),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(color: Colors.white.withOpacity(0.15), width: 1),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _PulsingDot(),
                              const SizedBox(width: 5),
                              Text(
                                _formatTimer(timeRemaining),
                                style: TextStyle(
                                  fontFamily: 'JetBrainsMono',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Mono caps meta: "SALI · 20:30 · SMOLENSKAYA"
                    if (eventDate != null)
                      Text(
                        _metaLabel(l10n, eventDate!),
                        style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 9, fontWeight: FontWeight.w700, color: Colors.white60, letterSpacing: 1.2),
                      ),
                    const SizedBox(height: 5),
                    // Fraunces italic başlık
                    Text(
                      title,
                      style: const TextStyle(fontFamily: 'Fraunces', fontStyle: FontStyle.italic, fontSize: 20, fontWeight: FontWeight.w600, color: Colors.white, height: 1.05, letterSpacing: -0.3),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 12),
                    // Full-width gradient CTA
                    GestureDetector(
                      onTap: onCtaTap ?? onTap,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: isOwner
                                ? [AuroraTheme.auroraBlue, AuroraTheme.auroraViolet]
                                : isInviteFlow
                                    ? [AuroraTheme.auroraRed, AuroraTheme.auroraBlue]
                                    : [AuroraTheme.auroraBlue, AuroraTheme.auroraRed],
                          ),
                          borderRadius: BorderRadius.circular(100),
                          boxShadow: [BoxShadow(color: glowColor.withOpacity(0.45), blurRadius: 16, offset: const Offset(0, 4))],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          isOwner
                              ? l10n.inv_detail_applicants_btn
                              : (isInviteFlow ? l10n.feed_cta_invite : l10n.feed_cta_request),
                          style: const TextStyle(fontFamily: 'JetBrainsMono', fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 0.5),
                        ),
                      ),
                    ),
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
// City Picker Bottom Sheet
// ─────────────────────────────────────────────────────────────────────────────

class _CityPickerSheet extends StatefulWidget {
  final String? selectedCityId;
  final void Function(String? cityId, String? cityName) onCitySelected;
  const _CityPickerSheet({this.selectedCityId, required this.onCitySelected});

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  List<({String id, String nameEn, String nameRu, String nameTr})>? _cities;
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _fetchCities();
    _searchController.addListener(
      () => setState(() => _query = _searchController.text.toLowerCase().trim()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCities() async {
    final data = await Supabase.instance.client
        .from('cities')
        .select('id, name_en, name_ru, name_tr')
        .eq('is_active', true)
        .order('name_en');
    if (!mounted) return;
    setState(() {
      _cities = (data as List)
          .map((r) => (
                id: r['id'] as String,
                nameEn: (r['name_en'] as String?) ?? '',
                nameRu: (r['name_ru'] as String?) ?? '',
                nameTr: (r['name_tr'] as String?) ?? '',
              ))
          .toList();
    });
  }

  String _locName({required String nameEn, required String nameRu, required String nameTr}) {
    final code = Localizations.localeOf(context).languageCode;
    if (code == 'ru' && nameRu.isNotEmpty) return nameRu;
    if (code == 'tr' && nameTr.isNotEmpty) return nameTr;
    return nameEn;
  }

  List<({String id, String nameEn, String nameRu, String nameTr})> get _filtered {
    if (_cities == null) return [];
    if (_query.isEmpty) return _cities!;
    return _cities!
        .where((c) =>
            c.nameEn.toLowerCase().contains(_query) ||
            c.nameRu.toLowerCase().contains(_query) ||
            c.nameTr.toLowerCase().contains(_query))
        .toList();
  }

  String _cityEmoji(String nameEn) {
    switch (nameEn.toLowerCase()) {
      case 'moscow':
      case 'saint petersburg':
        return '🇷🇺';
      case 'istanbul':
        return '🇹🇷';
      case 'london':
        return '🇬🇧';
      case 'dubai':
        return '🇦🇪';
      case 'berlin':
        return '🇩🇪';
      default:
        return '📍';
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(
            color: AuroraTheme.bgDeep.withOpacity(0.94),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border(
              top: BorderSide(
                  color: Colors.white.withOpacity(0.12), width: 0.8),
            ),
          ),
          child: Column(
            children: [
              // ── Handle ──
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              // ── Başlık ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: ShaderMask(
                  shaderCallback: (b) =>
                      AuroraTheme.redBlueGradient.createShader(b),
                  child: Text(
                    AppLocalizations.of(context)!.feed_city_picker_title,
                    style: TextStyle(
                      fontFamily: 'Fraunces',
                      fontStyle: FontStyle.italic,
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              // ── Arama kutusu ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: TextField(
                      controller: _searchController,
                      autofocus: false,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        color: Colors.white,
                      ),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context)!.feed_city_search_hint,
                        hintStyle: TextStyle(
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          color: AuroraTheme.textMuted,
                        ),
                        prefixIcon: Icon(Icons.search_rounded,
                            color: AuroraTheme.textMuted, size: 20),
                        suffixIcon: _query.isNotEmpty
                            ? GestureDetector(
                                onTap: () => _searchController.clear(),
                                child: Icon(Icons.close_rounded,
                                    color: AuroraTheme.textMuted, size: 18),
                              )
                            : null,
                        filled: true,
                        fillColor: Colors.white.withOpacity(0.07),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.12),
                              width: 0.8),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(
                              color: Colors.white.withOpacity(0.12),
                              width: 0.8),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                              color: AuroraTheme.auroraRed, width: 1),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // ── Liste (kaydırılabilir) ──
              Expanded(
                child: _cities == null
                    ? Center(
                        child: SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation(
                                AuroraTheme.auroraRed),
                          ),
                        ),
                      )
                    : ListView(
                        padding: EdgeInsets.only(
                            bottom: bottomPad + 24, top: 4),
                        children: [
                          // "Tüm Şehirler" yalnızca arama yokken
                          if (_query.isEmpty)
                            _CityRow(
                              name: AppLocalizations.of(context)!.feed_all_cities,
                              emoji: '🌍',
                              selected: widget.selectedCityId == null,
                              onTap: () => widget.onCitySelected(null, null),
                            ),
                          ...filtered.map((c) {
                            final displayName = _locName(nameEn: c.nameEn, nameRu: c.nameRu, nameTr: c.nameTr);
                            return _CityRow(
                              name: displayName,
                              emoji: _cityEmoji(c.nameEn),
                              selected: widget.selectedCityId == c.id,
                              onTap: () => widget.onCitySelected(c.id, displayName),
                            );
                          }),
                          if (filtered.isEmpty)
                            Padding(
                              padding: const EdgeInsets.all(32),
                              child: Center(
                                child: Text(
                                  AppLocalizations.of(context)!.feed_city_not_found(_query),
                                  style: TextStyle(
                                    fontFamily: 'Manrope',
                                    fontSize: 14,
                                    color: AuroraTheme.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
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

class _CityRow extends StatelessWidget {
  final String name;
  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  const _CityRow({
    required this.name,
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: selected
              ? const LinearGradient(
                  colors: [AuroraTheme.auroraRed, AuroraTheme.auroraBlue],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : null,
          color: selected ? null : AuroraTheme.glassBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Colors.transparent
                : AuroraTheme.glassBorder,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: AuroraTheme.auroraRed.withOpacity(0.3),
                    blurRadius: 12,
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 12),
            Text(
              name,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: selected ? Colors.white : AuroraTheme.textSecondary,
              ),
            ),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_circle_rounded,
                  color: Colors.white, size: 20),
          ],
        ),
      ),
    );
  }
}

class _CardFallbackGradient extends StatelessWidget {
  final String ownerName;
  final InvitationCategory category;
  const _CardFallbackGradient(
      {this.ownerName = '', required this.category});

  @override
  Widget build(BuildContext context) {
    final raw = ownerName.trim();
    final initials = raw.isEmpty
        ? '✦'
        : raw
            .split(' ')
            .where((w) => w.isNotEmpty)
            .map((w) => w[0])
            .take(2)
            .join()
            .toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1A0510),
            Color(0xFF0A0B1A),
            AuroraTheme.bgDeep
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          category == InvitationCategory.bar
              ? Image.asset('assets/icons/bar.png', width: 80, height: 80)
              : Text(
                  category.emoji,
                  style: TextStyle(
                    fontSize: 80,
                    color: category == InvitationCategory.concert ? AuroraTheme.auroraRed : null,
                  ),
                ),
          const SizedBox(height: 28),
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [
                  AuroraTheme.auroraViolet,
                  AuroraTheme.auroraRed,
                  AuroraTheme.auroraBlue
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: AuroraTheme.auroraRed.withOpacity(0.45),
                  blurRadius: 24,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: Center(
              child: Text(
                initials,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: MediaQuery.of(context).size.width < 360 ? 25.5 : 30,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Pulsing Dot — timer pill için animasyonlu kırmızı nokta
// ─────────────────────────────────────────────────────────────────────────────

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.35, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          width: 5,
          height: 5,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AuroraTheme.auroraGold.withOpacity(_anim.value),
            boxShadow: [
              BoxShadow(
                color: AuroraTheme.auroraGold.withOpacity(_anim.value * 0.7),
                blurRadius: 6,
              ),
            ],
          ),
        ),
      );
}
