import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../data/models/invitation_model.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/sc_button.dart';

class CreateInvitationScreen extends StatefulWidget {
  const CreateInvitationScreen({super.key});

  @override
  State<CreateInvitationScreen> createState() => _CreateInvitationScreenState();
}

class _CreateInvitationScreenState extends State<CreateInvitationScreen> {
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
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _publish();
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      context.pop();
    }
  }

  Future<void> _publish() async {
    // TODO: save to Supabase
    if (mounted) {
      context.go('/feed');
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
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 24, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
                      onPressed: _back,
                    ),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (_step + 1) / _steps.length,
                          backgroundColor: AppColors.glassBorder,
                          color: AppColors.red,
                          minHeight: 3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  '${_step + 1} / ${_steps.length}  •  ${_steps[_step]}',
                  style: AppTextStyles.monoSmall,
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StepFlowType(selected: _flowType, onSelected: (v) => setState(() => _flowType = v)),
                    _StepCategory(selected: _category, onSelected: (v) => setState(() => _category = v)),
                    _StepTitle(controller: _titleController),
                    _StepDescription(controller: _descriptionController),
                    _StepVenue(controller: _venueController),
                    _StepDateTime(date: _eventDate, onSelected: (d) => setState(() => _eventDate = d)),
                    _StepSlots(slots: _slots, onChanged: (v) => setState(() => _slots = v)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: ScButton(
                  label: _step < _steps.length - 1 ? 'Devam' : 'Yayınla',
                  onPressed: _next,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
          Text('Ne açmak istiyorsun?', style: AppTextStyles.displayMedium),
          const SizedBox(height: 40),
          GlassCard(
            borderColor: selected == InvitationFlowType.invite ? AppColors.red : AppColors.glassBorder,
            onTap: () => onSelected(InvitationFlowType.invite),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('Ismarlıyorum', style: AppTextStyles.titleMedium),
                  const Spacer(),
                  if (selected == InvitationFlowType.invite)
                    const Icon(Icons.check_circle, color: AppColors.red),
                ]),
                const SizedBox(height: 4),
                Text('Birini de götürmek istiyorum, masraf benden', style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            borderColor: selected == InvitationFlowType.request ? AppColors.blue : AppColors.glassBorder,
            onTap: () => onSelected(InvitationFlowType.request),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Text('İstiyorum', style: AppTextStyles.titleMedium),
                  const Spacer(),
                  if (selected == InvitationFlowType.request)
                    const Icon(Icons.check_circle, color: AppColors.blue),
                ]),
                const SizedBox(height: 4),
                Text('Birinin beni götürmesini istiyorum', style: AppTextStyles.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

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
          const SizedBox(height: 32),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: InvitationCategory.values.map((c) {
              final isSelected = selected == c;
              return GestureDetector(
                onTap: () => onSelected(c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.red.withOpacity(0.15) : AppColors.glassBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: isSelected ? AppColors.red : AppColors.glassBorder),
                  ),
                  child: Column(
                    children: [
                      Text(c.emoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(height: 4),
                      Text(c.label, style: AppTextStyles.labelMedium.copyWith(
                        color: isSelected ? AppColors.red : AppColors.textSecondary,
                      )),
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
            Text('Kısa ve çarpıcı — feed\'de büyük görünecek', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 32),
            TextField(
              controller: controller,
              maxLength: 60,
              style: AppTextStyles.feedCardTitle.copyWith(fontSize: 18),
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'BAŞLIK'),
            ),
          ],
        ),
      );
}

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
            Text('Ne yapacaksınız? Kim arıyorsunuz?', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 32),
            TextField(
              controller: controller,
              maxLines: 5,
              maxLength: 300,
              style: AppTextStyles.bodyLarge,
              decoration: const InputDecoration(hintText: 'Detayları yaz...', alignLabelWithHint: true),
            ),
          ],
        ),
      );
}

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
            const SizedBox(height: 32),
            TextField(
              controller: controller,
              style: AppTextStyles.bodyLarge,
              decoration: const InputDecoration(
                labelText: 'Mekan adı',
                prefixIcon: Icon(Icons.location_on_outlined, color: AppColors.textTertiary),
              ),
            ),
          ],
        ),
      );
}

class _StepDateTime extends StatelessWidget {
  final DateTime? date;
  final ValueChanged<DateTime> onSelected;

  const _StepDateTime({required this.date, required this.onSelected});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('Ne zaman?', style: AppTextStyles.displayMedium),
            const SizedBox(height: 32),
            GlassCard(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(hours: 2)),
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(hours: 24)),
                );
                if (picked != null) onSelected(picked);
              },
              child: Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, color: AppColors.textSecondary),
                  const SizedBox(width: 14),
                  Text(
                    date != null
                        ? '${date!.day}.${date!.month}.${date!.year} ${date!.hour}:00'
                        : 'Tarih seç',
                    style: AppTextStyles.bodyLarge,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

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
            const SizedBox(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [1, 2].map((n) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: GestureDetector(
                      onTap: () => onChanged(n),
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: slots == n ? AppColors.red.withOpacity(0.15) : AppColors.glassBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: slots == n ? AppColors.red : AppColors.glassBorder, width: 1.5),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('$n', style: AppTextStyles.monoLarge.copyWith(color: slots == n ? AppColors.red : AppColors.textPrimary)),
                            Text('kişi', style: AppTextStyles.bodyMedium),
                          ],
                        ),
                      ),
                    ),
                  )).toList(),
            ),
          ],
        ),
      );
}
