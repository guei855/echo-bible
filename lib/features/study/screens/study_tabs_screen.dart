import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:echo_bible/features/bible/screens/parallel_comparison_screen.dart';
import 'package:echo_bible/features/search/screens/concordance_screen.dart';
import 'package:echo_bible/features/study/models/study_tab.dart';
import 'package:echo_bible/features/study/screens/nave_topics_screen.dart';
import 'package:echo_bible/features/study/services/study_tab_manager.dart';
import 'package:flutter/material.dart';

class StudyTabsScreen extends StatefulWidget {
  const StudyTabsScreen({super.key});
  @override
  State<StudyTabsScreen> createState() => _StudyTabsScreenState();
}

class _StudyTabsScreenState extends State<StudyTabsScreen> {
  late Future<List<StudyTab>> _tabs = const StudyTabManager().load();
  Future<void> _reload() async {
    final data = await const StudyTabManager().load();
    if (!mounted) return;
    final tabs = Future.value(data);
    setState(() {
      _tabs = tabs;
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<StudyTab>>(
      future: _tabs,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final tabs = snapshot.data!;
        if (tabs.isEmpty) {
          return Scaffold(
            appBar: AppBar(title: const Text('Onglets d’étude')),
            body: Center(
              child: FilledButton(
                onPressed: _reload,
                child: const Text('Restaurer les onglets de départ'),
              ),
            ),
          );
        }
        return DefaultTabController(
            length: tabs.length,
            child: Scaffold(
                appBar: AppBar(
                    title: const Text('Onglets d’étude'),
                    bottom: TabBar(
                        isScrollable: true,
                        tabs: tabs
                            .map((tab) => Tab(
                                    child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                      Text(tab.title),
                                      const SizedBox(width: 6),
                                      InkWell(
                                          onTap: () async {
                                            await const StudyTabManager()
                                                .close(tab.id);
                                            _reload();
                                          },
                                          child:
                                              const Icon(Icons.close, size: 16))
                                    ])))
                            .toList())),
                body: TabBarView(children: tabs.map(_screen).toList())));
      });

  Widget _screen(StudyTab tab) {
    switch (tab.type) {
      case 'strong':
        return ConcordanceScreen(
            initialTab: 1, initialQuery: tab.state['query'] as String?);
      case 'concordance':
        return ConcordanceScreen(initialQuery: tab.state['query'] as String?);
      case 'nave':
        return NaveTopicsScreen(initialQuery: tab.state['query'] as String?);
      case 'comparison':
        return FutureBuilder<BibleBook>(
            future: _book(tab.state['book'] as int),
            builder: (_, snap) => snap.hasData
                ? ParallelComparisonScreen(
                    book: snap.data!,
                    chapter: tab.state['chapter'] as int,
                    verse: tab.state['verse'] as int)
                : const Center(child: CircularProgressIndicator()));
      default:
        return FutureBuilder<BibleBook>(
            future: _book(tab.state['book'] as int),
            builder: (_, snap) => snap.hasData
                ? ChapterReaderScreen(
                    book: snap.data!,
                    initialChapter: tab.state['chapter'] as int)
                : const Center(child: CircularProgressIndicator()));
    }
  }

  Future<BibleBook> _book(int id) async {
    final db = await DatabaseService.database;
    final rows =
        await db.query('books', where: 'id=?', whereArgs: [id], limit: 1);
    return BibleBook.fromMap(rows.first);
  }
}
