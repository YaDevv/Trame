import 'package:flutter/material.dart';

import '../widgets/auth_form.dart';
import 'forum_api.dart';

/// Longueur maximale d'un titre (limite de la base).
const _titleMax = 50;

/// Nouveau message : seuls le titre et le texte partent vers l'API.
/// L'auteur est deduit du jeton par le serveur. Renvoie true si publie.
class DemoComposeScreen extends StatefulWidget {
  const DemoComposeScreen({super.key, required this.api, required this.token});

  final ForumApi api;
  final String token;

  @override
  State<DemoComposeScreen> createState() => _DemoComposeScreenState();
}

class _DemoComposeScreenState extends State<DemoComposeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titre = TextEditingController();
  final _contenu = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _titre.dispose();
    _contenu.dispose();
    super.dispose();
  }

  // Clic sur « Publier ».
  Future<void> _publish() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      // On envoie seulement le titre et le contenu : l'API ajoute elle-même
      // l'auteur (d'après le jeton) et la date.
      await widget.api.createMessage(
        titre: _titre.text,
        contenu: _contenu.text,
        token: widget.token,
      );
      // Succès : on ferme l'écran en renvoyant true à DemoShell, qui recharge l'accueil.
      if (mounted) Navigator.of(context).pop(true);
    } on ValidationException catch (e) {
      _showError(e.messages.values.where((m) => m.isNotEmpty).join('\n'));
    } on UnauthorizedException {
      _showError('Ta session a expiré. Reconnecte-toi, puis réessaie.');
    } catch (_) {
      _showError(
        'Ton message n’a pas pu être publié. Vérifie ta connexion '
        'internet, puis réessaie.',
      );
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message.isEmpty
          ? 'Ton message n’a pas pu être publié. Réessaie.'
          : message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: false,
        title: const Text('Nouveau message'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (_error != null)
              FormNotice(text: _error!, kind: FormNoticeKind.error),
            TextFormField(
              controller: _titre,
              // Limite de 50 caractères, avec un compteur sous le champ.
              maxLength: _titleMax,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Titre'),
              // Le titre est obligatoire.
              validator: (value) {
                final text = value?.trim() ?? '';
                if (text.isEmpty) return 'Donne un titre à ton message.';
                if (text.length > _titleMax) {
                  return '$_titleMax caractères au maximum.';
                }
                return null;
              },
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _contenu,
              minLines: 6,
              maxLines: 12,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Votre message',
                alignLabelWithHint: true,
              ),
              // Le message est obligatoire.
              validator: (value) => (value?.trim() ?? '').isEmpty
                  ? 'Écris ton message.'
                  : null,
            ),
            const SizedBox(height: 20),
            SubmitButton(label: 'Publier', isBusy: _busy, onPressed: _publish),
          ],
        ),
      ),
    );
  }
}
