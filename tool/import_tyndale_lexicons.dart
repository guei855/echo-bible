import 'dart:io';

/// The former importer wrote lexical rows into `bible.db`. That behavior is
/// intentionally disabled so the Bible and user data can never be replaced.
void main() {
  stderr.writeln(
    'Utilisez : python bible_builder/build_strong_db.py\n'
    'Le générateur écrit uniquement assets/database/strong.db et crée une '
    'sauvegarde préalable.',
  );
  exitCode = 64;
}
