import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Le nom du forum accroche a son fil.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.scale = 1});

  final double scale;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: Size(10 * scale, 24 * scale),
          painter: const _LogoThreadPainter(),
        ),
        SizedBox(width: 5 * scale),
        Text('Trame', style: logoStyle.copyWith(fontSize: 22 * scale)),
      ],
    );
  }
}

class _LogoThreadPainter extends CustomPainter {
  const _LogoThreadPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height),
      Paint()
        ..color = AppColors.primary
        ..strokeWidth = size.width / 6,
    );
    canvas.drawCircle(
      Offset(x, size.height / 2),
      size.width / 2.4,
      Paint()..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(_LogoThreadPainter oldDelegate) => false;
}
