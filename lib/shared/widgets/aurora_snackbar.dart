import 'package:flutter/material.dart';
import '../../core/theme/aurora_theme.dart';

/// Kilitli snackbar deseni (12.08 kararı): dolgu HER ZAMAN nötr koyu cam;
/// anlam (hata/başarı) dolguyla değil, kenar + ikon vurgu rengiyle verilir.
/// Renkli dolgulu SnackBar açma — bu dosyayı kullan.
SnackBar auroraSnackBar(
  String message, {
  Color accentColor = AuroraTheme.auroraRed,
  IconData icon = Icons.error_outline,
}) =>
    SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      backgroundColor: AuroraTheme.bgDeep,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentColor.withOpacity(0.4)),
      ),
      content: Row(
        children: [
          Icon(icon, color: accentColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontFamily: 'Manrope',
                fontSize: 13,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );

void showAuroraErrorSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(auroraSnackBar(message));
}
