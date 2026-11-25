import 'package:flutter/material.dart';

import '../core/validators.dart';
import '../widgets/auth_form.dart';
import 'api_validators.dart';
import 'forum_api.dart';

/// Inscription : POST /api/users, avec les champs de l'entite User de l'API.
/// En cas de succes, renvoie l'email a l'ecran de connexion.
class DemoRegisterScreen extends StatefulWidget {
  const DemoRegisterScreen({super.key, required this.api});

  final ForumApi api;

  @override
  State<DemoRegisterScreen> createState() => _DemoRegisterScreenState();
}

class _DemoRegisterScreenState extends State<DemoRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  // Un contrôleur par champ du formulaire.
  final _prenom = TextEditingController();
  final _nom = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    // Libère les 5 contrôleurs.
    for (final c in [_prenom, _nom, _email, _password, _confirmation]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // Envoie l'inscription à l'API (POST /api/users).
      await widget.api.register(
        prenom: _prenom.text,
        nom: _nom.text,
        email: _email.text,
        password: _password.text,
      );
      // Succès : on ferme l'écran et on renvoie l'email à l'écran de connexion.
      if (mounted) Navigator.of(context).pop(_email.text.trim());
    // 422 : l'API a refusé un champ (ex. email déjà utilisé) ; on affiche ses messages.
    } on ValidationException catch (e) {
      _showError(e.messages.values.where((m) => m.isNotEmpty).join('\n'));
    } on UnauthorizedException {
      _showError(
        'Les inscriptions sont momentanément fermées. Réessaie plus tard.',
      );
    } on ApiUnavailableException {
      _showError(
        'Inscription impossible pour le moment. Vérifie ta connexion '
        'internet, puis réessaie.',
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message.isEmpty
          ? 'Ton inscription n’a pas pu aboutir. Réessaie.'
          : message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Créer un compte',
      intro: 'Rejoins la communauté Trame.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_error != null)
                FormNotice(text: _error!, kind: FormNoticeKind.error),
              AuthField(
                label: 'Prénom',
                controller: _prenom,
                validator: (v) => validateApiName(v, label: 'prénom'),
                autofillHints: const [AutofillHints.givenName],
              ),
              AuthField(
                label: 'Nom',
                controller: _nom,
                validator: (v) => validateApiName(v, label: 'nom'),
                autofillHints: const [AutofillHints.familyName],
              ),
              AuthField(
                label: 'Adresse email',
                controller: _email,
                validator: validateEmail,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              AuthField(
                label: 'Mot de passe',
                controller: _password,
                validator: validateApiPassword,
                isPassword: true,
                helper: '12 caractères minimum, avec majuscule, minuscule, '
                    'chiffre et caractère spécial.',
                autofillHints: const [AutofillHints.newPassword],
              ),
              AuthField(
                label: 'Confirmer le mot de passe',
                controller: _confirmation,
                validator: (v) =>
                    // Vérifie que la confirmation est identique au mot de passe.
                    validatePasswordConfirmation(v, _password.text),
                isPassword: true,
                isLast: true,
                onSubmitted: _submit,
              ),
              const SizedBox(height: 8),
              SubmitButton(
                label: 'S’inscrire',
                isBusy: _busy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
