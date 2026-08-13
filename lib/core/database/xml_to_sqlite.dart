import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseInitializer {
  static Future<void> initialize() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'bible.db');

    // En développement : on supprime l'ancienne base pour forcer la copie à chaque hot restart/relancement
    if (await databaseExists(path)) {
      await deleteDatabase(path);
    }

    try {
      await Directory(dirname(path)).create(recursive: true);

      ByteData data = await rootBundle.load('assets/database/bible.db');

      await File(path).writeAsBytes(
        data.buffer.asUint8List(),
        flush: true,
      );
    } catch (_) {
      // Gestion des erreurs de copie silencieuses ou loggées
    }
  }
}
