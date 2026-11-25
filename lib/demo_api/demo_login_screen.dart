import 'package:flutter/material.dart';

import '../core/validators.dart';
import '../widgets/auth_form.dart';
import 'demo_register_screen.dart';
import 'demo_session.dart';
import 'forum_api.dart';

/// Connexion a l'API : POST /api/authentication_token renvoie un JWT.
class DemoLoginScreen extends StatefulWidget {
  const DemoLoginScreen({super.key, required this.api, required this.session});

  final ForumApi api;
  final DemoSession session;

  @override
  State<DemoLoginScreen> createState() => _DemoLoginScreenState();
}

class _DemoLoginScreenState extends State<DemoLoginScreen> {
  // Clé du formulaire : permet de lancer validate() sur tous les champs.
  final _formKey = GlobalKey<FormState>();
  // Contrôleurs : ils contiennent le texte tapé dans chaque champ.
  final _email = TextEditingController();
  final _password = TextEditingController();
  // true pendant l'envoi : le bouton affiche un chargement et ne peut pas être recliqué.
  bool _busy = false;
  String? _error;
  String? _info;

  @override
  void initState() {
    super.initState();
    // Message laissé par la session (ex. « Tu es déconnecté »).
    _info = widget.session.notice;
  }

  // Libère les contrôleurs quand l'écran est détruit.
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  // Clic sur « Se connecter ».
  Future<void> _submit() async {
    // On s'arrête si un envoi est déjà en cours ou si un champ est invalide.
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      // Appel à l'API (voir forum_api.dart) ; await attend la réponse.
      final session = await widget.api.login(
        email: _email.text,
        password: _password.text,
      );
      // L'ecran du compte remplace celui-ci (voir DemoApp).
      widget.session.signIn(session);
    // Chaque type d'erreur donne un message compréhensible.
    } on InvalidCredentialsException {
      _showError('Adresse email ou mot de passe incorrect.');
    } on ApiUnavailableException {
      _showError(
        'Connexion impossible pour le moment. Vérifie ta connexion '
        'internet, puis réessaie.',
      );
    }
  }

  // Affiche l'erreur et réactive le bouton.
  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  // Ouvre l'inscription. Si le compte est créé, elle renvoie l'email
  // pour pré-remplir le champ de connexion.
  Future<void> _openRegister() async {
    final email = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => DemoRegisterScreen(api: widget.api)),
    );
    if (email == null || !mounted) return;
    setState(() {
      _email.text = email;
      _password.clear();
      _error = null;
      _info = 'Ton compte est créé. Connecte-toi avec ton mot de passe.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Connexion',
      intro: 'Connecte-toi pour publier et participer aux discussions.',
      footer: AuthSwitchLink(
        question: 'Pas encore de compte ?',
        action: 'Créer un compte',
        onPressed: _openRegister,
      ),
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_error != null)
                FormNotice(text: _error!, kind: FormNoticeKind.error),
              if (_info != null)
                FormNotice(text: _info!, kind: FormNoticeKind.info),
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
                validator: validateRequiredPassword,
                isPassword: true,
                isLast: true,
                autofillHints: const [AutofillHints.password],
                onSubmitted: _submit,
              ),
              const SizedBox(height: 8),
              SubmitButton(
                label: 'Se connecter',
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
