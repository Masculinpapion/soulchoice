import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../data/models/invitation_model.dart';
import '../../../features/feed/providers/invitations_provider.dart';
import '../../../features/invitation/providers/invitation_provider.dart';
import '../providers/my_active_invitation_provider.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/sc_button.dart';
import '../../../shared/widgets/sc_scaffold.dart';
import '../widgets/place_picker.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

// Bu ekrana özel, tekrar eden Aurora metin stilleri (eski AppTextStyles yerine).
const _displayMediumStyle = TextStyle(
  fontFamily: 'Fraunces',
  fontStyle: FontStyle.italic,
  fontSize: 34,
  fontWeight: FontWeight.w400,
  color: AuroraTheme.textPrimary,
  letterSpacing: -0.5,
  height: 1.15,
);
final _bodyMediumStyle = TextStyle(
  fontFamily: 'Manrope',
  fontSize: 14,
  fontWeight: FontWeight.w400,
  color: AuroraTheme.textSecondary,
  height: 1.5,
);
const _bodyLargeStyle = TextStyle(
  fontFamily: 'Manrope',
  fontSize: 16,
  fontWeight: FontWeight.w400,
  color: AuroraTheme.textPrimary,
  height: 1.6,
);
const _titleStyle = TextStyle(
  fontFamily: 'Manrope',
  fontSize: 17,
  fontWeight: FontWeight.w700,
  color: AuroraTheme.textPrimary,
  letterSpacing: -0.1,
);
final _monoSmallStyle = TextStyle(
  fontFamily: 'JetBrainsMono',
  fontSize: 11,
  fontWeight: FontWeight.w400,
  color: AuroraTheme.textMuted,
  letterSpacing: 0.25,
);
final _labelMediumStyle = TextStyle(
  fontFamily: 'Manrope',
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: AuroraTheme.textSecondary,
  letterSpacing: 0.05,
);
const _feedCardTitleStyle = TextStyle(
  fontFamily: 'Manrope',
  fontSize: 22,
  fontWeight: FontWeight.w800,
  color: AuroraTheme.textPrimary,
  letterSpacing: 1.2,
  shadows: [
    Shadow(color: Color(0xCC000000), offset: Offset(0, 2), blurRadius: 12),
    Shadow(color: Color(0x40FF2D55), offset: Offset(0, 0), blurRadius: 20),
  ],
);

class CreateInvitationScreen extends ConsumerStatefulWidget {
  const CreateInvitationScreen({super.key});

  @override
  ConsumerState<CreateInvitationScreen> createState() =>
      _CreateInvitationScreenState();
}

