import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/invitation_model.dart';
import '../../../features/feed/providers/invitations_provider.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/sc_button.dart';

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
  int _slots = 1;
  bool _isPublishing = false;

  static const _steps = [
    'Davet tipi',
    'Kategori',
    'Başlık',
    'Açıklama',
    'Yer',
    'Tarih & Saat',
    'Kaç kişi',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < _steps.length - 1) {
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

  Future<void> _publish() async {
    setState(() => _isPublishing = true);
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser!.id;

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
        'title': _titleController.text.trim(),
        'description': _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        'venue_name': _venueController.text.trim().isEmpty
            ? null
            : _venueController.text.trim(),
        'event_date': _eventDate?.toIso8601String(),
        'city_id': cityId,
        'slots_total': _slots,
        'status': 'active',
      });

      if (mounted) {
        ref.invalidate(invitationsProvider);
        context.go('/feed');
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
      if (mounted) setState(() => _isPublishing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
                        value: (_step + 1) / _steps.length,
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
                        total: _steps.length, current: _step),
                    const SizedBox(width: 10),
                    Text(
                      _steps[_step],
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
                    _StepDescription(controller: _descriptionController),
                    _StepVenue(controller: _venueController),
                    _StepDateTime(
                        date: _eventDate,
                        onSelected: (d) =>
                            setState(() => _eventDate = d)),
                    _StepSlots(
                        slots: _slots,
                        onChanged: (v) =>
                            setState(() => _slots = v)),
                  ],
                ),
              ),
              // ── Footer CTA ────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
                child: ScButton(
                  label:
                      _step < _steps.length - 1 ? 'Devam' : 'Yayınla',
                  onPressed: _isPublishing ? null : _next,
                  isLoading:
                      _isPublishing && _step == _steps.length - 1,
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
          Text('Ne açmak istiyorsun?',
              style: AppTextStyles.displayMedium),
          const SizedBox(height: 40),
          _FlowTypeCard(
            title: 'Ismarlıyorum',
            subtitle: 'Birini de götürmek istiyorum, masraf benden',
            icon: '🥂',
            isSelected: selected == InvitationFlowType.invite,
            onTap: () => onSelected(InvitationFlowType.invite),
          ),
          const SizedBox(height: 14),
          _FlowTypeCard(
            title: 'İstiyorum',
            subtitle: 'Gitmek istediğim bir yer var, birlikte gelen olsun',
            icon: '✨',
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
  final String icon;
  final bool isSelected;
  final VoidCallback onTap;
  const _FlowTypeCard({
    required this.title,
    required this.subtitle,
    required this.icon,
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
              Text(icon, style: const TextStyle(fontSize: 32)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTextStyles.bodyMedium),
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
          Text('Kategori', style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text('Hangi deneyimi paylaşıyorsunuz?',
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
                      Text(c.emoji,
                          style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 6),
                      Text(
                        c.label,
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
            Text('Başlık', style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text(
              'Kısa ve çarpıcı — feed\'de büyük görünecek',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 32),
            TextField(
              controller: controller,
              maxLength: 60,
              style: AppTextStyles.feedCardTitle.copyWith(fontSize: 20),
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'BAŞLIK'),
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
  const _StepDescription({required this.controller});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('Açıklama', style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text('Ne yapacaksınız? Kim arıyorsunuz?',
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: 32),
            TextField(
              controller: controller,
              maxLines: 5,
              maxLength: 300,
              style: AppTextStyles.bodyLarge,
              decoration: const InputDecoration(
                hintText: 'Detayları yaz...',
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
      );
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
            Text('Nerede?', style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text('Mekan adı veya adres', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 32),
            TextField(
              controller: controller,
              style: AppTextStyles.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Mekan adı',
                prefixIcon: Icon(Icons.location_on_outlined,
                    color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      );
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
            Text('Ne zaman?', style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text('Etkinlik tarih ve saatini seçin',
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
                    date != null ? _format(date!) : 'Tarih & saat seç',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: date != null
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (date != null) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0x12E63946),
                      Color(0x084A90E2),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppColors.gradientStart.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: AppColors.gradientEnd, size: 18),
                    const SizedBox(width: 10),
                    Text(_format(date!),
                        style: AppTextStyles.mono.copyWith(
                            color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Step: Slots
// ─────────────────────────────────────────────────────────────────────────────

class _StepSlots extends StatelessWidget {
  final int slots;
  final ValueChanged<int> onChanged;

  const _StepSlots({required this.slots, required this.onChanged});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('Kaç kişi?', style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text('Kaç kişilik bir deneyim?',
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [1, 2].map((n) {
                final isSelected = slots == n;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: GestureDetector(
                    onTap: () => onChanged(n),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? AppColors.primaryGradient
                            : null,
                        color: isSelected ? null : AppColors.glassBgMedium,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: isSelected
                              ? Colors.transparent
                              : AppColors.glassBorder,
                          width: isSelected ? 0 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.gradientStart
                                      .withOpacity(0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 6),
                                )
                              ]
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$n',
                            style: AppTextStyles.monoLarge.copyWith(
                              color: AppColors.textPrimary,
                            ),
                          ),
                          Text('kişi',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: isSelected
                                      ? AppColors.textPrimary.withOpacity(0.8)
                                      : AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      );
}
