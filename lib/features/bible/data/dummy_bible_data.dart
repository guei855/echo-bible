import 'package:echo_bible/features/bible/models/verse.dart';

class DummyBibleData {
  static final List<Verse> johnChapter3 = [
    Verse(
      id: 1,
      bookId: 43,
      chapterNumber: 3,
      verseNumber: 1,
      text:
          "Il y eut un homme d'entre les pharisiens, nommé Nicodème, chef des Juifs,",
    ),
    Verse(
      id: 2,
      bookId: 43,
      chapterNumber: 3,
      verseNumber: 2,
      text:
          "Il vint de nuit auprès de Jésus, et lui dit: Rabbi, nous savons que tu es un docteur venu de Dieu; car personne ne peut faire ces miracles que tu fais, si Dieu n'est avec lui.",
    ),
    Verse(
      id: 3,
      bookId: 43,
      chapterNumber: 3,
      verseNumber: 3,
      text:
          "Jésus lui répondit: En vérité, en vérité, je te le dis, si un homme ne naît de nouveau, il ne peut voir le royaume de Dieu.",
    ),
    Verse(
      id: 4,
      bookId: 43,
      chapterNumber: 3,
      verseNumber: 4,
      text:
          "Nicodème lui dit: Comment un homme peut-il naître quand il est vieux? Peut-il rentrer dans le sein de sa mère et naître?",
    ),
  ];
}
