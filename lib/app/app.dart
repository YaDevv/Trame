import 'package:flutter/material.dart';

import '../core/app_scope.dart';
import '../core/forum_events.dart';
import '../core/session.dart';
import '../repositories/auth_repository.dart';
import '../repositories/discussion_repository.dart';
import 'main_shell.dart';
import 'theme.dart';

class ForumApp extends StatefulWidget {
  const ForumApp({
    super.key,
    required this.discussions,
    required this.auth,
    required this.session,
  });

  final DiscussionRepository discussions;
  final AuthRepository auth;
  final SessionController session;

  @override
  State<ForumApp> createState() => _ForumAppState();
}

class _ForumAppState extends State<ForumApp> {
  final _events = ForumEvents();

  @override
  void dispose() {
    _events.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AppScope(
      discussions: widget.discussions,
      auth: widget.auth,
      events: _events,
      child: SessionScope(
        notifier: widget.session,
        child: MaterialApp(
          title: 'Trame',
          debugShowCheckedModeBanner: false,
          theme: buildAppTheme(),
          home: MainShell(discussions: widget.discussions, auth: widget.auth),
        ),
      ),
    );
  }
}
