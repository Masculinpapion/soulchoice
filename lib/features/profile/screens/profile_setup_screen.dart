import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart';
import '../providers/profile_provider.dart';
import '../../../shared/widgets/glass_card.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

// 7-step profile setup wizard
class ProfileSetupScreen extends ConsumerStatefulWidget {
  final bool isEditing;
  const ProfileSetupScreen({super.key, this.isEditing = false});

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
  String _showGender = 'opposite';
  int _minAge = 21;
  int _maxAge = 60;
  bool _isSaving = false;
  bool _isLoadingProfile = true;

  static const _stepCount = 9;
  static const _allInterestKeys = [
    'art', 'music', 'sports', 'books', 'travel', 'food',
    'film', 'theatre', 'dance', 'yoga', 'photography', 'games',
    'technology', 'nature', 'history', 'fashion',
  ];

  List<String> _getSteps(AppLocalizations l10n) => [
    l10n.profile_setup_step_name_age,
    l10n.profile_setup_step_gender,
    l10n.profile_setup_step_city,
    l10n.profile_setup_step_bio,
    l10n.profile_setup_step_job_edu,
    l10n.profile_setup_step_interests,
    l10n.profile_setup_step_prompts,
    l10n.profile_setup_step_show_gender,
    l10n.profile_setup_step_age_range,
  ];

  Map<String, String> _getPromptQuestions(AppLocalizations l10n) => {
    'favorite_restaurant': l10n.profile_setup_prompt_favorite_restaurant,
    'last_book': l10n.profile_setup_prompt_last_book(_gender ?? 'other'),
    'perfect_evening': l10n.profile_setup_prompt_perfect_evening,
    'travel_dream': l10n.profile_setup_prompt_travel_dream,
  };

  @override
  void initState() {
    super.initState();
    _loadExistingProfile();
  }

