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
import 'package:soulchoice/l10n/app_localizations.dart';

// Tek sayfa davet düzenleme — sihirbaz YOK. Kullanıcı tüm alanları görür,
// istediğini değiştirir, tek "Kaydet" ile çıkar. Süre (expires_at) burada
// gösterilmez: yayın anında belirlenir, düzenlemede değişmez.

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
const _bodyLargeStyle = TextStyle(
  fontFamily: 'Manrope',
  fontSize: 16,
  fontWeight: FontWeight.w400,
  color: AuroraTheme.textPrimary,
  height: 1.6,
);
final _labelMediumStyle = TextStyle(
  fontFamily: 'Manrope',
  fontSize: 13,
  fontWeight: FontWeight.w600,
  color: AuroraTheme.textSecondary,
  letterSpacing: 0.05,
);
const _pillTitleStyle = TextStyle(
  fontFamily: 'Manrope',
  fontSize: 15,
  fontWeight: FontWeight.w700,
  color: AuroraTheme.textPrimary,
  letterSpacing: -0.1,
);

class EditInvitationScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  const EditInvitationScreen({super.key, required this.data});

  @override
  ConsumerState<EditInvitationScreen> createState() =>
      _EditInvitationScreenState();
}

class _EditInvitationScreenState extends ConsumerState<EditInvitationScreen> {
  late InvitationFlowType _flowType;
  InvitationCategory? _category;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _venueController = TextEditingController();
  DateTime? _eventDate;
  bool _isSaving = false;

  bool get _isTravel => _category == InvitationCategory.travel;

  @override
  void initState() {
    super.initState();
    final ed = widget.data;
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

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _venueController.dispose();
    super.dispose();
  }

  String? _validate(AppLocalizations l10n) {
    if (_category == null) return l10n.create_inv_validation_category;
    if (_titleController.text.trim().isEmpty) {
      return l10n.create_inv_validation_title;
    }
    if (_isTravel && _descriptionController.text.trim().isEmpty) {
      return l10n.create_inv_validation_description_travel;
    }
    if (_venueController.text.trim().isEmpty) {
      return l10n.create_inv_validation_venue;
    }
    if (_eventDate == null) return l10n.create_inv_validation_date;
    return null;
  }

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

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final error = _validate(l10n);
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

