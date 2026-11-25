# Trame — démo Flutter reliée à une API Symfony

Trame est un petit forum scolaire et informatique. Cette version de démonstration est une application Flutter (web) qui communique avec une API Symfony / API Platform hébergée sur `https://4534.s3.nuage-peda.fr/forum`.

Elle permet de :

- lire les discussions sans compte ;
- s'inscrire et se connecter (authentification JWT) ;
- publier un message (l'auteur est fixé par l'API à partir du jeton) ;
- consulter son profil, avec le badge Membre ou Administrateur ;
- se déconnecter.

## Lancer la démo

Prérequis : Flutter 3.47 ou plus récent (Dart 3.13.7 ou plus), et un accès à Internet.

```bash
git clone <adresse du dépôt>
cd <dossier du dépôt>
flutter pub get
flutter run -d web-server --web-port 8083 --release -t lib/main_demo.dart
```

Ouvrir ensuite `http://localhost:8083` dans un navigateur.

Dans VS Code : ouvrir le dossier, puis choisir la configuration « Trame DÉMO API (navigateur, port 8083) » dans le panneau Exécuter.

## Tests

```bash
flutter test
```

## Organisation

- `lib/main_demo.dart` : point d'entrée de la démo.
- `lib/demo_api/` : écrans de la démo, session et client de l'API (`forum_api.dart`).
- `lib/app`, `lib/core`, `lib/widgets` : thème, utilitaires et composants visuels utilisés par la démo.
- `test/demo_api_test.dart` : tests de la démo (avec une fausse API, sans réseau).
