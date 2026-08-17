// Hediye ürün linki / adı alanı — create ve edit ekranlarında ORTAK.
// Alan + kilit yardımı + "Tanınan mağazalar ›" (alttan açılan gruplu liste).
// Kural/liste: ../logic/gift_link_rules.dart (tek kaynak).

import 'package:flutter/material.dart';
import 'package:soulchoice/l10n/app_localizations.dart';
import '../../../core/theme/aurora_theme.dart';
import '../logic/gift_link_rules.dart';

const _bodyLarge = TextStyle(
  fontFamily: 'Manrope',
  fontSize: 16,
  fontWeight: FontWeight.w400,
  color: AuroraTheme.textPrimary,
  height: 1.6,
);

class GiftUrlField extends StatelessWidget {
  final TextEditingController controller;
  const GiftUrlField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final helper = TextStyle(
      fontFamily: 'Manrope',
      fontSize: 12,
      height: 1.5,
      color: AuroraTheme.textSecondary,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          style: _bodyLarge,
          keyboardType: TextInputType.url,
          autocorrect: false,
          scrollPadding: const EdgeInsets.only(bottom: 120),
          decoration: InputDecoration(
            hintText: l10n.create_inv_gift_url_hint,
            prefixIcon: Icon(Icons.link_rounded, color: AuroraTheme.textMuted),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline_rounded, size: 14, color: AuroraTheme.textMuted),
            const SizedBox(width: 6),
            Expanded(child: Text(l10n.create_inv_gift_url_helper, style: helper)),
          ],
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () => showGiftStoresSheet(context),
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Icon(Icons.storefront_outlined, size: 14, color: AuroraTheme.auroraBlue),
                const SizedBox(width: 6),
                Text(
                  l10n.gift_stores_link,
                  style: helper.copyWith(
                    color: AuroraTheme.auroraBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 16, color: AuroraTheme.auroraBlue),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// "Tanınan mağazalar" — gruplu liste, salt bilgi.
Future<void> showGiftStoresSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) {
      final l10n = AppLocalizations.of(ctx)!;
      final maxH = MediaQuery.of(ctx).size.height * 0.8;
      return Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: BoxDecoration(
          color: AuroraTheme.bgDeep,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: AuroraTheme.glassBorder, width: 0.8),
        ),
        child: SafeArea(
          top: false,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                l10n.gift_stores_title,
                style: const TextStyle(
                  fontFamily: 'Fraunces',
                  fontStyle: FontStyle.italic,
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: AuroraTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.gift_stores_intro,
                style: TextStyle(
                  fontFamily: 'Manrope',
                  fontSize: 13,
                  height: 1.5,
                  color: AuroraTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              for (final g in giftStoreGroups) ...[
                Text(
                  g.label(l10n).toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'JetBrainsMono',
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: AuroraTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final d in g.domains)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: AuroraTheme.glassBg,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(color: AuroraTheme.glassBorder),
                        ),
                        child: Text(
                          d,
                          style: const TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontSize: 12,
                            color: AuroraTheme.textPrimary,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
              ],
            ],
          ),
        ),
      );
    },
  );
}
