import 'package:flutter/material.dart';

import '../models/user.dart';

// Tons sombres : tous lisibles avec des initiales blanches.
const _tones = [
  Color(0xFF5B2A6E),
  Color(0xFF8A3B5C),
  Color(0xFF2F5D73),
  Color(0xFF3F6B4F),
  Color(0xFF8A5A1F),
  Color(0xFF4B4E8A),
];

/// La couleur depend de l'identifiant : stable d'un lancement a l'autre.
Color avatarColorFor(String userId) {
  final sum = userId.codeUnits.fold<int>(0, (total, unit) => total + unit);
  return _tones[sum % _tones.length];
}

class UserAvatar extends StatelessWidget {
  const UserAvatar({super.key, required this.user, this.size = 28});

  final User user;
  final double size;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: avatarColorFor(user.id),
          shape: BoxShape.circle,
        ),
        child: Text(
          user.displayName.characters.first.toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.46,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