  Future<void> _loadExistingProfile() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoadingProfile = false);
      return;
    }
    try {
      final row = await client
          .from('users')
          .select('name, age, gender, city_id, bio, job, education, interests, show_gender, min_age, max_age, cities(name)')
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      if (row == null) {
        setState(() => _isLoadingProfile = false);
        return;
      }
      _nameController.text = row['name'] as String? ?? '';
      _bioController.text = row['bio'] as String? ?? '';
      _jobController.text = row['job'] as String? ?? '';
      _educationController.text = row['education'] as String? ?? '';

      final prompts = await client
          .from('user_prompts')
          .select('question_key, answer')
          .eq('user_id', user.id);
      if (!mounted) return;

      setState(() {
        _interests.clear();
        _age = row['age'] as int?;
        _gender = row['gender'] as String?;
        _cityId = row['city_id'] as String?;
        final interests = row['interests'];
        if (interests is List) _interests.addAll(interests.cast<String>());
        for (final p in prompts) {
          _prompts[p['question_key'] as String] = p['answer'] as String;
        }
        _showGender = row['show_gender'] as String? ?? 'opposite';
        _minAge = row['min_age'] as int? ?? 21;
        _maxAge = row['max_age'] as int? ?? 60;
        _isLoadingProfile = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoadingProfile = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _bioController.dispose();
    _jobController.dispose();
    _educationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    final l10n = AppLocalizations.of(context)!;
    if (_step == 0) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.profile_setup_validation_name),
          backgroundColor: AppColors.error,
        ));
        return;
      }
      if (_age == null ||
          _age! < AppConstants.minAge ||
          _age! > AppConstants.maxAge) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(l10n.profile_setup_validation_age(AppConstants.minAge, AppConstants.maxAge)),
          backgroundColor: AppColors.error,
        ));
        return;
      }
    }
    if (_step == 1 && (_gender == null || _gender!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.profile_setup_validation_gender),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    if (_step == 2 && (_cityId == null || _cityId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(l10n.profile_setup_validation_city),
        backgroundColor: AppColors.error,
      ));
      return;
    }
    if (_step < _stepCount - 1) {
      setState(() => _step++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      await _save();
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) {
        setState(() => _isSaving = false);
        return;
      }
      final uid = user.id;

      await client.from('users').upsert({
        'id': uid,
        'phone': user.phone,
        'name': _nameController.text.trim(),
        'age': _age,
        'gender': _gender,
        'city_id': _cityId,
        'bio': _bioController.text.trim().isEmpty ? null : _bioController.text.trim(),
        'job': _jobController.text.trim().isEmpty ? null : _jobController.text.trim(),
        'education': _educationController.text.trim().isEmpty ? null : _educationController.text.trim(),
        'interests': _interests.toList(),
        'show_gender': _showGender,
        'min_age': _minAge,
        'max_age': _maxAge,
      });

      if (_prompts.isNotEmpty) {
        await client.from('user_prompts').upsert(
          _prompts.entries
              .where((e) => e.value.trim().isNotEmpty)
              .map((e) => {'user_id': uid, 'question_key': e.key, 'answer': e.value.trim()})
              .toList(),
          onConflict: 'user_id,question_key',
        );
      }

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.profile_setup_error(e.toString())), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid != null) {
      ref.invalidate(userProfileProvider(uid));
      ref.invalidate(userPromptsProvider(uid));
    }
    if (mounted) {
      if (widget.isEditing) {
        context.pop();
      } else {
        context.go('/profile/photos');
      }
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
    final l10n = AppLocalizations.of(context)!;
    final steps = _getSteps(l10n);
    if (_isLoadingProfile) {
      return const Scaffold(
        backgroundColor: AppColors.bgBlack,
        body: Center(child: CircularProgressIndicator(color: AppColors.red)),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.bgBlack,
      resizeToAvoidBottomInset: true,
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
                              value: (_step + 1) / _stepCount,
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
                      '${_step + 1} / $_stepCount  •  ${steps[_step]}',
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
                      allInterests: _allInterestKeys,
                      selected: _interests,
                      onToggle: (v) => setState(() {
                        _interests.contains(v) ? _interests.remove(v) : _interests.add(v);
                      }),
                    ),
                    _StepPrompts(
                      questions: _getPromptQuestions(l10n),
                      answers: _prompts,
                      onAnswered: (k, v) => setState(() => _prompts[k] = v),
                    ),
                    _StepShowGender(
                      selected: _showGender,
                      onSelected: (v) => setState(() => _showGender = v),
                    ),
                    _StepAgeRange(
                      minAge: _minAge,
                      maxAge: _maxAge,
                      onChanged: (min, max) => setState(() { _minAge = min; _maxAge = max; }),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: ScButton(label: l10n.profile_setup_btn_next, onPressed: _isSaving ? null : _next, isLoading: _isSaving),
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context)!.profile_setup_name_question, style: AppTextStyles.displayMedium),
            const SizedBox(height: 32),
            TextField(
              controller: nameController,
              style: AppTextStyles.bodyLarge,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.profile_setup_name_label),
            ),
            const SizedBox(height: 20),
            TextFormField(
              keyboardType: TextInputType.number,
              style: AppTextStyles.bodyLarge,
              initialValue: age?.toString(),
              onChanged: (v) => onAgeChanged(int.tryParse(v)),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.profile_setup_age_label(AppConstants.minAge, AppConstants.maxAge),
              ),
            ),
          ],
        ),
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context)!.profile_setup_step_gender, style: AppTextStyles.displayMedium),
            const SizedBox(height: 40),
            _GenderOption(
              label: AppLocalizations.of(context)!.profile_setup_gender_female,
              icon: Icons.female,
              isSelected: selected == 'female',
              onTap: () => onSelected('female'),
            ),
            const SizedBox(height: 12),
            _GenderOption(
              label: AppLocalizations.of(context)!.profile_setup_gender_male,
              icon: Icons.male,
              isSelected: selected == 'male',
              onTap: () => onSelected('male'),
            ),
          ],
        ),
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

