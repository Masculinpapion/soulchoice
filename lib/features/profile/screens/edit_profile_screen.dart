import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/aurora_theme.dart';
import '../../../shared/widgets/ambient_background.dart';
import '../../../shared/widgets/glass_card.dart';
import '../../../shared/widgets/sc_button.dart';
import '../../../shared/widgets/sc_scaffold.dart';
import '../providers/profile_provider.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

// Tek sayfa profil düzenleme — kayıt sihirbazı (ProfileSetupScreen) yalnız
// ilk kurulumda kullanılır. Burada kullanıcı tüm alanlarını görür, istediğini
// değiştirir, tek "Kaydet" ile çıkar. Consent/e-posta adımları onboarding'e
// aittir, burada yok. Cinsiyet feed eşleştirmesinin temeli olduğu için
// düzenlemede DEĞİŞTİRİLEMEZ (salt-okunur rozet).

final _sectionLabelStyle = TextStyle(
  fontFamily: 'JetBrainsMono',
  fontSize: 11,
  fontWeight: FontWeight.w400,
  color: AuroraTheme.textMuted,
  letterSpacing: 1.2,
);
const _screenTitleStyle = TextStyle(
  fontFamily: 'Fraunces',
  fontStyle: FontStyle.italic,
  fontSize: 22,
  fontWeight: FontWeight.w400,
  color: AuroraTheme.textPrimary,
  letterSpacing: -0.5,
  height: 1.15,
);
final _fieldStyle = TextStyle(
  fontFamily: 'Manrope',
  fontSize: 16,
  color: AuroraTheme.textPrimary,
  height: 1.6,
);
const _promptQuestionStyle = TextStyle(
  fontFamily: 'Manrope',
  fontSize: 15,
  fontWeight: FontWeight.w700,
  color: AuroraTheme.textPrimary,
  letterSpacing: 0.1,
);

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _bioController = TextEditingController();
  final _jobController = TextEditingController();
  final _educationController = TextEditingController();
  String? _gender;
  String? _cityId;
  String _cityName = '';
  final Set<String> _interests = {};
  final Map<String, String> _prompts = {};
  int _minAge = 21;
  int _maxAge = 60;
  bool _isSaving = false;
  bool _isLoading = true;

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

  Map<String, String> _getPromptQuestions(AppLocalizations l10n) => {
    'favorite_restaurant': l10n.profile_setup_prompt_favorite_restaurant,
    'last_book': l10n.profile_setup_prompt_last_book(_gender ?? 'other'),
    'perfect_evening': l10n.profile_setup_prompt_perfect_evening,
    'travel_dream': l10n.profile_setup_prompt_travel_dream,
  };

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final client = Supabase.instance.client;
    final user = client.auth.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final row = await client
          .from('users')
          .select(
            'name, age, gender, city_id, bio, job, education, interests, min_age, max_age, cities(name, name_ru, name_tr, name_en)',
          )
          .eq('id', user.id)
          .maybeSingle();
      if (!mounted) return;
      if (row == null) {
        setState(() => _isLoading = false);
        return;
      }
      _nameController.text = row['name'] as String? ?? '';
      _ageController.text = (row['age'] as int?)?.toString() ?? '';
      _bioController.text = row['bio'] as String? ?? '';
      _jobController.text = row['job'] as String? ?? '';
      _educationController.text = row['education'] as String? ?? '';

      final prompts = await client
          .from('user_prompts')
          .select('question_key, answer')
          .eq('user_id', user.id);
      if (!mounted) return;

      setState(() {
        _gender = row['gender'] as String?;
        _cityId = row['city_id'] as String?;
        _cityName = _localizedCityName(
          (row['cities'] as Map<String, dynamic>?) ?? const {},
        );
        final interests = row['interests'];
        _interests.clear();
        if (interests is List) _interests.addAll(interests.cast<String>());
        for (final p in prompts) {
          _prompts[p['question_key'] as String] = p['answer'] as String;
        }
        _minAge = row['min_age'] as int? ?? 21;
        _maxAge = row['max_age'] as int? ?? 60;
        _isLoading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _localizedCityName(Map<String, dynamic> c) {
    final lang = Localizations.localeOf(context).languageCode;
    if (lang == 'ru') {
      return c['name_ru'] as String? ?? c['name'] as String? ?? '';
    }
    if (lang == 'tr') {
      return c['name_tr'] as String? ?? c['name'] as String? ?? '';
    }
    return c['name_en'] as String? ?? c['name'] as String? ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _bioController.dispose();
    _jobController.dispose();
    _educationController.dispose();
    super.dispose();
  }

  Future<void> _pickCity() async {
    final picked = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AuroraTheme.bgDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _CityPickerSheet(),
    );
    if (picked != null && mounted) {
      setState(() {
        _cityId = picked['id'] as String;
        _cityName = _localizedCityName(picked);
      });
    }
  }

  String? _validate(AppLocalizations l10n) {
    if (_nameController.text.trim().isEmpty) {
      return l10n.profile_setup_validation_name;
    }
    final age = int.tryParse(_ageController.text.trim());
    if (age == null || age < AppConstants.minAge || age > AppConstants.maxAge) {
      return l10n.profile_setup_validation_age(
        AppConstants.minAge,
        AppConstants.maxAge,
      );
    }
    if (_cityId == null) return l10n.profile_setup_validation_city;
    return null;
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final error = _validate(l10n);
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error),
          backgroundColor: AuroraTheme.auroraRed,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final client = Supabase.instance.client;
      final uid = client.auth.currentUser!.id;

      // NOT: update (upsert değil) — consent_given_at/consent_version gibi
      // onboarding alanlarına dokunulmaz.
      await client
          .from('users')
          .update({
            'name': _nameController.text.trim(),
            'age': int.parse(_ageController.text.trim()),
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
          })
          .eq('id', uid);

      if (_prompts.isNotEmpty) {
        await client.from('user_prompts').upsert(
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

      if (mounted) {
        ref.invalidate(userProfileProvider(uid));
        ref.invalidate(userPromptsProvider(uid));
        context.pop();
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
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text.toUpperCase(), style: _sectionLabelStyle),
  );

  String _interestLabel(String key, AppLocalizations l10n) {
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
    if (_isLoading) {
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
                padding: const EdgeInsets.fromLTRB(8, 8, 24, 4),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.arrow_back_ios_new,
                        color: AuroraTheme.textPrimary,
                      ),
                      onPressed: () => context.pop(),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        l10n.settings_edit_profile,
                        style: _screenTitleStyle,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── İsim + yaş ──
                      _sectionLabel(l10n.profile_setup_step_name_age),
                      TextField(
                        controller: _nameController,
                        style: _fieldStyle,
                        decoration: InputDecoration(
                          labelText: l10n.profile_setup_name_label,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        style: _fieldStyle,
                        decoration: InputDecoration(
                          labelText: l10n.profile_setup_age_label(
                            AppConstants.minAge,
                            AppConstants.maxAge,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Cinsiyet (salt-okunur) ──
                      _sectionLabel(l10n.profile_setup_step_gender),
                      _GenderBadge(
                        label: _gender == 'female'
                            ? l10n.profile_setup_gender_female
                            : l10n.profile_setup_gender_male,
                        icon: _gender == 'female' ? Icons.female : Icons.male,
                      ),
                      const SizedBox(height: 28),

                      // ── Şehir ──
                      _sectionLabel(l10n.profile_setup_step_city),
                      GlassCard(
                        onTap: _pickCity,
                        child: Row(
                          children: [
                            Icon(
                              Icons.location_on_outlined,
                              color: AuroraTheme.textMuted,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                _cityName.isNotEmpty
                                    ? _cityName
                                    : l10n.profile_setup_city_search,
                                style: _fieldStyle.copyWith(
                                  color: _cityName.isNotEmpty
                                      ? AuroraTheme.textPrimary
                                      : AuroraTheme.textMuted,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.chevron_right,
                              color: AuroraTheme.textMuted,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Bio ──
                      _sectionLabel(l10n.profile_setup_step_bio),
                      TextField(
                        controller: _bioController,
                        maxLength: AppConstants.maxBioLength,
                        maxLines: 5,
                        style: _fieldStyle,
                        decoration: InputDecoration(
                          hintText: l10n.profile_setup_bio_hint,
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── İş + eğitim ──
                      _sectionLabel(l10n.profile_setup_step_job_edu),
                      TextField(
                        controller: _jobController,
                        style: _fieldStyle,
                        decoration: InputDecoration(
                          labelText: l10n.profile_setup_job_label,
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _educationController,
                        style: _fieldStyle,
                        decoration: InputDecoration(
                          labelText: l10n.profile_setup_education_label,
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── İlgi alanları ──
                      _sectionLabel(l10n.profile_setup_step_interests),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _allInterestKeys.map((interest) {
                          final isSelected = _interests.contains(interest);
                          return FilterChip(
                            label: Text(_interestLabel(interest, l10n)),
                            selected: isSelected,
                            onSelected: (_) => setState(() {
                              isSelected
                                  ? _interests.remove(interest)
                                  : _interests.add(interest);
                            }),
                            backgroundColor: AuroraTheme.glassBg,
                            selectedColor: AuroraTheme.auroraRed.withValues(
                              alpha: 0.2,
                            ),
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
                      const SizedBox(height: 28),

                      // ── Sorular ──
                      _sectionLabel(l10n.profile_setup_step_prompts),
                      ..._getPromptQuestions(l10n).entries.map(
                        (e) => Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.value, style: _promptQuestionStyle),
                              const SizedBox(height: 8),
                              TextFormField(
                                style: _fieldStyle,
                                initialValue: _prompts[e.key] ?? '',
                                onChanged: (v) => _prompts[e.key] = v,
                                decoration: InputDecoration(
                                  hintText:
                                      l10n.profile_setup_prompts_answer_hint,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // ── Yaş aralığı ──
                      _sectionLabel(l10n.profile_setup_step_age_range),
                      Center(
                        child: Text(
                          l10n.profile_setup_age_range_value(_minAge, _maxAge),
                          style: const TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AuroraTheme.textPrimary,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      RangeSlider(
                        values: RangeValues(
                          _minAge.toDouble(),
                          _maxAge.toDouble(),
                        ),
                        min: 21,
                        max: 60,
                        divisions: 39,
                        activeColor: AuroraTheme.auroraRed,
                        inactiveColor: AuroraTheme.glassBorder,
                        labels: RangeLabels('$_minAge', '$_maxAge'),
                        onChanged: (v) => setState(() {
                          _minAge = v.start.round();
                          _maxAge = v.end.round();
                        }),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                // Üst 12px: klavye açıkken buton içeriğe yapışmasın (13.07).
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
                child: ScButton(
                  label: l10n.btn_save,
                  onPressed: _isSaving ? null : _save,
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

class _GenderBadge extends StatelessWidget {
  final String label;
  final IconData icon;
  const _GenderBadge({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: AuroraTheme.auroraRed.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: AuroraTheme.auroraRed.withValues(alpha: 0.45),
      ),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AuroraTheme.auroraRed),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontFamily: 'Manrope',
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AuroraTheme.textPrimary,
            letterSpacing: -0.1,
          ),
        ),
      ],
    ),
  );
}

class _CityPickerSheet extends StatefulWidget {
  const _CityPickerSheet();

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
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
    if (lang == 'ru') {
      return c['name_ru'] as String? ?? c['name'] as String? ?? '';
    }
    if (lang == 'tr') {
      return c['name_tr'] as String? ?? c['name'] as String? ?? '';
    }
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
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _searchCtrl,
                autofocus: false,
                style: _fieldStyle,
                decoration: InputDecoration(
                  hintText: l10n.profile_setup_city_search,
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
              const SizedBox(height: 16),
              Expanded(
                child: _loading
                    ? const Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AuroraTheme.auroraRed,
                        ),
                      )
                    : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          l10n.profile_setup_city_not_found,
                          style: TextStyle(
                            fontFamily: 'Manrope',
                            fontSize: 14,
                            color: AuroraTheme.textSecondary,
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _filtered.length,
                        itemBuilder: (_, i) {
                          final c = _filtered[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: GlassCard(
                              onTap: () => Navigator.of(context).pop(c),
                              child: Text(
                                _localizedName(c),
                                style: _fieldStyle,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
