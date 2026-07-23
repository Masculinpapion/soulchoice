import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/sc_button.dart';
import '../../../shared/widgets/sc_scaffold.dart';
import '../providers/profile_provider.dart';
import '../../../shared/widgets/glass_card.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

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
  // Seçenek B (09.07.2026): opsiyonel e-posta + ayrı pazarlama rızası (ФЗ-38)
  final _emailController = TextEditingController();
  bool _marketingConsent = false;
  final Set<String> _interests = {};
  final Map<String, String> _prompts = {};
  int _minAge = 21;
  int _maxAge = 60;
  bool _isSaving = false;
  bool _isLoadingProfile = true;

  // 152-ФЗ: kayıt tamamlanmadan önce üç ayrı aktif onay gerekiyor —
  // mevcut pasif "devam ederek kabul edersin" metni (phone_screen) tek
  // başına yeterli değil. Onay anı + hangi metin sürümüne onay verildiği
  // audit için users.consent_given_at / consent_version'a yazılıyor.
  bool _ageConfirmed = false;
  bool _dataConsent = false;
  bool _profileVisibilityConsent = false;
  static const _consentVersion = '2026-07-08';

  static const _stepCount = 9;
  static const _allInterestKeys = [
    'art',
    'music',
    'sports',
    'books',
    'travel',
    'food',
    'film',
    'theatre',
    'dance',
    'yoga',
    'photography',
    'games',
    'technology',
    'nature',
    'history',
    'fashion',
  ];

  List<String> _getSteps(AppLocalizations l10n) => [
    l10n.profile_setup_step_name_age,
    l10n.profile_setup_step_gender,
    l10n.profile_setup_step_city,
    l10n.profile_setup_step_bio,
    l10n.profile_setup_step_job_edu,
    l10n.profile_setup_step_interests,
    l10n.profile_setup_step_prompts,
    l10n.profile_setup_step_age_range,
    l10n.profile_setup_step_consent,
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
          .select(
            'name, age, gender, city_id, bio, job, education, interests, min_age, max_age, billing_email, cities(name, name_ru, name_tr, name_en)',
          )
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
      _emailController.text = row['billing_email'] as String? ?? '';

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
    _emailController.dispose();
    _jobController.dispose();
    _educationController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  // Son adımda (Onaylar) üç aktif onay işaretlenmeden buton pasif kalır.
  bool get _canProceed =>
      _step != _stepCount - 1 ||
      (_ageConfirmed && _dataConsent && _profileVisibilityConsent);

  Future<void> _next() async {
    final l10n = AppLocalizations.of(context)!;
    if (_step == 0) {
      if (_nameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.profile_setup_validation_name),
            backgroundColor: AuroraTheme.auroraRed,
          ),
        );
        return;
      }
      if (_age == null ||
          _age! < AppConstants.minAge ||
          _age! > AppConstants.maxAge) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.profile_setup_validation_age(
                AppConstants.minAge,
                AppConstants.maxAge,
              ),
            ),
            backgroundColor: AuroraTheme.auroraRed,
          ),
        );
        return;
      }
    }
    if (_step == 1 && (_gender == null || _gender!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profile_setup_validation_gender),
          backgroundColor: AuroraTheme.auroraRed,
        ),
      );
      return;
    }
    if (_step == 2 && (_cityId == null || _cityId!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.profile_setup_validation_city),
          backgroundColor: AuroraTheme.auroraRed,
        ),
      );
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
        'bio': _bioController.text.trim().isEmpty
            ? null
            : _bioController.text.trim(),
        'job': _jobController.text.trim().isEmpty
            ? null
            : _jobController.text.trim(),
        'education': _educationController.text.trim().isEmpty
            ? null
            : _educationController.text.trim(),
        'interests': _interests.toList(),
        'min_age': _minAge,
        'max_age': _maxAge,
        'consent_given_at': DateTime.now().toUtc().toIso8601String(),
        'consent_version': _consentVersion,
      });

      // E-posta + pazarlama rızası: profil kaydını bloklamayan yan işlem;
      // D+0 hoş geldin mailini ve consent logunu save-billing-email fn yapar
      final email = _emailController.text.trim();
      if (RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
        try {
          await client.functions.invoke('save-billing-email', body: {
            'email': email,
            'marketing_consent': _marketingConsent,
            'source': 'app_onboarding',
          });
        } catch (_) {
          // sessiz: e-posta kaydı profili engellemez, cron/lifecycle telafi etmez ama
          // kullanıcı profil düzenlemeden tekrar deneyebilir
        }
      }

      if (_prompts.isNotEmpty) {
        await client
            .from('user_prompts')
            .upsert(
              _prompts.entries
                  .where((e) => e.value.trim().isNotEmpty)
                  .map(
                    (e) => {
                      'user_id': uid,
                      'question_key': e.key,
                      'answer': e.value.trim(),
                    },
                  )
                  .toList(),
              onConflict: 'user_id,question_key',
            );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.profile_setup_error(AppLocalizations.of(context)!.error_generic),
            ),
            backgroundColor: AuroraTheme.auroraRed,
          ),
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
      context.go('/permissions');
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
      return ScScaffold(
        backgroundColor: AuroraTheme.bgDeep,
        body: const Center(
          child: CircularProgressIndicator(color: AuroraTheme.auroraRed),
        ),
      );
    }
    return ScScaffold(
      backgroundColor: AuroraTheme.bgDeep,
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
                            icon: const Icon(
                              Icons.arrow_back_ios_new,
                              color: AuroraTheme.textPrimary,
                            ),
                            onPressed: _back,
                          )
                        else
                          const SizedBox(width: 48),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: (_step + 1) / _stepCount,
                              backgroundColor: AuroraTheme.glassBorder,
                              color: AuroraTheme.auroraRed,
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
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        letterSpacing: 0.25,
                        color: AuroraTheme.textMuted,
                      ),
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
                        _interests.contains(v)
                            ? _interests.remove(v)
                            : _interests.add(v);
                      }),
                    ),
                    _StepPrompts(
                      questions: _getPromptQuestions(l10n),
                      answers: _prompts,
                      onAnswered: (k, v) => setState(() => _prompts[k] = v),
                    ),
                    _StepAgeRange(
                      minAge: _minAge,
                      maxAge: _maxAge,
                      onChanged: (min, max) => setState(() {
                        _minAge = min;
                        _maxAge = max;
                      }),
                    ),
                    _StepConsent(
                      ageConfirmed: _ageConfirmed,
                      dataConsent: _dataConsent,
                      profileVisibilityConsent: _profileVisibilityConsent,
                      onAgeChanged: (v) => setState(() => _ageConfirmed = v),
                      onDataConsentChanged: (v) =>
                          setState(() => _dataConsent = v),
                      onProfileVisibilityChanged: (v) =>
                          setState(() => _profileVisibilityConsent = v),
                      emailController: _emailController,
                      marketingConsent: _marketingConsent,
                      onMarketingConsentChanged: (v) =>
                          setState(() => _marketingConsent = v),
                    ),
                  ],
                ),
              ),
              Padding(
                // Üst 12px: klavye açıkken buton içeriğe yapışmasın (13.07,
                // davet sihirbazıyla aynı desen).
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: ScButton(
                  label: l10n.profile_setup_btn_next,
                  onPressed: (_isSaving || !_canProceed) ? null : _next,
                  isLoading: _isSaving,
                ),
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

  const _StepNameAge({
    required this.nameController,
    required this.age,
    required this.onAgeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.profile_setup_name_question,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
                fontSize: 32,
                color: AuroraTheme.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: nameController,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                color: AuroraTheme.textPrimary,
                height: 1.6,
              ),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                )!.profile_setup_name_label,
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              keyboardType: TextInputType.number,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                color: AuroraTheme.textPrimary,
                height: 1.6,
              ),
              initialValue: age?.toString(),
              onChanged: (v) => onAgeChanged(int.tryParse(v)),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!
                    .profile_setup_age_label(
                      AppConstants.minAge,
                      AppConstants.maxAge,
                    ),
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
            Text(
              AppLocalizations.of(context)!.profile_setup_step_gender,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
                fontSize: 32,
                color: AuroraTheme.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
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

  const _GenderOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: isSelected ? AuroraTheme.auroraRed : AuroraTheme.glassBorder,
      onTap: onTap,
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected
                ? AuroraTheme.auroraRed
                : AuroraTheme.textSecondary,
            size: 28,
          ),
          const SizedBox(width: 16),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AuroraTheme.textPrimary,
              letterSpacing: -0.1,
            ),
          ),
          const Spacer(),
          if (isSelected)
            const Icon(
              Icons.check_circle,
              color: AuroraTheme.auroraRed,
              size: 22,
            ),
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

  String _localizedName(Map<String, dynamic> c) {
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == 'ru')
      return c['name_ru'] as String? ?? c['name'] as String? ?? '';
    if (lang == 'tr')
      return c['name_tr'] as String? ?? c['name'] as String? ?? '';
    return c['name_en'] as String? ?? c['name'] as String? ?? '';
  }

  Future<void> _loadCities() async {
    final data = await Supabase.instance.client
        .from('cities')
        .select('id, name, name_ru, name_tr, name_en')
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
          : _cities
                .where((c) => _localizedName(c).toLowerCase().contains(q))
                .toList();
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
            Text(
              AppLocalizations.of(context)!.profile_setup_city_question,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
                fontSize: 32,
                color: AuroraTheme.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _searchCtrl,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                color: AuroraTheme.textPrimary,
                height: 1.6,
              ),
              decoration: InputDecoration(
                hintText: AppLocalizations.of(
                  context,
                )!.profile_setup_city_search,
                prefixIcon: Icon(
                  Icons.search,
                  color: AuroraTheme.textMuted,
                  size: 20,
                ),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? GestureDetector(
                        onTap: () => _searchCtrl.clear(),
                        child: Icon(
                          Icons.close,
                          color: AuroraTheme.textMuted,
                          size: 18,
                        ),
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AuroraTheme.auroraRed,
                ),
              )
            else if (_filtered.isEmpty)
              Center(
                child: Text(
                  AppLocalizations.of(context)!.profile_setup_city_not_found,
                  style: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 14,
                    color: AuroraTheme.textSecondary,
                    height: 1.5,
                  ),
                ),
              )
            else
              ..._filtered.map((c) {
                final name = _localizedName(c);
                final id = c['id'] as String;
                final isSelected = widget.selectedCityId == id;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: GlassCard(
                    borderColor: isSelected
                        ? AuroraTheme.auroraRed
                        : AuroraTheme.glassBorder,
                    onTap: () => widget.onSelected(id),
                    child: Row(
                      children: [
                        Text(
                          name,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 16,
                            color: AuroraTheme.textPrimary,
                            height: 1.6,
                          ),
                        ),
                        const Spacer(),
                        if (isSelected)
                          const Icon(
                            Icons.check_circle,
                            color: AuroraTheme.auroraRed,
                            size: 20,
                          ),
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
            Text(
              AppLocalizations.of(context)!.profile_setup_bio_title,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
                fontSize: 32,
                color: AuroraTheme.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.profile_setup_bio_subtitle,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color: AuroraTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: bioController,
              maxLength: AppConstants.maxBioLength,
              maxLines: 5,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                color: AuroraTheme.textPrimary,
                height: 1.6,
              ),
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

  const _StepJobEducation({
    required this.jobController,
    required this.educationController,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.profile_setup_job_title,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
                fontSize: 32,
                color: AuroraTheme.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.profile_setup_step_job_edu,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color: AuroraTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            TextField(
              controller: jobController,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                color: AuroraTheme.textPrimary,
                height: 1.6,
              ),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                )!.profile_setup_job_label,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: educationController,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 16,
                color: AuroraTheme.textPrimary,
                height: 1.6,
              ),
              decoration: InputDecoration(
                labelText: AppLocalizations.of(
                  context,
                )!.profile_setup_education_label,
              ),
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

  const _StepInterests({
    required this.allInterests,
    required this.selected,
    required this.onToggle,
  });

  String _label(String key, AppLocalizations l10n) {
    switch (key) {
      case 'art':
        return l10n.profile_setup_interest_art;
      case 'music':
        return l10n.profile_setup_interest_music;
      case 'sports':
        return l10n.profile_setup_interest_sports;
      case 'books':
        return l10n.profile_setup_interest_books;
      case 'travel':
        return l10n.profile_setup_interest_travel;
      case 'food':
        return l10n.profile_setup_interest_food;
      case 'film':
        return l10n.profile_setup_interest_film;
      case 'theatre':
        return l10n.profile_setup_interest_theatre;
      case 'dance':
        return l10n.profile_setup_interest_dance;
      case 'yoga':
        return l10n.profile_setup_interest_yoga;
      case 'photography':
        return l10n.profile_setup_interest_photography;
      case 'games':
        return l10n.profile_setup_interest_games;
      case 'technology':
        return l10n.profile_setup_interest_technology;
      case 'nature':
        return l10n.profile_setup_interest_nature;
      case 'history':
        return l10n.profile_setup_interest_history;
      case 'fashion':
        return l10n.profile_setup_interest_fashion;
      default:
        return key;
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
            Text(
              l10n.profile_setup_interests_title,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
                fontSize: 32,
                color: AuroraTheme.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.profile_setup_interests_subtitle,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color: AuroraTheme.textSecondary,
                height: 1.5,
              ),
            ),
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
                  backgroundColor: AuroraTheme.glassBg,
                  selectedColor: AuroraTheme.auroraRed.withOpacity(0.2),
                  checkmarkColor: AuroraTheme.auroraRed,
                  side: BorderSide(
                    color: isSelected
                        ? AuroraTheme.auroraRed
                        : AuroraTheme.glassBorder,
                  ),
                  labelStyle: TextStyle(
                    fontFamily: 'Manrope',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.05,
                    color: isSelected
                        ? AuroraTheme.auroraRed
                        : AuroraTheme.textSecondary,
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

class _StepAgeRange extends StatelessWidget {
  final int minAge;
  final int maxAge;
  final void Function(int min, int max) onChanged;

  const _StepAgeRange({
    required this.minAge,
    required this.maxAge,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.profile_setup_age_range_title,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
                fontSize: 32,
                color: AuroraTheme.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.profile_setup_age_range_subtitle,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color: AuroraTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 40),
            Center(
              child: Text(
                AppLocalizations.of(
                  context,
                )!.profile_setup_age_range_value(minAge, maxAge),
                style: const TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: AuroraTheme.textPrimary,
                  letterSpacing: -0.1,
                ),
              ),
            ),
            const SizedBox(height: 16),
            RangeSlider(
              values: RangeValues(minAge.toDouble(), maxAge.toDouble()),
              min: 21,
              max: 60,
              divisions: 39,
              activeColor: AuroraTheme.auroraRed,
              inactiveColor: AuroraTheme.glassBorder,
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

  const _StepPrompts({
    required this.questions,
    required this.answers,
    required this.onAnswered,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Text(
              AppLocalizations.of(context)!.profile_setup_prompts_title,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
                fontSize: 32,
                color: AuroraTheme.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.profile_setup_prompts_subtitle,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color: AuroraTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            ...questions.entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      e.value,
                      style: const TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AuroraTheme.textPrimary,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      style: TextStyle(
                        fontFamily: 'Manrope',
                        fontSize: 16,
                        color: AuroraTheme.textPrimary,
                        height: 1.6,
                      ),
                      initialValue: answers[e.key] ?? '',
                      onChanged: (v) => onAnswered(e.key, v),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(
                          context,
                        )!.profile_setup_prompts_answer_hint,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepConsent extends StatelessWidget {
  final bool ageConfirmed;
  final bool dataConsent;
  final bool profileVisibilityConsent;
  final ValueChanged<bool> onAgeChanged;
  final ValueChanged<bool> onDataConsentChanged;
  final ValueChanged<bool> onProfileVisibilityChanged;
  final TextEditingController emailController;
  final bool marketingConsent;
  final ValueChanged<bool> onMarketingConsentChanged;

  const _StepConsent({
    required this.ageConfirmed,
    required this.dataConsent,
    required this.profileVisibilityConsent,
    required this.onAgeChanged,
    required this.onDataConsentChanged,
    required this.onProfileVisibilityChanged,
    required this.emailController,
    required this.marketingConsent,
    required this.onMarketingConsentChanged,
  });

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
            Text(
              l10n.profile_setup_step_consent,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
                fontSize: 32,
                color: AuroraTheme.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.profile_setup_consent_subtitle,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                color: AuroraTheme.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 28),
            _ConsentCheckbox(
              value: ageConfirmed,
              onChanged: onAgeChanged,
              text: l10n.profile_setup_consent_age,
            ),
            const SizedBox(height: 12),
            _ConsentCheckbox(
              value: dataConsent,
              onChanged: onDataConsentChanged,
              text: l10n.profile_setup_consent_data,
              linkText: l10n.profile_setup_consent_data_link,
              linkUrl: 'https://soulchoice.app/privacy',
            ),
            const SizedBox(height: 12),
            _ConsentCheckbox(
              value: profileVisibilityConsent,
              onChanged: onProfileVisibilityChanged,
              text: l10n.profile_setup_consent_visibility,
            ),
            // Seçenek B: opsiyonel e-posta + AYRI, işaretsiz pazarlama rızası (ФЗ-38).
            // Zorunlu onaylardan görsel olarak ayrık; _canProceed'e DAHİL DEĞİL.
            const SizedBox(height: 24),
            Text(
              l10n.profile_setup_email_label,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                color: AuroraTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 15,
                color: AuroraTheme.textPrimary,
              ),
              decoration: InputDecoration(
                hintText: l10n.profile_setup_email_hint,
                hintStyle: TextStyle(color: AuroraTheme.textMuted),
                filled: true,
                fillColor: AuroraTheme.glassBg,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AuroraTheme.glassBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AuroraTheme.glassBorder),
                ),
              ),
            ),
            const SizedBox(height: 12),
            _ConsentCheckbox(
              value: marketingConsent,
              onChanged: onMarketingConsentChanged,
              text: l10n.profile_setup_marketing_consent,
            ),
          ],
        ),
      ),
    );
  }
}

/// Onay satırı: checkbox + metin, opsiyonel olarak metne gömülü
/// tıklanabilir belge linki (delete_account_screen'deki Checkbox+GlassCard
/// kalıbıyla aynı stil). Kart kasıtlı olarak onTap almıyor — tüm satırı
/// tıklanabilir yapmak, link kısmına basıldığında gesture arena'da
/// checkbox toggle'ıyla çakışır; kutuya net basmak onay UX'i için doğrusu.
class _ConsentCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String text;
  final String? linkText;
  final String? linkUrl;

  const _ConsentCheckbox({
    required this.value,
    required this.onChanged,
    required this.text,
    this.linkText,
    this.linkUrl,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: value ? AuroraTheme.auroraRed : AuroraTheme.glassBorder,
      padding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Checkbox(
            value: value,
            onChanged: (v) => onChanged(v ?? false),
            activeColor: AuroraTheme.auroraRed,
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: linkText == null
                  ? Text(
                      text,
                      style: const TextStyle(
                        color: AuroraTheme.textPrimary,
                        fontFamily: 'Manrope',
                        fontSize: 14,
                        height: 1.4,
                      ),
                    )
                  : RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          color: AuroraTheme.textPrimary,
                          fontFamily: 'Manrope',
                          fontSize: 14,
                          height: 1.4,
                        ),
                        children: [
                          TextSpan(text: '$text '),
                          TextSpan(
                            text: linkText,
                            style: const TextStyle(
                              color: AuroraTheme.auroraRed,
                              decoration: TextDecoration.underline,
                            ),
                            recognizer: TapGestureRecognizer()
                              ..onTap = () =>
                                  launchUrl(Uri.parse(linkUrl!)),
                          ),
                        ],
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
