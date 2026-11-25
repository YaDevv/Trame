import 'package:flutter/material.dart';

import 'app/app.dart';
import 'core/session.dart';
import 'repositories/demo/demo_auth_repository.dart';
import 'repositories/demo/demo_discussion_repository.dart';

void main() {
  runApp(
    ForumApp(
      // Les deux seules lignes a changer pour brancher la vraie API.
      discussions: DemoDiscussionRepository(),
      auth: DemoAuthRepository(),
      session: SessionController(),
    ),
  );
}
