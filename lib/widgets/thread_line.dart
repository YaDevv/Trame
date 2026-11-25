import 'package:flutter/material.dart';

import '../app/theme.dart';

enum ThreadNode { fresh, replied, empty, deleted, none }

const _threadX = 13.0;
const _nodeY = 26.0;

/// Le fil vertical sur lequel s'accrochent les discussions.
class ThreadLine extends StatelessWidget {
  const ThreadLine({
    super.key,
    required this.node,
    required this.isFirst,
    required this.isLast,
    required this.child,
  });

  final ThreadNode node;
  final bool isFirst;
  final bool isLast;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _ThreadPainter(node: node, isFirst: isFirst, isLast: isLast),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(28, 4, 12, 4),
        child: child,
      ),
    );
  }
}

class _ThreadPainter extends CustomPainter {
  const _ThreadPainter({
    required this.node,
    required this.isFirst,
    required this.isLast,
  });

  final ThreadNode node;
  final bool isFirst;
  final bool isLast;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawLine(
      Offset(_threadX, isFirst ? _nodeY : 0),
      Offset(_threadX, isLast ? _nodeY : size.height),
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.28)
        ..strokeWidth = 2,
    );

    const center = Offset(_threadX, _nodeY);
    switch (node) {
      case ThreadNode.fresh:
        canvas.drawCircle(center, 6, Paint()..color = AppColors.accent);
      case ThreadNode.replied:
        canvas.drawCircle(center, 4.5, Paint()..color = AppColors.primary);
      case ThreadNode.empty:
        canvas.drawCircle(center, 4.5, Paint()..color = AppColors.background);
        canvas.drawCircle(
          center,
          4.5,
          Paint()
            ..color = AppColors.primary
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      case ThreadNode.deleted:
        canvas.drawRect(
          Rect.fromCenter(center: center, width: 12, height: 7),
          Paint()..color = AppColors.background,
        );
        canvas.drawLine(
          center.translate(-5, 0),
          center.translate(5, 0),
          Paint()
            ..color = AppColors.inkSoft
            ..strokeWidth = 2.5
            ..strokeCap = StrokeCap.round,
        );
      case ThreadNode.none:
        break;
    }
  }

  @override
  bool shouldRepaint(_ThreadPainter oldDelegate) {
    return node != oldDelegate.node ||
        isFirst != oldDelegate.isFirst ||
        isLast != oldDelegate.isLast;
  }
}
