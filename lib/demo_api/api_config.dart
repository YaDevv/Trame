/// Adresse de l'API Symfony `forum` (sans le /api final).
/// Modifiable au lancement : --dart-define=FORUM_API_URL=https://...
// String.fromEnvironment lit une valeur passée au lancement ;
// si rien n'est passé, on utilise defaultValue.
const forumApiBaseUrl = String.fromEnvironment(
  'FORUM_API_URL',
  defaultValue: 'https://4534.s3.nuage-peda.fr/forum',
);
