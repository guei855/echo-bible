import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

class VerseActionService {
  static Future<void> copyVerse(
      String bookName, int chapter, int verseNumber, String text) async {
    final formattedText = '« $text »\n$bookName $chapter:$verseNumber';
    await Clipboard.setData(ClipboardData(text: formattedText));
  }

  static Future<void> copyText(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  static Future<void> shareVerse(
      String bookName, int chapter, int verseNumber, String text) async {
    final formattedText =
        '« $text »\n$bookName $chapter:$verseNumber\n\nPartagé via Echo Bible';
    await Share.share(formattedText);
  }

  static Future<void> shareText(String text) async {
    await Share.share(text);
  }
}