    setState(() => _isSaving = true);
    try {
      final client = Supabase.instance.client;
      final rawVenue = _venueController.text.trim();
      final originalVenue = widget.data['venue_name'] as String?;
      // Değişmediyse olduğu gibi bırak (seçilmiş yer adını bozma);
      // değiştiyse serbest metin gibi biçimle.
      final venueFormatted = rawVenue.isEmpty
          ? null
          : rawVenue == originalVenue
              ? originalVenue
              : rawVenue
                    .split(' ')
                    .where((w) => w.isNotEmpty)
                    .map((w) => w[0].toUpperCase() + w.substring(1))
                    .join(' ');

      final editId = widget.data['id'] as String;
      await client
          .from('invitations')
          .update({
            'flow_type': _flowType.name,
            'category': _category?.name ?? InvitationCategory.food.name,
            'title': _fixCase(_titleController.text),
            'description': _descriptionController.text.trim().isEmpty
                ? null
                : _fixCase(_descriptionController.text),
            'venue_name': venueFormatted,
            // Yer metni elle değişti — eski yer bağlantısı/koordinat artık
            // geçersiz, snapshot'ı temizle.
            if (venueFormatted != originalVenue) ...{
              'place_id': null,
              'place_kind': null,
              'venue_address': null,
              'venue_lat': null,
              'venue_lng': null,
            },
            'event_date': _eventDate?.toIso8601String(),
          })
          .eq('id', editId);

      if (mounted) {
        ref.invalidate(invitationDetailProvider(editId));
        ref.invalidate(invitationsProvider);
        ref.invalidate(myActiveInvitationsProvider);
        context.pop();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.error_generic),
            backgroundColor: AuroraTheme.auroraRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String _formatDate(DateTime dt) {
    final d =
        '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$d  $h:$m';
  }

  Future<void> _pickDateTime() async {
    final now = DateTime.now();
    final initial = (_eventDate != null && _eventDate!.isAfter(now))
        ? _eventDate!
        : now.add(const Duration(hours: 2));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (pickedDate == null || !mounted) return;
    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _eventDate?.hour ?? (now.hour + 2) % 24,
        minute: _eventDate?.minute ?? 0,
      ),
      initialEntryMode: TimePickerEntryMode.input,
    );
    if (pickedTime == null) return;
    setState(() {
      _eventDate = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(text.toUpperCase(), style: _sectionLabelStyle),
  );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                      child: Text(l10n.edit_inv_title, style: _screenTitleStyle),
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
                      // ── Akış türü ──
                      // Akış türü düzenlemede DEĞİŞTİRİLEMEZ (başvuranların
                      // bağlamı + tür bazlı aktif kart limiti korunur) —
                      // salt-okunur rozet olarak gösterilir.
                      _sectionLabel(l10n.create_inv_step_flow_type),
                      _FlowTypeBadge(
                        title: _flowType == InvitationFlowType.invite
                            ? l10n.create_inv_flow_invite_title
                            : l10n.create_inv_flow_request_title,
                        icon: _flowType == InvitationFlowType.invite
                            ? Icons.wine_bar_rounded
                            : Icons.explore_rounded,
                        color: _flowType == InvitationFlowType.invite
                            ? AuroraTheme.auroraRed
                            : AuroraTheme.auroraBlue,
                      ),
                      const SizedBox(height: 28),

                      // ── Kategori ──
                      _sectionLabel(l10n.create_inv_step_category),
                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 4,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.95,
                        children: InvitationCategory.values.map((c) {
                          final isSelected = _category == c;
                          return GestureDetector(
                            onTap: () => setState(() => _category = c),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              decoration: BoxDecoration(
                                gradient: isSelected
                                    ? AuroraTheme.redBlueGradient
                                    : null,
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
                                    width: 28,
                                    height: 28,
                                    child: Center(
                                      child: c == InvitationCategory.bar
                                          ? Image.asset(
                                              'assets/icons/bar.png',
                                              width: 25,
                                              height: 25,
                                            )
                                          : c == InvitationCategory.concert
                                          ? Image.asset(
                                              'assets/icons/music.png',
                                              width: 18,
                                              height: 18,
                                              color: AuroraTheme.auroraRed,
                                            )
                                          : Text(
                                              c.emoji,
                                              style: const TextStyle(
                                                fontSize: 22,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Text(
                                      c.labelFor(l10n),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                      style: _labelMediumStyle.copyWith(
                                        fontSize: 11,
                                        color: isSelected
                                            ? AuroraTheme.textPrimary
                                            : AuroraTheme.textSecondary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 28),

                      // ── Başlık ──
                      _sectionLabel(l10n.create_inv_step_title),
                      TextField(
                        controller: _titleController,
                        maxLength: 60,
                        style: _bodyLargeStyle,
                        decoration: InputDecoration(
                          labelText: l10n.create_inv_title_label,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Açıklama ──
                      _sectionLabel(l10n.create_inv_step_description),
                      TextField(
                        controller: _descriptionController,
                        maxLines: 4,
                        maxLength: 300,
                        style: _bodyLargeStyle,
                        decoration: InputDecoration(
                          hintText: l10n.create_inv_desc_input_hint,
                          alignLabelWithHint: true,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Yer (mekân / destinasyon / marka) ──
                      _sectionLabel(_isTravel
                          ? l10n.create_inv_step_destination
                          : _category == InvitationCategory.gift
                              ? l10n.create_inv_step_brand
                              : l10n.create_inv_step_venue),
                      TextField(
                        controller: _venueController,
                        style: _bodyLargeStyle,
                        decoration: InputDecoration(
                          labelText: l10n.create_inv_venue_label,
                          prefixIcon: Icon(
                            Icons.location_on_outlined,
                            color: AuroraTheme.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Tarih & saat ──
                      _sectionLabel(l10n.create_inv_step_datetime),
                      GlassCard(
                        onTap: _pickDateTime,
                        child: Row(
                          children: [
                            ShaderMask(
                              blendMode: BlendMode.srcIn,
                              shaderCallback: (b) =>
                                  AuroraTheme.redBlueGradient.createShader(
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
                              _eventDate != null
                                  ? _formatDate(_eventDate!)
                                  : l10n.create_inv_datetime_placeholder,
                              style: _bodyLargeStyle.copyWith(
                                color: _eventDate != null
                                    ? AuroraTheme.textPrimary
                                    : AuroraTheme.textMuted,
                              ),
                            ),
                          ],
                        ),
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

class _FlowTypeBadge extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  const _FlowTypeBadge({
    required this.title,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: color.withValues(alpha: 0.45)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            title,
            style: _pillTitleStyle.copyWith(fontSize: 14),
          ),
        ),
      ],
    ),
  );
}
