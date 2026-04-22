import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart';
import '../../../shared/widgets/glass_card.dart';

// 7-step profile setup wizard
class ProfileSetupScreen extends ConsumerStatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  ConsumerState<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends ConsumerState<ProfileSetupScreen> {
  int _step = 0;
  final _pageController = PageController();

  // Form state
  final _nameController = TextEditingController();
  int? _age;
  String? _gender;
  String? _cityId;
  final _bioController = TextEditingController();
  final _jobController = TextEditingController();
  final _educationController = TextEditingController();
  final Set<String> _interests = {};
  final Map<String, String> _prompts = {};

  static const _steps = [
    'Ad ve yaş',
    'Cinsiyet',
    'Şehir',
    'Bio',
    'İş / Eğitim',
    'İlgi alanları',
    'Sorular',
  ];

  static const _allInterests = [
    'Sanat', 'Müzik', 'Spor', 'Kitaplar', 'Seyahat', 'Yemek',
    'Film', 'Tiyatro', 'Dans', 'Yoga', 'Fotoğrafçılık', 'Oyunlar',
    'Teknoloji', 'Doğa', 'Tarih', 'Moda',
  ];

  static const _promptQuestions = {
    'favorite_restaurant': 'Favori restoranım...',
    'last_book': 'Son okuduğum kitap...',
    'perfect_evening': 'Mükemmel bir akşam...',
    'travel_dream': 'Hayalimdeki seyahat...',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _jobController.dispose();
    _educationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  void _next() {
    if (_step < _steps.length - 1) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      context.go('/profile/photos');
    }
  }

  void _back() {
    if (_step > 0) {
      setState(() => _step--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
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
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        if (_step > 0)
                          IconButton(
                            icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.textPrimary),
                            onPressed: _back,
                          )
                        else
                          const SizedBox(width: 48),
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
                        const SizedBox(width: 48),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_step + 1} / ${_steps.length}  •  ${_steps[_step]}',
                      style: AppTextStyles.monoSmall,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _StepNameAge(
                      nameController: _nameController,
                      age: _age,
                      onAgeChanged: (v) => setState(() => _age = v),
                    ),
                    _StepGender(
                      selected: _gender,
                      onSelected: (v) => setState(() => _gender = v),
                    ),
                    _StepCity(
                      selectedCityId: _cityId,
                      onSelected: (v) => setState(() => _cityId = v),
                    ),
                    _StepBio(bioController: _bioController),
                    _StepJobEducation(
                      jobController: _jobController,
                      educationController: _educationController,
                    ),
                    _StepInterests(
                      allInterests: _allInterests,
                      selected: _interests,
                      onToggle: (v) => setState(() {
                        _interests.contains(v) ? _interests.remove(v) : _interests.add(v);
                      }),
                    ),
                    _StepPrompts(
                      questions: _promptQuestions,
                      answers: _prompts,
                      onAnswered: (k, v) => setState(() => _prompts[k] = v),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: ScButton(label: _step < _steps.length - 1 ? 'Devam' : 'Fotoğraf ekle', onPressed: _next),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StepNameAge extends StatelessWidget {
  final TextEditingController nameController;
  final int? age;
  final ValueChanged<int?> onAgeChanged;

  const _StepNameAge({required this.nameController, required this.age, required this.onAgeChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text('Adın ne?', style: AppTextStyles.displayMedium),
          const SizedBox(height: 32),
          TextField(
            controller: nameController,
            style: AppTextStyles.bodyLarge,
            decoration: const InputDecoration(labelText: 'Ad'),
          ),
          const SizedBox(height: 20),
          TextField(
            keyboardType: TextInputType.number,
            style: AppTextStyles.bodyLarge,
            onChanged: (v) => onAgeChanged(int.tryParse(v)),
            decoration: InputDecoration(
              labelText: 'Yaş (${AppConstants.minAge}-${AppConstants.maxAge})',
            ),
          ),
        ],
      ),
    );
  }
}

class _StepGender extends StatelessWidget {
  final String? selected;
  final ValueChanged<String> onSelected;

