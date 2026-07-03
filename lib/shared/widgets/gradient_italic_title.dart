import 'package:flutter/material.dart';
import '../../core/theme/aurora_theme.dart';

/// Fraunces italik marka başlığı — brandTitleGradient.
///
/// ShaderMask kullanır çünkü shaderCallback'e gelen bounds widget'ın KENDİ
/// lokal boyutudur; Text.foreground'a doğrudan Paint().shader= verirsek
/// shader mutlak çizim koordinatlarında değerlendirilir ve widget ekranda
/// (0,0) dışında bir yere (örn. ortalanmış bir başlık) çizildiğinde gradyan
/// tamamen kayar (offset > rect genişliği ise düz tek renk görünür).
/// +14/-4/-2/+4 payı Fraunces italiğin uç kıvrımının bounds dışına taşmasını
/// karşılar (feed_screen.dart'taki diğer ShaderMask başlıklarıyla aynı pay).
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
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (b) => gradient.createShader(
        Rect.fromLTRB(b.left - 4, b.top - 2, b.right + 14, b.bottom + 4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Fraunces',
          fontStyle: FontStyle.italic,
          fontSize: fontSize,
          fontWeight: fontWeight,
          color: Colors.white,
          letterSpacing: letterSpacing,
        ),
      ),
    );
  }
}
