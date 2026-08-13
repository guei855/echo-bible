class ChapterCache {
  static final ChapterCache instance = ChapterCache._internal();
  ChapterCache._internal();

  final Map<String, List<Map<String, dynamic>>> _versesCache = {};
  final Map<String, Map<int, String>> _highlightsCache = {};

  bool hasChapter(int bookId, int chapter) {
    return _versesCache.containsKey('${bookId}_$chapter');
  }

  List<Map<String, dynamic>>? getVerses(int bookId, int chapter) {
    return _versesCache['${bookId}_$chapter'];
  }

  Map<int, String>? getHighlights(int bookId, int chapter) {
    return _highlightsCache['${bookId}_$chapter'];
  }

  void setChapterData(int bookId, int chapter,
      List<Map<String, dynamic>> verses, Map<int, String> highlights) {
    _versesCache['${bookId}_$chapter'] = verses;
    _highlightsCache['${bookId}_$chapter'] = highlights;
  }

  void invalidateChapter(int bookId, int chapter) {
    _versesCache.remove('${bookId}_$chapter');
    _highlightsCache.remove('${bookId}_$chapter');
  }

  void clear() {
    _versesCache.clear();
    _highlightsCache.clear();
  }
}
