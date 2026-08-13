import 'package:echo_bible/features/bible/data/datasource/bible_local_datasource.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';

class BibleRepository {
  final BibleLocalDatasource _datasource = BibleLocalDatasource();

  Future<List<BibleBook>> getBooks() async {
    return await _datasource.getBooks();
  }
}