class _StepCity extends StatefulWidget {
  final String? selectedCityId;
  final ValueChanged<String> onSelected;

  const _StepCity({required this.selectedCityId, required this.onSelected});

  @override
  State<_StepCity> createState() => _StepCityState();
}

class _StepCityState extends State<_StepCity> {
  List<Map<String, dynamic>> _cities = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCities();
    _searchCtrl.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onSearch);
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    final data = await Supabase.instance.client
        .from('cities')
        .select('id, name')
        .eq('is_active', true)
        .order('name');
    if (!mounted) return;
    setState(() {
      _cities = List<Map<String, dynamic>>.from(data as List);
      _filtered = _cities;
      _loading = false;
    });
  }

  void _onSearch() {
    final q = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _cities
          : _cities.where((c) => (c['name'] as String).toLowerCase().contains(q)).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context)!.profile_setup_city_question, style: AppTextStyles.displayMedium),
            const SizedBox(height: 24),
            TextField(
              controller: _searchCtrl,
              style: AppTextStyles.bodyLarge,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.profile_setup_city_search,
                prefixIcon: const Icon(Icons.search, color: AppColors.textTertiary, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () => _searchCtrl.clear(),
                        child: const Icon(Icons.close, color: AppColors.textTertiary, size: 18),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.red))
            else if (_filtered.isEmpty)
              Center(child: Text(AppLocalizations.of(context)!.profile_setup_city_not_found, style: AppTextStyles.bodyMedium))
            else
              ..._filtered.map((c) {
                final name = c['name'] as String;
                final id = c['id'] as String;
                final isSelected = widget.selectedCityId == id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    borderColor: isSelected ? AppColors.red : AppColors.glassBorder,
                    onTap: () => widget.onSelected(id),
                    child: Row(
                      children: [
                        Text(name, style: AppTextStyles.bodyLarge),
                        const Spacer(),
                        if (isSelected)
                          const Icon(Icons.check_circle, color: AppColors.red, size: 20),
                      ],
                    ),
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }
}

class _StepBio extends StatelessWidget {
  final TextEditingController bioController;

