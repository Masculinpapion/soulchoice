import 'package:flutter/material.dart';
import '../../core/theme/aurora_theme.dart';

/// Fraunces italik marka başlığı — brandTitleGradient.
///
/// CustomPainter kullanır. İki geçmiş yaklaşımın da kendine özgü bug'ı vardı:
/// - ShaderMask + BlendMode.srcIn: glyph kenarında beyaz leke (compositing
///   hatası — Skia'nın italik metin + mask katmanını birleştirme şekliyle
///   ilgili, matematiksel olarak olmaması gerekirken oluşuyor).
/// - Text.foreground = Paint()..shader=, Rect(0,0,w,h) ile: widget ekranda
///   (0,0) dışında bir yere çizildiğinde (örn. ortalanmış başlık) gradyan
///   kayıyor — çünkü RenderParagraph, offset'i canvas transformuna değil
///   doğrudan glyph koordinatlarına ekliyor.
///
/// CustomPaint bu ikisini de çözer: RenderCustomPaint, painter'ı çağırmadan
/// önce canvas'ı widget'ın offset'i kadar translate eder, yani painter içi
/// HER ZAMAN (0,0) tabanlı yerel bir tuval görür — mutlak koordinat kayması
/// yapısal olarak imkansız olur. Aynı zamanda foreground+Paint tekniğini
/// (ShaderMask değil) kullanmaya devam ettiğimiz için mask/compositing
/// katmanı hiç yok — beyaz leke de yapısal olarak imkansız olur.
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

  TextStyle get _baseStyle => TextStyle(
        fontFamily: 'Fraunces',
        fontStyle: FontStyle.italic,
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
      );

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(context);
    final tp = TextPainter(
      text: TextSpan(text: text, style: _baseStyle),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    // Dar alanda (uzun RU başlıklar, küçük ekranlar) otomatik küçül:
    // sabit-boyut CustomPaint tek başına RenderFlex taşması üretebiliyordu
    // ("RIGHT OVERFLOWED" — blocked_users başlığı, 07.07.2026).
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: CustomPaint(
        size: Size(tp.width, tp.height),
        painter: _GradientTextPainter(
          text: text,
          style: _baseStyle,
          textScaler: textScaler,
          gradient: gradient,
          textSize: Size(tp.width, tp.height),
        ),
      ),
    );
  }
}

class _GradientTextPainter extends CustomPainter {
  final String text;
  final TextStyle style;
  final TextScaler textScaler;
  final Gradient gradient;
  final Size textSize;

  _GradientTextPainter({
    required this.text,
    required this.style,
    required this.textScaler,
    required this.gradient,
    required this.textSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Fraunces italiğin uç kıvrımı mantıksal genişliğin ötesine taşar;
    // feed_screen.dart'taki ShaderMask başlıklarındaki aynı pay (+14/-4/-2/+4).
    final rect = Rect.fromLTRB(-4, -2, textSize.width + 14, textSize.height + 4);
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: style.copyWith(
          foreground: Paint()..shader = gradient.createShader(rect),
        ),
      ),
      textDirection: TextDirection.ltr,
      textScaler: textScaler,
    )..layout();
    tp.paint(canvas, Offset.zero);
  }

  @override
  bool shouldRepaint(covariant _GradientTextPainter oldDelegate) {
    return oldDelegate.text != text ||
        oldDelegate.style != style ||
        oldDelegate.gradient != gradient ||
        oldDelegate.textSize != textSize;
  }
}
