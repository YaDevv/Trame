import 'package:flutter/material.dart';

import '../../app/theme.dart';

const _rules = [
  (
    'Reste courtois',
    'Débats tant que tu veux, mais vise les idées, jamais les personnes.',
  ),
  (
    'Un sujet par discussion',
    'Donne un titre clair. Une nouvelle question mérite sa propre discussion.',
  ),
  (
    'Pas de données personnelles',
    'Ne publie ni adresse, ni numéro, ni information privée sur quelqu’un.',
  ),
  (
    'Pas de spam ni de publicité',
    'Les messages répétés ou promotionnels sont retirés.',
  ),
  (
    'La modération veille',
    'Un message qui ne respecte pas ces règles peut être retiré par la modération.',
  ),
];

class RulesScreen extends StatelessWidget {
  const RulesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Règles de la communauté')),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _rules.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final (title, text) = _rules[index];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: threadTitleStyle.copyWith(fontSize: 17)),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppColors.inkSoft,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
