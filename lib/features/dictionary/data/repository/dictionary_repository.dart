import 'package:echo_bible/features/dictionary/models/dictionary_entry.dart';
import 'package:echo_bible/features/dictionary/services/dictionary_database_service.dart';

class DictionaryRepository {
  const DictionaryRepository();

  Future<bool> isAvailable() async =>
      await DictionaryDatabaseService.database != null;

  Future<List<DictionaryEntry>> search(
    String value, {
    int limit = 100,
  }) async {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) return const [];
    final database = await DictionaryDatabaseService.database;
    if (database == null) return const [];
    final rows = await database.query(
      'dictionary_entries',
      where: 'normalized_title LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'title',
      limit: limit,
    );
    return rows.map(DictionaryEntry.fromMap).toList();
  }
}
