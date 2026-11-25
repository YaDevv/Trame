import 'package:flutter/material.dart';

import '../../core/validators.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/auth_form.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirmation = TextEditingController();
  bool _isBusy = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isBusy || !_formKey.currentState!.validate()) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      await widget.auth.register(
        username: _username.text,
        email: _email.text,
        password: _password.text,
      );
      if (!mounted) return;
      // Retour a la connexion, qui pre-remplit l'email.
      Navigator.of(context).pop(_email.text.trim());
    } on EmailAlreadyUsedException {
      _fail('Cette adresse email a déjà un compte. Connecte-toi plutôt.');
    } on UsernameAlreadyUsedException {
      _fail('Ce pseudo est déjà pris. Choisis-en un autre.');
    } catch (_) {
      _fail('Inscription impossible. Vérifie ton réseau, puis réessaie.');
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Créer un compte',
      intro: 'Choisis un pseudo : c’est lui qui signera tes messages.',
      footer: AuthSwitchLink(
        question: 'Déjà un compte ?',
        action: 'Se connecter',
        onPressed: () => Navigator.of(context).pop(),
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_error != null)
                FormNotice(text: _error!, kind: FormNoticeKind.error),
              AuthField(
                label: 'Pseudo',
                controller: _username,
                validator: validateUsername,
                autofillHints: const [AutofillHints.newUsername],
                              ),
              AuthField(
                label: 'Email',
                controller: _email,
                validator: validateEmail,
                keyboardType: TextInputType.emailAddress,
                autofillHints: const [AutofillHints.email],
              ),
              AuthField(
                label: 'Mot de passe',
                controller: _password,
                validator: validateNewPassword,
                autofillHints: const [AutofillHints.newPassword],
                helper: 'Au moins 10 caractères, avec une lettre et un chiffre.',
                isPassword: true,
              ),
              AuthField(
                label: 'Confirmation du mot de passe',
                controller: _confirmation,
                validator: (value) =>
                    validatePasswordConfirmation(value, _password.text),
                autofillHints: const [AutofillHints.newPassword],
                isPassword: true,
                isLast: true,
                onSubmitted: _submit,
              ),
              const SizedBox(height: 8),
              SubmitButton(
                label: 'Créer mon compte',
                isBusy: _isBusy,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
