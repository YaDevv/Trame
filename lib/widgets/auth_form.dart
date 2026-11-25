import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Cadre des ecrans de compte : contenu centre, lien de bascule en bas,
/// et le logo suspendu a son fil, comme le reste de l'application.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.child,
    this.intro,
    this.footer,
  });

  final String title;
  final String? intro;
  final Widget child;

  /// Sous le formulaire, par exemple "Pas encore de compte ?".
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    // Dans un onglet, pas de barre de retour.
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Scaffold(
      // La fleche de retour flotte au-dessus du contenu : le centrage se
      // calcule sur tout l'ecran, comme pour la connexion.
      extendBodyBehindAppBar: true,
      appBar: canPop
          ? AppBar(toolbarHeight: 44, backgroundColor: Colors.transparent)
          : null,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            child: ConstrainedBox(
              // Hauteur minimale = ecran : le formulaire reste centre,
              // et la page defile quand le clavier s'ouvre.
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              // Un peu au-dessus du centre exact : c'est le centre optique,
              // celui que l'oeil percoit comme le milieu de l'ecran.
              child: Align(
                alignment: Alignment(0, canPop ? -0.85 : -0.2),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: Padding(
                    // Marge en haut : la fleche de retour ne chevauche
                    // jamais le contenu.
                    padding: EdgeInsets.fromLTRB(24, canPop ? 48 : 16, 24, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _HangingLogo(),
                        const SizedBox(height: 18),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: threadTitleStyle.copyWith(fontSize: 24),
                        ),
                        if (intro != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            intro!,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              height: 1.4,
                              color: AppColors.inkSoft,
                            ),
                          ),
                        ],
                        const SizedBox(height: 24),
                        child,
                        if (footer != null) ...[
                          const SizedBox(height: 12),
                          footer!,
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "Trame" pend au bout de son fil, avec le noeud ocre.
class _HangingLogo extends StatelessWidget {
  const _HangingLogo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CustomPaint(
          size: const Size(16, 36),
          painter: const _ThreadDropPainter(),
        ),
        const SizedBox(height: 6),
        Text('Trame', style: logoStyle.copyWith(fontSize: 36)),
      ],
    );
  }
}

class _ThreadDropPainter extends CustomPainter {
  const _ThreadDropPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final x = size.width / 2;
    canvas.drawLine(
      Offset(x, 0),
      Offset(x, size.height - 8),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppColors.primary.withValues(alpha: 0),
            AppColors.primary,
          ],
        ).createShader(Offset.zero & size)
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      Offset(x, size.height - 6),
      6,
      Paint()..color = AppColors.accent,
    );
  }

  @override
  bool shouldRepaint(_ThreadDropPainter oldDelegate) => false;
}

class AuthField extends StatefulWidget {
  const AuthField({
    super.key,
    required this.label,
    required this.controller,
    required this.validator,
    this.keyboardType,
    this.autofillHints,
    this.helper,
    this.isPassword = false,
    this.isLast = false,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final String? helper;
  final bool isPassword;
  final bool isLast;
  final VoidCallback? onSubmitted;

  @override
  State<AuthField> createState() => _AuthFieldState();
}

class _AuthFieldState extends State<AuthField> {
  bool _obscured = true;

  IconData get _icon {
    if (widget.isPassword) return Icons.lock_outline;
    if (widget.keyboardType == TextInputType.emailAddress) {
      return Icons.mail_outline;
    }
    return Icons.person_outline;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: widget.controller,
        validator: widget.validator,
        autovalidateMode: AutovalidateMode.onUnfocus,
        keyboardType: widget.keyboardType,
        autofillHints: widget.autofillHints,
        autocorrect: false,
        enableSuggestions: !widget.isPassword,
        obscureText: widget.isPassword && _obscured,
        textInputAction:
            widget.isLast ? TextInputAction.done : TextInputAction.next,
        onFieldSubmitted: (_) => widget.onSubmitted?.call(),
        style: const TextStyle(fontSize: 15, color: AppColors.ink),
        decoration: InputDecoration(
          // Le libelle sert de texte d'aide dans le champ, comme dans
          // les applications mobiles, et reste lu par les lecteurs d'ecran.
          labelText: widget.label,
          floatingLabelBehavior: FloatingLabelBehavior.never,
          labelStyle: const TextStyle(fontSize: 15, color: AppColors.inkSoft),
          prefixIcon: Icon(_icon, size: 20, color: AppColors.inkSoft),
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
          border: _pill(AppColors.border),
          enabledBorder: _pill(AppColors.border),
          focusedBorder: _pill(AppColors.primary, 1.5),
          errorBorder: _pill(AppColors.danger),
          focusedErrorBorder: _pill(AppColors.danger, 1.5),
          helperText: widget.helper,
          helperMaxLines: 2,
          errorMaxLines: 2,
          suffixIcon: widget.isPassword
              ? IconButton(
                  tooltip: _obscured
                      ? 'Afficher le mot de passe'
                      : 'Masquer le mot de passe',
                  onPressed: () => setState(() => _obscured = !_obscured),
                  icon: Icon(
                    _obscured
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 20,
                  ),
                )
              : null,
        ),
      ),
    );
  }

  OutlineInputBorder _pill(Color color, [double width = 1]) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

enum FormNoticeKind { error, info }

class FormNotice extends StatelessWidget {
  const FormNotice({super.key, required this.text, required this.kind});

  final String text;
  final FormNoticeKind kind;

  @override
  Widget build(BuildContext context) {
    final isError = kind == FormNoticeKind.error;
    final color = isError ? AppColors.danger : AppColors.primary;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle_outline,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, height: 1.35, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class SubmitButton extends StatelessWidget {
  const SubmitButton({
    super.key,
    required this.label,
    required this.isBusy,
    required this.onPressed,
  });

  final String label;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: FilledButton(
        onPressed: isBusy ? null : onPressed,
        style: FilledButton.styleFrom(
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
        child: isBusy
            ? const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(label),
      ),
    );
  }
}

/// Bas d'ecran : "Pas encore de compte ? S'inscrire".
class AuthSwitchLink extends StatelessWidget {
  const AuthSwitchLink({
    super.key,
    required this.question,
    required this.action,
    required this.onPressed,
  });

  final String question;
  final String action;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          question,
          style: const TextStyle(fontSize: 14, color: AppColors.inkSoft),
        ),
        TextButton(onPressed: onPressed, child: Text(action)),
      ],
    );
  }
}