class _CreateInvitationScreenState
    extends ConsumerState<CreateInvitationScreen> {
  int _step = 0;
  final _pageController = PageController();

  // Form state
  InvitationFlowType _flowType = InvitationFlowType.invite;
  InvitationCategory? _category;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  DateTime? _eventDate;
  int _expiryHours = 24;
  bool _isPublishing = false;
  PlaceSuggestion? _selectedPlace;
  String? _cityId;

  bool get _isTravel => _category == InvitationCategory.travel;

  int get _stepCount => 7;

  // 12 kategori tek çatı: kategori sadece PlacePicker modunu seçer.
  PlacePickerMode get _pickerMode => _isTravel
      ? PlacePickerMode.destination
      : (_category == InvitationCategory.gift
          ? PlacePickerMode.brand
          : PlacePickerMode.venue);

  List<String> _getSteps(AppLocalizations l10n) => [
    l10n.create_inv_step_flow_type,
    l10n.create_inv_step_category,
    l10n.create_inv_step_title,
    l10n.create_inv_step_description,
    switch (_pickerMode) {
      PlacePickerMode.destination => l10n.create_inv_step_destination,
      PlacePickerMode.brand => l10n.create_inv_step_brand,
      PlacePickerMode.venue => l10n.create_inv_step_venue,
    },
    l10n.create_inv_step_datetime,
    l10n.create_inv_step_duration,
  ];

  List<Widget> _buildPages(AppLocalizations l10n) => [
    _StepFlowType(
      selected: _flowType,
      onSelected: (v) => setState(() => _flowType = v),
    ),
    _StepCategory(
      selected: _category,
      onSelected: (v) => setState(() {
        if (v != _category) {
          // Kategori değişti — eski mod/kategoriye ait yer seçimi geçersiz.
          _venueController.clear();
          _selectedPlace = null;
        }
        _category = v;
      }),
    ),
    _StepTitle(controller: _titleController),
    _StepDescription(
      controller: _descriptionController,
      flowType: _flowType,
      category: _category,
    ),
    _StepVenue(
      controller: _venueController,
      category: _category,
      flowType: _flowType,
      mode: _pickerMode,
      cityId: _cityId,
      onPlaceSelected: (s) => _selectedPlace = s,
    ),
    _StepDateTime(
      date: _eventDate,
      onSelected: (d) => setState(() => _eventDate = d),
    ),
    _StepDuration(
      selected: _expiryHours,
      onSelected: (h) => setState(() => _expiryHours = h),
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadCityId();
    WidgetsBinding.instance.addPostFrameCallback((_) => _checkSelfieGate());
  }

  Future<void> _checkSelfieGate() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    final row = await Supabase.instance.client
        .from('users')
        .select('selfie_status')
        .eq('id', uid)
        .maybeSingle();
    final status = row?['selfie_status'] as String? ?? 'none';
    if (status == 'approved' || !mounted) return;

    final l = AppLocalizations.of(context)!;
    final goSelfie = status != 'pending';
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuroraTheme.bgDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(l.create_inv_gate_title, style: _titleStyle),
        content: Text(
          status == 'pending'
              ? l.create_inv_gate_pending
              : status == 'rejected'
              ? l.create_inv_gate_rejected
              : l.create_inv_gate_none,
          style: _bodyMediumStyle,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(
              goSelfie
                  ? l.create_inv_gate_action_upload
                  : l.create_inv_gate_action_ok,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                color: AuroraTheme.auroraRed,
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (goSelfie) {
      context.pushReplacement('/profile/selfie');
    } else {
      context.pop();
    }
  }

  Future<bool> _checkActiveInvitationLimit(InvitationFlowType flowType) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return false;
    final rows = await Supabase.instance.client
        .from('invitations')
        .select('id')
        .eq('owner_id', uid)
        .eq('flow_type', flowType.name)
        .eq('status', 'active')
        .gt('expires_at', DateTime.now().toUtc().toIso8601String())
        .order('created_at', ascending: false)
        .limit(1);
    if (rows.isEmpty || !mounted) return false;

    final existingId = rows.first['id'] as String;
    final l = AppLocalizations.of(context)!;
    final isInvite = flowType == InvitationFlowType.invite;
    final goView = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AuroraTheme.bgDeep,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isInvite
              ? l.create_inv_active_limit_title_invite
              : l.create_inv_active_limit_title_request,
          style: _titleStyle,
        ),
        content: Text(l.create_inv_active_limit_body, style: _bodyMediumStyle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(
              l.create_inv_active_limit_cta_ok,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                color: Colors.white54,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(
              l.create_inv_active_limit_cta_view,
              style: const TextStyle(
                fontFamily: 'JetBrainsMono',
                color: AuroraTheme.auroraRed,
              ),
            ),
          ),
        ],
      ),
    );
    if (!mounted) return true;
    if (goView == true) {
      context.pushReplacement('/invitation/$existingId');
    }
    return true;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadCityId() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final row = await Supabase.instance.client
          .from('users')
          .select('city_id')
          .eq('id', uid)
          .maybeSingle();
      if (mounted) setState(() => _cityId = row?['city_id'] as String?);
    } catch (_) {
      // Şehir gelmezse öneriler kısıtlanır; serbest metin yolu açık kalır.
    }
  }

  String? _validateCurrentStep(AppLocalizations l10n) {
    switch (_step) {
      case 1:
        if (_category == null) return l10n.create_inv_validation_category;
      case 2:
        if (_titleController.text.trim().isEmpty)
          return l10n.create_inv_validation_title;
      case 3:
        if (_isTravel && _descriptionController.text.trim().isEmpty) {
          return l10n.create_inv_validation_description_travel;
        }
      case 4:
        if (_venueController.text.trim().isEmpty) {
          return l10n.create_inv_validation_venue;
        }
      case 5:
        if (_eventDate == null) return l10n.create_inv_validation_date;
    }
    return null;
  }

  Future<void> _next() async {
    if (_step == 0) {
      final blocked = await _checkActiveInvitationLimit(_flowType);
      if (!mounted || blocked) return;
    }
    final l10n = AppLocalizations.of(context)!;
    final error = _validateCurrentStep(l10n);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontWeight: FontWeight.w600,
            ),
          ),
          backgroundColor: AuroraTheme.auroraRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        ),
      );
      return;
    }
    if (_step < _stepCount - 1) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      _publish();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOutCubic,
      );
    } else {
      context.pop();
    }
  }

  /// Metin güzelleştirme:
  /// - Tümü küçük  → cümle başı büyük (. ! ? sonrası)
  /// - TÜMÜ BÜYÜK  → önce küçült, sonra cümle başı büyük
  /// - Karışık      → yalnızca ilk harf büyük ("White Rabbit" gibi proper noun'lar korunur)
  String _fixCase(String text) {
    final t = text.trim();
    if (t.isEmpty) return t;

    final letters = RegExp(r'\p{L}', unicode: true);
    if (!letters.hasMatch(t)) return t;

    final isAllLower = t == t.toLowerCase();
    final isAllUpper = t == t.toUpperCase();

    if (isAllLower || isAllUpper) {
      final base = isAllUpper ? t.toLowerCase() : t;
      final buf = StringBuffer();
      bool capNext = true;
      for (int i = 0; i < base.length; i++) {
        final ch = base[i];
        if (capNext && letters.hasMatch(ch)) {
          buf.write(ch.toUpperCase());
          capNext = false;
        } else {
          buf.write(ch);
        }
        if (ch == '.' || ch == '!' || ch == '?') capNext = true;
      }
      return buf.toString();
    }

    // Karışık — sadece ilk harf büyük garantisi
    return t[0].toUpperCase() + t.substring(1);
  }

  Future<void> _publish() async {
    setState(() => _isPublishing = true);
    try {
      final client = Supabase.instance.client;
      final place = _selectedPlace;
      final venueText = _venueController.text.trim();
      // Seçilmiş yer adını olduğu gibi taşı; serbest metni eski usul biçimle.
      final venueFormatted = venueText.isEmpty
          ? null
          : place != null
              ? place.name
              : venueText
                    .split(' ')
                    .where((w) => w.isNotEmpty)
                    .map((w) => w[0].toUpperCase() + w.substring(1))
                    .join(' ');
      final venueAddress =
          (place != null && place.subtitle.isNotEmpty) ? place.subtitle : null;

      final user = client.auth.currentUser;
      if (user == null) {
        setState(() => _isPublishing = false);
        return;
      }
      final uid = user.id;
      final userRow = await client
          .from('users')
          .select('city_id')
          .eq('id', uid)
          .maybeSingle();
      final cityId = userRow?['city_id'] as String?;

      await client.from('invitations').insert({
        'owner_id': uid,
        'flow_type': _flowType.name,
        'category': _category?.name ?? InvitationCategory.food.name,
        'title': _fixCase(_titleController.text),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _fixCase(_descriptionController.text),
        'venue_name': venueFormatted,
        'venue_address': venueAddress,
        'venue_lat': place?.lat,
        'venue_lng': place?.lng,
        'place_id': place?.id,
        'place_kind': venueFormatted == null ? null : _pickerMode.name,
        'event_date': _eventDate?.toIso8601String(),
        'expires_at': DateTime.now()
            .toUtc()
            .add(Duration(hours: _expiryHours))
            .toIso8601String(),
        'city_id': cityId,
        'slots_total': 1,
        'status': 'active',
      });

      if (place != null) {
        // Flywheel: seçilen yerin popülerliği artar (fire-and-forget).
        // ignore: unawaited_futures
        client.rpc('touch_place', params: {'p_place_id': place.id});
      }

      if (mounted) {
        ref.invalidate(invitationsProvider);
        ref.invalidate(myActiveInvitationsProvider);
        context.go('/feed');
      }
    } catch (e) {
      if (mounted) {
        final isLimitError =
            e is PostgrestException && e.message == 'ACTIVE_INVITATION_LIMIT';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            backgroundColor: AuroraTheme.bgDeep,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: AuroraTheme.auroraRed.withOpacity(0.4)),
            ),
            content: Row(
              children: [
                const Icon(
                  Icons.error_outline,
                  color: AuroraTheme.auroraRed,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isLimitError
                        ? AppLocalizations.of(
                            context,
                          )!.create_inv_error_active_limit
                        : AppLocalizations.of(
                            context,
                          )!.create_inv_error_publish(e.toString()),
                    style: const TextStyle(
                      fontFamily: 'Manrope',
                      fontSize: 13,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final steps = _getSteps(l10n);
    return ScScaffold(
      backgroundColor: AuroraTheme.bgDeep,
      body: AmbientBackground(
        child: SafeArea(
          child: Column(
            children: [
              // ── Header with progress ──────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: AuroraTheme.textPrimary,
                        size: 20,
                      ),
                      onPressed: _back,
                    ),
                    Expanded(
                      child: _GradientProgressBar(
                        value: (_step + 1) / _stepCount,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Step label ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _StepDots(total: _stepCount, current: _step),
                    const SizedBox(width: 10),
                    Text(
                      steps[_step],
                      style: _monoSmallStyle.copyWith(
                        color: AuroraTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // ── Page content ──────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: _buildPages(l10n),
                ),
              ),
              // ── Footer CTA ────────────────────────────────────────────
              // Üst 12px: klavye açılıp içerik daralınca buton metin alanına
              // yapışmasın (13.07 bulgusu — Açıklama adımında sıfır temas).
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: ScButton(
                  label: _step < _stepCount - 1
                      ? l10n.create_inv_btn_next
                      : l10n.create_inv_btn_publish,
                  onPressed: _isPublishing ? null : _next,
                  isLoading: _isPublishing && _step == _stepCount - 1,
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
// Gradient Progress Bar
// ─────────────────────────────────────────────────────────────────────────────

class _GradientProgressBar extends StatelessWidget {
  final double value;
  const _GradientProgressBar({required this.value});

  @override
  Widget build(BuildContext context) => Container(
    height: 4,
    decoration: BoxDecoration(
      color: AuroraTheme.glassBorder,
      borderRadius: BorderRadius.circular(4),
    ),
    child: FractionallySizedBox(
      widthFactor: value,
      alignment: Alignment.centerLeft,
      child: Container(
        decoration: BoxDecoration(
          gradient: AuroraTheme.redBlueGradient,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Step Dots
// ─────────────────────────────────────────────────────────────────────────────

class _StepDots extends StatelessWidget {
  final int total;
  final int current;
  const _StepDots({required this.total, required this.current});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: List.generate(total, (i) {
      final isActive = i == current;
      final isPast = i < current;
      return Container(
        width: isActive ? 16 : 5,
        height: 5,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          gradient: (isActive || isPast) ? AuroraTheme.redBlueGradient : null,
          color: (isActive || isPast) ? null : Colors.white.withOpacity(0.25),
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Step: Flow Type
// ─────────────────────────────────────────────────────────────────────────────

class _StepFlowType extends StatelessWidget {
  final InvitationFlowType selected;
  final ValueChanged<InvitationFlowType> onSelected;

  const _StepFlowType({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            AppLocalizations.of(context)!.create_inv_flow_question,
            style: _displayMediumStyle,
          ),
          const SizedBox(height: 40),
          _FlowTypeCard(
            title: AppLocalizations.of(context)!.create_inv_flow_invite_title,
            subtitle: AppLocalizations.of(
              context,
            )!.create_inv_flow_invite_subtitle,
            icon: Icons.wine_bar_rounded,
            gradientColors: const [
              AuroraTheme.auroraRed,
              AuroraTheme.auroraViolet,
            ],
            isSelected: selected == InvitationFlowType.invite,
            onTap: () => onSelected(InvitationFlowType.invite),
          ),
          const SizedBox(height: 14),
          _FlowTypeCard(
            title: AppLocalizations.of(context)!.create_inv_flow_request_title,
            subtitle: AppLocalizations.of(
              context,
            )!.create_inv_flow_request_subtitle,
            icon: Icons.explore_rounded,
            gradientColors: const [
              AuroraTheme.auroraBlue,
              AuroraTheme.auroraViolet,
            ],
            isSelected: selected == InvitationFlowType.request,
            onTap: () => onSelected(InvitationFlowType.request),
          ),
        ],
      ),
    );
  }
}

class _FlowTypeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Color> gradientColors;
  final bool isSelected;
  final VoidCallback onTap;
  const _FlowTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.gradientColors,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isSelected
            ? AuroraTheme.auroraRed.withOpacity(0.08)
            : AuroraTheme.glassBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AuroraTheme.auroraRed : AuroraTheme.glassBorder,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: gradientColors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: gradientColors[0].withOpacity(0.45),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: _titleStyle),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(subtitle, style: _bodyMediumStyle),
                ],
              ],
            ),
          ),
          if (isSelected)
            ShaderMask(
              blendMode: BlendMode.srcIn,
              shaderCallback: (b) => AuroraTheme.redBlueGradient.createShader(
                Rect.fromLTRB(
                  b.left - 4,
                  b.top - 2,
                  b.right + 14,
                  b.bottom + 4,
                ),
              ),
              child: const Icon(
                Icons.check_circle,
                color: Colors.white,
                size: 22,
              ),
            ),
        ],
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Step: Category
// ─────────────────────────────────────────────────────────────────────────────

class _StepCategory extends StatelessWidget {
  final InvitationCategory? selected;
  final ValueChanged<InvitationCategory> onSelected;

  const _StepCategory({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.create_inv_step_category,
            style: _displayMediumStyle,
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.create_inv_category_question,
            style: _bodyMediumStyle,
          ),
          const SizedBox(height: 20),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 3,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            // 1.15: 12 kategori (4 satır) tek ekrana sığsın, son satır
            // İleri butonunun altında kesilmesin (13.07 bulgusu).
            childAspectRatio: 1.15,
            children: InvitationCategory.values.map((c) {
              final isSelected = selected == c;
              return GestureDetector(
                onTap: () => onSelected(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  decoration: BoxDecoration(
                    gradient: isSelected ? AuroraTheme.redBlueGradient : null,
                    color: isSelected ? null : AuroraTheme.glassBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : AuroraTheme.glassBorder,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: Center(
                          child: c == InvitationCategory.bar
                              ? Image.asset(
                                  'assets/icons/bar.png',
                                  width: 32,
                                  height: 32,
                                )
                              : c == InvitationCategory.concert
                              ? Image.asset(
                                  'assets/icons/music.png',
                                  width: 22,
                                  height: 22,
                                  color: AuroraTheme.auroraRed,
                                )
                              : Text(
                                  c.emoji,
                                  style: const TextStyle(fontSize: 28),
                                ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        c.labelFor(AppLocalizations.of(context)!),
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        style: _labelMediumStyle.copyWith(
                          color: isSelected
                              ? AuroraTheme.textPrimary
                              : AuroraTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step: Title
// ─────────────────────────────────────────────────────────────────────────────

class _StepTitle extends StatelessWidget {
  final TextEditingController controller;
  const _StepTitle({required this.controller});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          AppLocalizations.of(context)!.create_inv_step_title,
          style: _displayMediumStyle,
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.create_inv_title_subtitle,
          style: _bodyMediumStyle,
        ),
        const SizedBox(height: 32),
        TextField(
          controller: controller,
          maxLength: 60,
          style: _feedCardTitleStyle.copyWith(fontSize: 20),
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.create_inv_title_label,
          ),
        ),
      ],
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Step: Description
// ─────────────────────────────────────────────────────────────────────────────

class _StepDescription extends StatelessWidget {
  final TextEditingController controller;
  final InvitationFlowType flowType;
  final InvitationCategory? category;
  const _StepDescription({
    required this.controller,
    required this.flowType,
    this.category,
  });

  String _hint(AppLocalizations l10n) {
    final isInvite = flowType == InvitationFlowType.invite;
    switch (category) {
      case InvitationCategory.food:
        return isInvite
            ? l10n.create_inv_desc_invite_food
            : l10n.create_inv_desc_request_food;
      case InvitationCategory.bar:
        return isInvite
            ? l10n.create_inv_desc_invite_bar
            : l10n.create_inv_desc_request_bar;
      case InvitationCategory.coffee:
        return isInvite
            ? l10n.create_inv_desc_invite_coffee
            : l10n.create_inv_desc_request_coffee;
      case InvitationCategory.cinema:
        return isInvite
            ? l10n.create_inv_desc_invite_cinema
            : l10n.create_inv_desc_request_cinema;
      case InvitationCategory.theater:
        return isInvite
            ? l10n.create_inv_desc_invite_theater
            : l10n.create_inv_desc_request_theater;
      case InvitationCategory.concert:
        return isInvite
            ? l10n.create_inv_desc_invite_concert
            : l10n.create_inv_desc_request_concert;
      case InvitationCategory.culture:
        return isInvite
            ? l10n.create_inv_desc_invite_culture
            : l10n.create_inv_desc_request_culture;
      case InvitationCategory.travel:
        return isInvite
            ? l10n.create_inv_desc_invite_travel
            : l10n.create_inv_desc_request_travel;
      case InvitationCategory.gift:
        return isInvite
            ? l10n.create_inv_desc_invite_gift
            : l10n.create_inv_desc_request_gift;
      case InvitationCategory.sport:
        return isInvite
            ? l10n.create_inv_desc_invite_sport
            : l10n.create_inv_desc_request_sport;
      case InvitationCategory.walk:
        return isInvite
            ? l10n.create_inv_desc_invite_walk
            : l10n.create_inv_desc_request_walk;
      case InvitationCategory.karaoke:
        return isInvite
            ? l10n.create_inv_desc_invite_karaoke
            : l10n.create_inv_desc_request_karaoke;
      default:
        return isInvite
            ? l10n.create_inv_desc_invite_hint
            : l10n.create_inv_desc_request_hint;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final subtitle = _hint(l10n);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Sıkı boşluklar + sayaç gizli: klavye açıkken alan BÜTÜNÜYLE
          // görünür kalsın, alt kenarı kesilmesin (13.07 bulgusu).
          const SizedBox(height: 8),
          Text(l10n.create_inv_step_description, style: _displayMediumStyle),
          const SizedBox(height: 8),
          Text(subtitle, style: _bodyMediumStyle),
          const SizedBox(height: 20),
          TextField(
            controller: controller,
            maxLines: 4,
            maxLength: 300,
            style: _bodyLargeStyle,
            scrollPadding: const EdgeInsets.only(bottom: 120),
            decoration: InputDecoration(
              hintText: l10n.create_inv_desc_input_hint,
              alignLabelWithHint: true,
              counterText: '',
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step: Venue
// ─────────────────────────────────────────────────────────────────────────────

class _StepVenue extends StatelessWidget {
  final TextEditingController controller;
  final InvitationCategory? category;
  final InvitationFlowType flowType;
  final PlacePickerMode mode;
  final String? cityId;
  final ValueChanged<PlaceSuggestion?> onPlaceSelected;
  const _StepVenue({
    required this.controller,
    this.category,
    required this.flowType,
    required this.mode,
    required this.cityId,
    required this.onPlaceSelected,
  });

  String _question(AppLocalizations l10n) {
    switch (category) {
      case InvitationCategory.gift:
        return l10n.create_inv_venue_question_gift;
      case InvitationCategory.cinema:
        return l10n.create_inv_venue_question_cinema;
      case InvitationCategory.theater:
        return l10n.create_inv_venue_question_theater;
      case InvitationCategory.concert:
        return l10n.create_inv_venue_question_concert;
      case InvitationCategory.travel:
        return l10n.create_inv_venue_question_travel;
      default:
        return l10n.create_inv_venue_question;
    }
  }

  String _subtitle(AppLocalizations l10n) {
    final isInvite = flowType == InvitationFlowType.invite;
    switch (category) {
      case InvitationCategory.gift:
        return isInvite
            ? l10n.create_inv_venue_subtitle_gift
            : l10n.create_inv_venue_subtitle_gift_request;
      case InvitationCategory.cinema:
        return l10n.create_inv_venue_subtitle_cinema;
      case InvitationCategory.theater:
        return l10n.create_inv_venue_subtitle_theater;
      case InvitationCategory.concert:
        return l10n.create_inv_venue_subtitle_concert;
      case InvitationCategory.travel:
        return l10n.create_inv_venue_subtitle_travel;
      default:
        return l10n.create_inv_venue_subtitle;
    }
  }

  String _placeholder(AppLocalizations l10n) {
    switch (category) {
      case InvitationCategory.food:
        return l10n.create_inv_venue_ph_food;
      case InvitationCategory.bar:
        return l10n.create_inv_venue_ph_bar;
      case InvitationCategory.coffee:
        return l10n.create_inv_venue_ph_coffee;
      case InvitationCategory.cinema:
        return l10n.create_inv_venue_ph_cinema;
      case InvitationCategory.theater:
        return l10n.create_inv_venue_ph_theater;
      case InvitationCategory.concert:
        return l10n.create_inv_venue_ph_concert;
      case InvitationCategory.culture:
        return l10n.create_inv_venue_ph_culture;
      case InvitationCategory.travel:
        return l10n.create_inv_venue_ph_travel;
      case InvitationCategory.gift:
        return l10n.create_inv_venue_ph_gift;
      case InvitationCategory.sport:
        return l10n.create_inv_venue_ph_sport;
      case InvitationCategory.walk:
        return l10n.create_inv_venue_ph_walk;
      case InvitationCategory.karaoke:
        return l10n.create_inv_venue_ph_karaoke;
      default:
        return l10n.create_inv_venue_placeholder;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(_question(l10n), style: _displayMediumStyle),
          const SizedBox(height: 8),
          Text(_subtitle(l10n), style: _bodyMediumStyle),
          const SizedBox(height: 32),
          PlacePicker(
            controller: controller,
            mode: mode,
            cityId: cityId,
            category: category?.name,
            labelText: l10n.create_inv_venue_label,
            hintText: _placeholder(l10n),
            onSelected: onPlaceSelected,
          ),
          // Öneri listesi sabit CTA'nın üstüne kaydırılabilsin diye pay.
          const SizedBox(height: 220),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Step: Duration
// ─────────────────────────────────────────────────────────────────────────────

class _StepDuration extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;

  const _StepDuration({required this.selected, required this.onSelected});

  List<(int, String, String)> _options(AppLocalizations l10n) => [
    (6, l10n.create_inv_duration_6h, l10n.create_inv_duration_6h_desc),
    (12, l10n.create_inv_duration_12h, l10n.create_inv_duration_12h_desc),
    (24, l10n.create_inv_duration_24h, l10n.create_inv_duration_24h_desc),
    (48, l10n.create_inv_duration_48h, l10n.create_inv_duration_48h_desc),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(l10n.create_inv_duration_question, style: _displayMediumStyle),
          const SizedBox(height: 8),
          Text(l10n.create_inv_duration_subtitle, style: _bodyMediumStyle),
          const SizedBox(height: 32),
          ..._options(l10n).map(
            (opt) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => onSelected(opt.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    gradient: selected == opt.$1
                        ? AuroraTheme.redBlueGradient
                        : null,
                    color: selected == opt.$1 ? null : AuroraTheme.glassBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: selected == opt.$1
                          ? Colors.transparent
                          : AuroraTheme.glassBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(opt.$2, style: _titleStyle),
                            const SizedBox(height: 2),
                            Text(
                              opt.$3,
                              style: _bodyMediumStyle.copyWith(
                                color: selected == opt.$1
                                    ? AuroraTheme.textPrimary.withOpacity(0.75)
                                    : AuroraTheme.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (selected == opt.$1)
                        ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (b) => selected == opt.$1
                              ? const LinearGradient(
                                  colors: [Colors.white, Colors.white],
                                ).createShader(b)
                              : AuroraTheme.redBlueGradient.createShader(b),
                          child: const Icon(
                            Icons.check_circle,
                            color: Colors.white,
                            size: 22,
                          ),
                        ),
                    ],
                  ),
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
// Step: Date & Time
// ─────────────────────────────────────────────────────────────────────────────

class _StepDateTime extends StatelessWidget {
  final DateTime? date;
  final ValueChanged<DateTime> onSelected;

  const _StepDateTime({required this.date, required this.onSelected});

  String _format(DateTime dt) {
    final d =
        '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$d  $h:$m';
  }

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Text(
          AppLocalizations.of(context)!.create_inv_datetime_question,
          style: _displayMediumStyle,
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.create_inv_datetime_subtitle,
          style: _bodyMediumStyle,
        ),
        const SizedBox(height: 32),
        GlassCard(
          onTap: () async {
            final now = DateTime.now();
            final pickedDate = await showDatePicker(
              context: context,
              initialDate: now.add(const Duration(hours: 2)),
              firstDate: now,
              lastDate: now.add(const Duration(days: 30)),
            );
            if (pickedDate == null || !context.mounted) return;
            final pickedTime = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: (now.hour + 2) % 24, minute: 0),
              initialEntryMode: TimePickerEntryMode.input,
            );
            if (pickedTime == null) return;
            onSelected(
              DateTime(
                pickedDate.year,
                pickedDate.month,
                pickedDate.day,
                pickedTime.hour,
                pickedTime.minute,
              ),
            );
          },
          child: Row(
            children: [
              ShaderMask(
                blendMode: BlendMode.srcIn,
                shaderCallback: (b) => AuroraTheme.redBlueGradient.createShader(
                  Rect.fromLTRB(
                    b.left - 4,
                    b.top - 2,
                    b.right + 14,
                    b.bottom + 4,
                  ),
                ),
                child: const Icon(
                  Icons.calendar_today_outlined,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),
              Text(
                date != null
                    ? _format(date!)
                    : AppLocalizations.of(
                        context,
                      )!.create_inv_datetime_placeholder,
                style: _bodyLargeStyle.copyWith(
                  color: date != null
                      ? AuroraTheme.textPrimary
                      : AuroraTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
