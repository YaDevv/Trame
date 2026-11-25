import 'package:flutter/material.dart';

import '../../core/validators.dart';
import '../../repositories/auth_repository.dart';
import '../../widgets/auth_form.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.auth,
    this.initialEmail,
  });

  final AuthRepository auth;
  final String? initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _isBusy = false;
  String? _notice;
  FormNoticeKind _noticeKind = FormNoticeKind.info;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isBusy || !_formKey.currentState!.validate()) return;
    setState(() {
      _isBusy = true;
      _notice = null;
    });
    try {
      await widget.auth.requestPasswordReset(email: _email.text);
      // Meme message dans tous les cas : ne revele pas si le compte existe.
      _show(
        'Si un compte existe avec cette adresse, un lien de réinitialisation '
        'vient de lui être envoyé.',
        FormNoticeKind.info,
      );
    } on FeatureUnavailableException {
      _show(
        "L'envoi du lien n'est pas encore disponible : le serveur du forum "
        "n'est pas connecté. Aucun email n'a été envoyé.",
        FormNoticeKind.error,
      );
    } catch (_) {
      _show(
        "Le lien n'a pas pu être envoyé. Vérifie ton réseau, puis réessaie.",
        FormNoticeKind.error,
      );
    }
  }

  void _show(String message, FormNoticeKind kind) {
    if (!mounted) return;
    setState(() {
      _isBusy = false;
      _notice = message;
      _noticeKind = kind;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      title: 'Mot de passe oublié',
      intro: 'Saisis ton email pour recevoir un lien de réinitialisation.',
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            if (_notice != null) FormNotice(text: _notice!, kind: _noticeKind),
            AuthField(
              label: 'Email',
              controller: _email,
              validator: validateEmail,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              isLast: true,
              onSubmitted: _submit,
            ),
            const SizedBox(height: 8),
            SubmitButton(
              label: 'Envoyer le lien',
              isBusy: _isBusy,
              onPressed: _submit,
            ),
          ],
        ),
      ),
    );
  }
}
