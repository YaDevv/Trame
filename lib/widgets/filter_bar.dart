import 'package:flutter/material.dart';

import '../app/theme.dart';
import '../repositories/discussion_repository.dart';

const _labels = {
  DiscussionFilter.recent: 'Récentes',
  DiscussionFilter.active: 'Actives',
  DiscussionFilter.unanswered: 'Sans réponse',
};

class FilterBar extends StatelessWidget {
  const FilterBar({super.key, required this.selected, required this.onSelected});

  final DiscussionFilter selected;
  final ValueChanged<DiscussionFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 2),
        child: Row(
          children: [
            for (final filter in DiscussionFilter.values)
              _FilterPill(
                label: _labels[filter]!,
                isSelected: filter == selected,
                onTap: () => onSelected(filter),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterPill extends StatelessWidget {
  const _FilterPill({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      // La pastille mesure 30 px, la zone de toucher 40 px.
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(0, 5, 6, 5),
          child: Container(
            height: 30,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary : AppColors.card,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
              ),
            ),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.inkSoft,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
