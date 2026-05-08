import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../data/models/invitation_model.dart';
import '../../../features/feed/providers/invitations_provider.dart';
import '../../../features/invitation/providers/invitation_provider.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/sc_button.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

class CreateInvitationScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? editData;
  const CreateInvitationScreen({super.key, this.editData});

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

  static const _stepCount = 7;

  List<String> _getSteps(AppLocalizations l10n) => [
    l10n.create_inv_step_flow_type,
    l10n.create_inv_step_category,
    l10n.create_inv_step_title,
    l10n.create_inv_step_description,
    l10n.create_inv_step_venue,
    l10n.create_inv_step_datetime,
    l10n.create_inv_step_duration,
  ];

  @override
  void initState() {
    super.initState();
    final ed = widget.editData;
    if (ed != null) {
      _flowType = InvitationFlowType.values.firstWhere(
        (f) => f.name == ed['flow_type'],
        orElse: () => InvitationFlowType.invite,
      );
      _category = ed['category'] != null
          ? InvitationCategory.values.firstWhere(
              (c) => c.name == ed['category'],
              orElse: () => InvitationCategory.food,
            )
          : null;
      _titleController.text = ed['title'] as String? ?? '';
      _descriptionController.text = ed['description'] as String? ?? '';
      _venueController.text = ed['venue_name'] as String? ?? '';
      final rawDate = ed['event_date'] as String?;
      if (rawDate != null) _eventDate = DateTime.tryParse(rawDate);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  String? _validateCurrentStep(AppLocalizations l10n) {
    switch (_step) {
      case 1:
        if (_category == null) return l10n.create_inv_validation_category;
      case 2:
        if (_titleController.text.trim().isEmpty) return l10n.create_inv_validation_title;
      case 4:
        if (_venueController.text.trim().isEmpty) return l10n.create_inv_validation_venue;
      case 5:
        if (_eventDate == null) return l10n.create_inv_validation_date;
    }
    return null;
  }

  void _next() {
    final l10n = AppLocalizations.of(context)!;
    final error = _validateCurrentStep(l10n);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error,
              style: const TextStyle(fontFamily: 'Manrope', fontWeight: FontWeight.w600)),
          backgroundColor: AuroraTheme.auroraRed,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        ),
      );
      return;
    }
    if (_step < _stepCount - 1) {
      setState(() => _step++);
      _pageController.nextPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic);
    } else {
      _publish();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.previousPage(
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeInOutCubic);
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
    final isEdit = widget.editData != null;
    try {
      final client = Supabase.instance.client;
      final venueFormatted = _venueController.text.trim().isEmpty
          ? null
          : _venueController.text.trim().split(' ')
              .where((w) => w.isNotEmpty)
              .map((w) => w[0].toUpperCase() + w.substring(1))
              .join(' ');

      if (isEdit) {
        final editId = widget.editData!['id'] as String;
        await client.from('invitations').update({
          'flow_type': _flowType.name,
          'category': _category?.name ?? InvitationCategory.food.name,
          'title': _fixCase(_titleController.text),
          'description': _descriptionController.text.trim().isEmpty
              ? null
              : _fixCase(_descriptionController.text),
          'venue_name': venueFormatted,
          'event_date': _eventDate?.toIso8601String(),
        }).eq('id', editId);

        if (mounted) {
          ref.invalidate(invitationDetailProvider(editId));
          ref.invalidate(invitationsProvider);
          context.go('/invitation/$editId');
        }
      } else {
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
          'event_date': _eventDate?.toIso8601String(),
          'expires_at': DateTime.now().toUtc().add(Duration(hours: _expiryHours)).toIso8601String(),
          'city_id': cityId,
          'slots_total': 1,
          'status': 'active',
        });

        if (mounted) {
          ref.invalidate(invitationsProvider);
          context.go('/feed');
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(AppLocalizations.of(context)!.create_inv_error_publish(e.toString())),
              backgroundColor: AppColors.error),
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
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
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
                      icon: const Icon(Icons.arrow_back_ios_new,
                          color: AppColors.textPrimary, size: 20),
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
                    _StepDots(
                        total: _stepCount, current: _step),
                    const SizedBox(width: 10),
                    Text(
                      steps[_step],
                      style: AppTextStyles.monoSmall.copyWith(
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              // ── Page content ──────────────────────────────────────────
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StepFlowType(
                        selected: _flowType,
                        onSelected: (v) =>
                            setState(() => _flowType = v)),
                    _StepCategory(
                        selected: _category,
                        onSelected: (v) =>
                            setState(() => _category = v)),
                    _StepTitle(controller: _titleController),
                    _StepDescription(
                        controller: _descriptionController,
                        flowType: _flowType),
                    _StepVenue(controller: _venueController),
                    _StepDateTime(
                        date: _eventDate,
                        onSelected: (d) =>
                            setState(() => _eventDate = d)),
                    _StepDuration(
                        selected: _expiryHours,
                        onSelected: (h) =>
                            setState(() => _expiryHours = h)),
                  ],
                ),
              ),
              // ── Footer CTA ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: ScButton(
                  label: _step < _stepCount - 1
                      ? l10n.create_inv_btn_next
                      : (widget.editData != null
                          ? l10n.create_inv_btn_update
                          : l10n.create_inv_btn_publish),
                  onPressed: _isPublishing ? null : _next,
                  isLoading:
                      _isPublishing && _step == _stepCount - 1,
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
          color: AppColors.glassBorder,
          borderRadius: BorderRadius.circular(4),
        ),
        child: FractionallySizedBox(
          widthFactor: value,
          alignment: Alignment.centerLeft,
          child: Container(
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
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
              gradient: (isActive || isPast)
                  ? AppColors.primaryGradient
                  : null,
              color: (isActive || isPast)
                  ? null
                  : AppColors.glassBorderBright,
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(AppLocalizations.of(context)!.create_inv_flow_question,
              style: AppTextStyles.displayMedium),
          const SizedBox(height: 40),
          _FlowTypeCard(
            title: AppLocalizations.of(context)!.create_inv_flow_invite_title,
            subtitle: AppLocalizations.of(context)!.create_inv_flow_invite_subtitle,
            icon: Icons.wine_bar_rounded,
            gradientColors: const [Color(0xFFFF2D55), Color(0xFF8B5CF6)],
            isSelected: selected == InvitationFlowType.invite,
            onTap: () => onSelected(InvitationFlowType.invite),
          ),
          const SizedBox(height: 14),
          _FlowTypeCard(
            title: AppLocalizations.of(context)!.create_inv_flow_request_title,
            subtitle: AppLocalizations.of(context)!.create_inv_flow_request_subtitle,
            icon: Icons.explore_rounded,
            gradientColors: const [Color(0xFF2D7FFF), Color(0xFF8B5CF6)],
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
                ? AppColors.gradientStart.withOpacity(0.08)
                : AppColors.glassBgMedium,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected
                  ? AppColors.gradientStart
                  : AppColors.glassBorder,
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
                    Text(title, style: AppTextStyles.titleMedium),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(subtitle, style: AppTextStyles.bodyMedium),
                    ],
                  ],
                ),
              ),
              if (isSelected)
                ShaderMask(
                  shaderCallback: (b) =>
                      AppColors.primaryGradient.createShader(b),
                  child: const Icon(Icons.check_circle,
                      color: Colors.white, size: 22),
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
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(AppLocalizations.of(context)!.create_inv_step_category, style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text(AppLocalizations.of(context)!.create_inv_category_question,
              style: AppTextStyles.bodyMedium),
          const SizedBox(height: 32),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: InvitationCategory.values.map((c) {
              final isSelected = selected == c;
              return GestureDetector(
                onTap: () => onSelected(c),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? AppColors.primaryGradient
                        : null,
                    color: isSelected
                        ? null
                        : AppColors.glassBgMedium,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected
                          ? Colors.transparent
                          : AppColors.glassBorder,
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      c == InvitationCategory.bar
                          ? Image.asset('assets/icons/bar.png', width: 28, height: 28)
                          : Text(
                              c.emoji,
                              style: TextStyle(
                                fontSize: c == InvitationCategory.concert ? 34 : 28,
                                color: c == InvitationCategory.concert ? AuroraTheme.auroraRed : null,
                              ),
                            ),
                      const SizedBox(height: 6),
                      Text(
                        c.labelFor(AppLocalizations.of(context)!),
                        style: AppTextStyles.labelMedium.copyWith(
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context)!.create_inv_step_title, style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.create_inv_title_subtitle,
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: controller,
              maxLength: 60,
              style: AppTextStyles.feedCardTitle.copyWith(fontSize: 20),
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.create_inv_title_label),
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
  const _StepDescription({required this.controller, required this.flowType});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final subtitle = flowType == InvitationFlowType.invite
        ? l10n.create_inv_desc_invite_hint
        : l10n.create_inv_desc_request_hint;
    return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(l10n.create_inv_step_description, style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text(subtitle, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 32),
            TextField(
              controller: controller,
              maxLines: 4,
              maxLength: 300,
              style: AppTextStyles.bodyLarge,
              decoration: InputDecoration(
                hintText: l10n.create_inv_desc_input_hint,
                alignLabelWithHint: true,
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
  const _StepVenue({required this.controller});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context)!.create_inv_venue_question, style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.create_inv_venue_subtitle,
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: 32),
            TextField(
              controller: controller,
              style: AppTextStyles.bodyLarge,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.create_inv_venue_label,
                hintText: AppLocalizations.of(context)!.create_inv_venue_placeholder,
                prefixIcon: Icon(Icons.location_on_outlined,
                    color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      );
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
    return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(l10n.create_inv_duration_question, style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text(l10n.create_inv_duration_subtitle, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 32),
            ..._options(l10n).map((opt) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GestureDetector(
                    onTap: () => onSelected(opt.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                      decoration: BoxDecoration(
                        gradient: selected == opt.$1 ? AppColors.primaryGradient : null,
                        color: selected == opt.$1 ? null : AppColors.glassBgMedium,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected == opt.$1 ? Colors.transparent : AppColors.glassBorder,
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(opt.$2, style: AppTextStyles.titleMedium),
                                const SizedBox(height: 2),
                                Text(
                                  opt.$3,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: selected == opt.$1
                                        ? AppColors.textPrimary.withOpacity(0.75)
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (selected == opt.$1)
                            ShaderMask(
                              shaderCallback: (b) =>
                                  selected == opt.$1 ? const LinearGradient(colors: [Colors.white, Colors.white]).createShader(b) : AppColors.primaryGradient.createShader(b),
                              child: const Icon(Icons.check_circle, color: Colors.white, size: 22),
                            ),
                        ],
                      ),
                    ),
                  ),
                )),
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
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context)!.create_inv_datetime_question, style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.create_inv_datetime_subtitle,
                style: AppTextStyles.bodyMedium),
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
                  initialTime:
                      TimeOfDay(hour: (now.hour + 2) % 24, minute: 0),
                );
                if (pickedTime == null) return;
                onSelected(DateTime(
                  pickedDate.year,
                  pickedDate.month,
                  pickedDate.day,
                  pickedTime.hour,
                  pickedTime.minute,
                ));
              },
              child: Row(
                children: [
                  ShaderMask(
                    shaderCallback: (b) =>
                        AppColors.primaryGradient.createShader(b),
                    child: const Icon(Icons.calendar_today_outlined,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    date != null ? _format(date!) : AppLocalizations.of(context)!.create_inv_datetime_placeholder,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: date != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

