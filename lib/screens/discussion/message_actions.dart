import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/validators.dart';
import '../../models/message.dart';

enum MessageAction { edit, delete }

/// Menu « ⋯ » d'un message de l'utilisateur connecte.
Future<MessageAction?> showMessageActions(BuildContext context) {
  return showModalBottomSheet<MessageAction>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: AppColors.ink),
            title: const Text('Modifier'),
            onTap: () => Navigator.of(sheetContext).pop(MessageAction.edit),
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.danger),
            title: const Text(
              'Supprimer',
              style: TextStyle(color: AppColors.danger),
            ),
            onTap: () => Navigator.of(sheetContext).pop(MessageAction.delete),
          ),
          const SizedBox(height: 8),
        ],
      ),
    ),
  );
}

/// Demande confirmation avant une suppression ; true si confirmee.
Future<bool> confirmMessageDeletion(
  BuildContext context, {
  required bool isOpening,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(
        isOpening
            ? 'Supprimer ta discussion\u00a0?'
            : 'Supprimer ce message\u00a0?',
      ),
      content: Text(
        isOpening
            ? 'Ton titre et ton message ne seront plus visibles. Les réponses '
                  'restent affichées, sous la mention '
                  '«\u00a0Discussion supprimée par l’utilisateur\u00a0». '
                  'Tu ne pourras pas revenir en arrière.'
            : 'Ton message ne sera plus visible. À sa place, tout le monde '
                  'verra la mention '
                  '«\u00a0Message supprimé par l’utilisateur\u00a0». '
                  'Tu ne pourras pas revenir en arrière.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Annuler'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Supprimer'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

/// Ouvre le formulaire de modification, prerempli avec le texte actuel.
/// [onSave] enregistre ; le message modifie est renvoye, ou null si
/// l'utilisateur annule ou ne change rien.
Future<Message?> showEditMessageSheet(
  BuildContext context, {
  required String initialContent,
  required bool isOpening,
  required Future<Message> Function(String content) onSave,
}) {
  return showModalBottomSheet<Message>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => EditMessageSheet(
      initialContent: initialContent,
      isOpening: isOpening,
      onSave: onSave,
    ),
  );
}

class EditMessageSheet extends StatefulWidget {
  const EditMessageSheet({
    super.key,
    required this.initialContent,
    required this.isOpening,
    required this.onSave,
  });

  final String initialContent;
  final bool isOpening;
  final Future<Message> Function(String content) onSave;

  @override
  State<EditMessageSheet> createState() => _EditMessageSheetState();
}

class _EditMessageSheetState extends State<EditMessageSheet> {
  late final _controller = TextEditingController(text: widget.initialContent);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final text = _controller.text.trim();
    // Memes regles qu'a l'ecriture : ecran Ecrire ou barre de reponse.
    final error = widget.isOpening
        ? validateOpeningContent(text)
        : validateReplyContent(text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final navigator = Navigator.of(context);
    if (text == widget.initialContent.trim()) {
      navigator.pop();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await widget.onSave(text);
      if (!mounted) return;
      navigator.pop(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'La modification n’a pas pu être enregistrée. Réessaie.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      // Le formulaire remonte au-dessus du clavier.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.isOpening ? 'Modifier ton message' : 'Modifier ta réponse',
                style: threadTitleStyle.copyWith(fontSize: 20),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _controller,
                autofocus: true,
                enabled: !_saving,
                minLines: 4,
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: AppColors.ink,
                ),
                decoration: InputDecoration(
                  errorText: _error,
                  errorMaxLines: 2,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: _saving ? null : () => Navigator.of(context).pop(),
                      child: const Text('Annuler'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      onPressed: _saving ? null : _save,
                      style: FilledButton.styleFrom(
                        shape: const StadiumBorder(),
                      ),
                      child: _saving
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Enregistrer'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
