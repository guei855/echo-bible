import 'package:echo_bible/features/bible/data/database/database_helper.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';

class BibleLocalDatasource {
  Future<List<BibleBook>> getBooks() async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.query('books');

    return result.map((map) => BibleBook.fromMap(map)).toList();
  }
}
