import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../core/validators.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/auth_form.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.auth});

  final AuthRepository auth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _isBusy = false;
  String? _error;
  String? _notice;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isBusy || !_formKey.currentState!.validate()) return;
    final session = SessionScope.of(context);
    final navigator = Navigator.of(context);

    setState(() {
      _isBusy = true;
      _error = null;
      _notice = null;
    });
    try {
      final user = await widget.auth.signIn(
        email: _email.text,
        password: _password.text,
      );
      session.signIn(user);
      // Ouverte depuis une discussion : on y revient. Dans l'onglet : rien.
      if (navigator.canPop()) navigator.pop();
    } on InvalidCredentialsException {
      _fail('Email ou mot de passe incorrect.');
    } catch (_) {
      _fail('Connexion impossible. Vérifie ton réseau, puis réessaie.');
    }
  }

  Future<void> _openRegister() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => RegisterScreen(auth: widget.auth)),
    );
    if (!mounted || email == null) return;
    setState(() {
      _email.text = email;
      _password.clear();
      _error = null;
      _notice = 'Compte créé. Connecte-toi pour participer.';
    });
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
      title: 'Connexion',
      intro: 'Connecte-toi pour publier et répondre.',
      footer: AuthSwitchLink(
        question: 'Pas encore de compte ?',
        action: "S'inscrire",
        onPressed: _openRegister,
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_notice != null)
                FormNotice(text: _notice!, kind: FormNoticeKind.info),
              if (_error != null)
                FormNotice(text: _error!, kind: FormNoticeKind.error),
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
                validator: validateRequiredPassword,
                autofillHints: const [AutofillHints.password],
                isPassword: true,
                isLast: true,
                onSubmitted: _submit,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ForgotPasswordScreen(
                        auth: widget.auth,
                        initialEmail: _email.text,
                      ),
                    ),
                  ),
                  child: const Text('Mot de passe oublié ?'),
                ),
              ),
              const SizedBox(height: 8),
              SubmitButton(
                label: 'Se connecter',
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
