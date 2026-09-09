import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:soulchoice/l10n/app_localizations.dart';

import '../theme/aurora_theme.dart';
import '../../shared/widgets/glass_card.dart';

/// Cinsiyet kapısı (iOS «önce plan» paketi, 09.09.2026).
///
/// iOS sihirbazı cinsiyet sormaz (`planFirstMode`); sunucu eşleştirmesi için
/// gereken değer ilk plan yayınında / ilk başvuruda TEK soruyla alınır.
/// Android'de cinsiyet kayıtta alındığından `users.gender` doludur ve bu kapı
/// hiç açılmaz — davranış değişmez.
///
/// Döner: `true` = cinsiyet var (ya da şimdi seçildi), devam edilebilir.
Future<bool> ensureGenderSelected(BuildContext context) async {
  final client = Supabase.instance.client;
  final uid = client.auth.currentUser?.id;
  if (uid == null) return false;
  final row = await client
      .from('users')
      .select('gender')
      .eq('id', uid)
      .maybeSingle();
  final current = row?['gender'] as String?;
  if (current == 'male' || current == 'female') return true;
  if (!context.mounted) return false;

  final picked = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (_) => const _GenderSheet(),
  );
  if (picked == null) return false;
  await client.from('users').update({'gender': picked}).eq('id', uid);
  return true;
}

class _GenderSheet extends StatefulWidget {
  const _GenderSheet();

  @override
  State<_GenderSheet> createState() => _GenderSheetState();
}

class _GenderSheetState extends State<_GenderSheet> {
  String? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          color: AuroraTheme.bgDeep,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AuroraTheme.glassBorder),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.gender_sheet_title,
              style: const TextStyle(
                fontFamily: 'Fraunces',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w700,
                fontSize: 26,
                color: AuroraTheme.textPrimary,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.gender_sheet_body,
              style: TextStyle(
                fontFamily: 'Manrope',
                fontSize: 14,
                height: 1.5,
                color: AuroraTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            _Option(
              label: l10n.profile_setup_gender_female,
              icon: Icons.female,
              selected: _selected == 'female',
              onTap: () => Navigator.of(context).pop('female'),
            ),
            const SizedBox(height: 10),
            _Option(
              label: l10n.profile_setup_gender_male,
              icon: Icons.male,
              selected: _selected == 'male',
              onTap: () => Navigator.of(context).pop('male'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Option extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  const _Option({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      borderColor: selected ? AuroraTheme.auroraRed : AuroraTheme.glassBorder,
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon,
              color: selected ? AuroraTheme.auroraRed : AuroraTheme.textSecondary,
              size: 26),
          const SizedBox(width: 14),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Manrope',
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AuroraTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
