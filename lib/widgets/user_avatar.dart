import 'package:flutter/material.dart';

// Tons sombres : tous lisibles avec des initiales blanches.
const _tones = [
  Color(0xFF5B2A6E),
  Color(0xFF8A3B5C),
  Color(0xFF2F5D73),
  Color(0xFF3F6B4F),
  Color(0xFF8A5A1F),
  Color(0xFF4B4E8A),
];

/// Couleur d'avatar d'une personne : la somme des codes de ses caracteres,
/// modulo le nombre de couleurs. Meme nom = toujours la meme couleur.
Color avatarColorFor(String name) {
  final sum = name.codeUnits.fold<int>(0, (total, unit) => total + unit);
  return _tones[sum % _tones.length];
}
