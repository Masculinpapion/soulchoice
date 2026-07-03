import 'package:flutter/material.dart';
import '../../core/theme/aurora_theme.dart';

/// Fraunces italik marka başlığı — brandTitleGradient, ambient textScaler'a
/// göre ölçüm ve italik uç çıkıntısı için pay ile kenar lekesi/kırpılması yok.
class GradientItalicTitle extends StatelessWidget {
  final String text;
  final double fontSize;
  final FontWeight fontWeight;
  final double letterSpacing;
  final Gradient gradient;

  const GradientItalicTitle(
    this.text, {
    super.key,
    required this.fontSize,
    this.fontWeight = FontWeight.w700,
    this.letterSpacing = -0.5,
    this.gradient = AuroraTheme.brandTitleGradient,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = TextStyle(
      fontFamily: 'Fraunces',
      fontStyle: FontStyle.italic,
      fontSize: fontSize,
      fontWeight: fontWeight,
      letterSpacing: letterSpacing,
    );
    final tp = TextPainter(
      text: TextSpan(text: text, style: baseStyle),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
    )..layout();
    // Fraunces italiğin uç kıvrımı mantıksal genişliğin ötesine taşar;
    // feed_screen.dart'taki ShaderMask başlıklarındaki aynı pay (+14/-4/-2/+4).
    final rect = Rect.fromLTRB(-4, -2, tp.width + 14, tp.height + 4);
    return Text(
      text,
      style: baseStyle.copyWith(
        foreground: Paint()..shader = gradient.createShader(rect),
      ),
    );
  }
}