  const _StepBio({required this.bioController});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context)!.profile_setup_bio_title, style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.profile_setup_bio_subtitle, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 32),
            TextField(
              controller: bioController,
              maxLength: AppConstants.maxBioLength,
              maxLines: 5,
              style: AppTextStyles.bodyLarge,
              decoration: InputDecoration(
                hintText: AppLocalizations.of(context)!.profile_setup_bio_hint,
                alignLabelWithHint: true,
              ),
            ),
          ],
        ),
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
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context)!.profile_setup_job_title, style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.profile_setup_step_job_edu, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 32),
            TextField(
              controller: jobController,
              style: AppTextStyles.bodyLarge,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.profile_setup_job_label),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: educationController,
              style: AppTextStyles.bodyLarge,
              decoration: InputDecoration(labelText: AppLocalizations.of(context)!.profile_setup_education_label),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepInterests extends StatelessWidget {
  final List<String> allInterests;
  final Set<String> selected;
  final ValueChanged<String> onToggle;

  const _StepInterests({required this.allInterests, required this.selected, required this.onToggle});

  String _label(String key, AppLocalizations l10n) {
    switch (key) {
      case 'art': return l10n.profile_setup_interest_art;
      case 'music': return l10n.profile_setup_interest_music;
      case 'sports': return l10n.profile_setup_interest_sports;
      case 'books': return l10n.profile_setup_interest_books;
      case 'travel': return l10n.profile_setup_interest_travel;
      case 'food': return l10n.profile_setup_interest_food;
      case 'film': return l10n.profile_setup_interest_film;
      case 'theatre': return l10n.profile_setup_interest_theatre;
      case 'dance': return l10n.profile_setup_interest_dance;
      case 'yoga': return l10n.profile_setup_interest_yoga;
      case 'photography': return l10n.profile_setup_interest_photography;
      case 'games': return l10n.profile_setup_interest_games;
      case 'technology': return l10n.profile_setup_interest_technology;
      case 'nature': return l10n.profile_setup_interest_nature;
      case 'history': return l10n.profile_setup_interest_history;
      case 'fashion': return l10n.profile_setup_interest_fashion;
      default: return key;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(l10n.profile_setup_interests_title, style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text(l10n.profile_setup_interests_subtitle, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 24),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: allInterests.map((interest) {
                final isSelected = selected.contains(interest);
                return FilterChip(
                  label: Text(_label(interest, l10n)),
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
      ),
    );
  }
}

class _StepShowGender extends StatelessWidget {
  final String selected;
  final ValueChanged<String> onSelected;

  const _StepShowGender({required this.selected, required this.onSelected});

  List<(String, String, IconData)> _getOptions(AppLocalizations l10n) => [
    ('opposite', l10n.profile_setup_show_gender_opposite, Icons.swap_horiz),
    ('all', l10n.profile_setup_show_gender_all, Icons.people_outline),
    ('female', l10n.profile_setup_show_gender_female, Icons.female),
    ('male', l10n.profile_setup_show_gender_male, Icons.male),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(l10n.profile_setup_show_gender_title, style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text(l10n.profile_setup_show_gender_subtitle, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 32),
            ..._getOptions(l10n).map((opt) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: GlassCard(
                    borderColor: selected == opt.$1 ? AppColors.red : AppColors.glassBorder,
                    onTap: () => onSelected(opt.$1),
                    child: Row(
                      children: [
                        Icon(opt.$3, color: selected == opt.$1 ? AppColors.red : AppColors.textSecondary, size: 26),
                        const SizedBox(width: 16),
                        Text(opt.$2, style: AppTextStyles.titleMedium),
                        const Spacer(),
                        if (selected == opt.$1)
                          const Icon(Icons.check_circle, color: AppColors.red, size: 22),
                      ],
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _StepAgeRange extends StatelessWidget {
  final int minAge;
  final int maxAge;
  final void Function(int min, int max) onChanged;

  const _StepAgeRange({required this.minAge, required this.maxAge, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(AppLocalizations.of(context)!.profile_setup_age_range_title, style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.profile_setup_age_range_subtitle, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 40),
            Center(
              child: Text(
                AppLocalizations.of(context)!.profile_setup_age_range_value(minAge, maxAge),
                style: AppTextStyles.titleMedium.copyWith(fontSize: 22),
              ),
            ),
            const SizedBox(height: 16),
            RangeSlider(
              values: RangeValues(minAge.toDouble(), maxAge.toDouble()),
              min: 21,
              max: 60,
              divisions: 39,
              activeColor: AppColors.red,
              inactiveColor: AppColors.glassBorder,
              labels: RangeLabels('$minAge', '$maxAge'),
              onChanged: (v) => onChanged(v.start.round(), v.end.round()),
            ),
          ],
        ),
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
            Text(AppLocalizations.of(context)!.profile_setup_prompts_title, style: AppTextStyles.displayMedium),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.profile_setup_prompts_subtitle, style: AppTextStyles.bodyMedium),
            const SizedBox(height: 32),
            ...questions.entries.map((e) => Padding(
                  padding: const EdgeInsets.only(bottom: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.value, style: AppTextStyles.labelLarge),
                      const SizedBox(height: 8),
                      TextFormField(
                        style: AppTextStyles.bodyLarge,
                        initialValue: answers[e.key] ?? '',
                        onChanged: (v) => onAnswered(e.key, v),
                        decoration: InputDecoration(hintText: AppLocalizations.of(context)!.profile_setup_prompts_answer_hint),
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
