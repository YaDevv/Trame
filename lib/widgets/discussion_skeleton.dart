import 'package:flutter/material.dart';

import '../app/theme.dart';
import 'thread_line.dart';

/// Forme des discussions pendant leur chargement, sans animation.
class DiscussionSkeletonList extends StatelessWidget {
  const DiscussionSkeletonList({super.key});

  static const _count = 4;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Chargement des discussions',
      child: ExcludeSemantics(
        child: ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _count,
          itemBuilder: (context, index) => ThreadLine(
            node: ThreadNode.none,
            isFirst: index == 0,
            isLast: index == _count - 1,
            child: const _SkeletonCard(),
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: const Column(
        children: [
          Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: AppColors.skeleton,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(child: _Bar(widthFactor: 0.45, height: 12)),
            ],
          ),
          SizedBox(height: 12),
          _Bar(widthFactor: 0.8, height: 15),
          SizedBox(height: 12),
          _Bar(widthFactor: 1, height: 12),
          SizedBox(height: 8),
          _Bar(widthFactor: 0.6, height: 12),
        ],
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.widthFactor, required this.height});

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: widthFactor,
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.skeleton,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