  const _StepGender({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text('Cinsiyet', style: AppTextStyles.displayMedium),
          const SizedBox(height: 40),
          _GenderOption(
            label: 'Kadın',
            icon: Icons.female,
            isSelected: selected == 'female',
            onTap: () => onSelected('female'),
          ),
          const SizedBox(height: 12),
          _GenderOption(
            label: 'Erkek',
            icon: Icons.male,
            isSelected: selected == 'male',
            onTap: () => onSelected('male'),
          ),
        ],
      ),
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderOption({required this.label, required this.icon, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: isSelected ? AppColors.red : AppColors.glassBorder,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, color: isSelected ? AppColors.red : AppColors.textSecondary, size: 28),
          const SizedBox(width: 16),
          Text(label, style: AppTextStyles.titleMedium),
          const Spacer(),
          if (isSelected)
            const Icon(Icons.check_circle, color: AppColors.red, size: 22),
        ],
      ),
    );
  }
}

class _StepCity extends StatelessWidget {
  final String? selectedCityId;
  final ValueChanged<String> onSelected;

  const _StepCity({required this.selectedCityId, required this.onSelected});

  static const _cities = [
    ('moscow', '🇷🇺 Moskova'),
    ('istanbul', '🇹🇷 İstanbul'),
    ('london', '🇬🇧 Londra'),
    ('dubai', '🇦🇪 Dubai'),
    ('berlin', '🇩🇪 Berlin'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text('Hangi şehirdesin?', style: AppTextStyles.displayMedium),
          const SizedBox(height: 32),
          ..._cities.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GlassCard(
                  borderColor: selectedCityId == c.$1 ? AppColors.red : AppColors.glassBorder,
                  onTap: () => onSelected(c.$1),
                  child: Row(
                    children: [
                      Text(c.$2, style: AppTextStyles.bodyLarge),
                      const Spacer(),
                      if (selectedCityId == c.$1)
                        const Icon(Icons.check_circle, color: AppColors.red, size: 20),
                    ],
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class _StepBio extends StatelessWidget {
  final TextEditingController bioController;

  const _StepBio({required this.bioController});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text('Kendini anlat', style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text('Opsiyonel — max 200 karakter', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 32),
          TextField(
            controller: bioController,
            maxLength: AppConstants.maxBioLength,
            maxLines: 5,
            style: AppTextStyles.bodyLarge,
            decoration: const InputDecoration(
              hintText: 'Kısaca kendini tanıt...',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }
}

class _StepJobEducation extends StatelessWidget {
  final TextEditingController jobController;
  final TextEditingController educationController;

  const _StepJobEducation({required this.jobController, required this.educationController});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text('İş & Eğitim', style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text('Opsiyonel', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 32),
          TextField(
            controller: jobController,
            style: AppTextStyles.bodyLarge,
            decoration: const InputDecoration(labelText: 'Meslek'),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: educationController,
            style: AppTextStyles.bodyLarge,
            decoration: const InputDecoration(labelText: 'Okul / Üniversite'),
          ),
        ],
      ),
    );
  }
}

class _StepInterests extends StatelessWidget {
  final List<String> allInterests;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _StepInterests({required this.allInterests, required this.selected, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text('İlgi alanları', style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text('En az 3 seç', style: AppTextStyles.bodyMedium),
          const SizedBox(height: 24),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: allInterests.map((interest) {
              final isSelected = selected.contains(interest);
              return FilterChip(
                label: Text(interest),
                selected: isSelected,
                onSelected: (_) => onToggle(interest),
                backgroundColor: AppColors.glassBg,
                selectedColor: AppColors.red.withOpacity(0.2),
                checkmarkColor: AppColors.red,
                side: BorderSide(
                  color: isSelected ? AppColors.red : AppColors.glassBorder,
                ),
                labelStyle: AppTextStyles.labelMedium.copyWith(
                  color: isSelected ? AppColors.red : AppColors.textSecondary,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _StepPrompts extends StatelessWidget {
  final Map<String, String> questions;
  final Map<String, String> answers;
  final void Function(String key, String val) onAnswered;

  const _StepPrompts({required this.questions, required this.answers, required this.onAnswered});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text('Birkaç soru', style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text('Opsiyonel — profilini zenginleştirir', style: AppTextStyles.bodyMedium),
            const SizedBox(height: 32),
            ...questions.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.value, style: AppTextStyles.labelLarge),
                      const SizedBox(height: 8),
                      TextField(
                        style: AppTextStyles.bodyLarge,
                        onChanged: (v) => onAnswered(e.key, v),
                        decoration: const InputDecoration(hintText: 'Cevabın...'),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
