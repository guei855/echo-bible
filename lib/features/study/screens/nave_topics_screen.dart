import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:echo_bible/features/study/models/nave_topic.dart';
import 'package:echo_bible/features/study/repositories/nave_repository.dart';
import 'package:flutter/material.dart';

class NaveTopicsScreen extends StatefulWidget {
  final String? initialQuery;
  const NaveTopicsScreen({super.key, this.initialQuery});
  @override
  State<NaveTopicsScreen> createState() => _NaveTopicsScreenState();
}

class _NaveTopicsScreenState extends State<NaveTopicsScreen> {
  final _controller = TextEditingController();
  final _repository = const NaveRepository();
  Future<List<NaveTopic>>? _results;

  @override
  void initState() {
    super.initState();
    if (widget.initialQuery?.isNotEmpty ?? false) {
      _controller.text = widget.initialQuery!;
      _results = _repository.search(widget.initialQuery!);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final data = await _repository.search(_controller.text);
    if (!mounted) return;
    final results = Future.value(data);
    setState(() {
      _results = results;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Bible thématique Nave')),
      body: Column(children: [
        Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
                controller: _controller,
                onSubmitted: (_) => _search(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                    labelText: 'Rechercher un thème',
                    hintText: 'Foi, Prière, Mariage, Grâce…',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                        onPressed: _search, icon: const Icon(Icons.search))))),
        Expanded(
            child: _results == null
                ? const _NaveMessage('Recherchez parmi les thèmes de Nave.')
                : FutureBuilder<List<NaveTopic>>(
                    future: _results,
                    builder: (context, snap) {
                      if (snap.connectionState != ConnectionState.done) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final topics = snap.data ?? const [];
                      if (topics.isEmpty) {
                        return const _NaveMessage('Aucun thème trouvé.');
                      }
                      return ListView.separated(
                          itemCount: topics.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) => ListTile(
                              title: Text(topics[i].title),
                              leading: const Icon(Icons.hub_outlined),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (_) => NaveTopicDetailScreen(
                                          topic: topics[i])))));
                    }))
      ]));
}

class NaveTopicDetailScreen extends StatelessWidget {
  final NaveTopic topic;
  const NaveTopicDetailScreen({super.key, required this.topic});
  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: Text(topic.title)),
      body: FutureBuilder<List<NaveReference>>(
          future: const NaveRepository().references(topic.id),
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final refs = snap.data ?? const [];
            if (refs.isEmpty) {
              return const _NaveMessage('Aucune référence disponible.');
            }
            final groups = <int, List<NaveReference>>{};
            for (final ref in refs) {
              (groups[ref.subtopicId] ??= []).add(ref);
            }
            return ListView(
              children: groups.values.map<Widget>((items) {
                return ExpansionTile(
                  initiallyExpanded: groups.length < 5,
                  title: Text(items.first.subtopic),
                  children: items.map<Widget>((ref) {
                    return ListTile(
                      leading: const Icon(Icons.menu_book_outlined),
                      title: Text(
                        '${ref.bookName} ${ref.chapter}:${ref.verseStart}'
                        '${ref.verseEnd == null ? '' : '-${ref.verseEnd}'}',
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChapterReaderScreen(
                            book: BibleBook(
                              id: ref.bookId,
                              name: ref.bookName,
                              abbreviation: '',
                              testament: '',
                              chaptersCount: ref.chaptersCount,
                            ),
                            initialChapter: ref.chapter,
                            initialVerse: ref.verseStart,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              }).toList(),
            );
          }));
}

class _NaveMessage extends StatelessWidget {
  final String text;
  const _NaveMessage(this.text);
  @override
  Widget build(BuildContext context) => Center(
      child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center)));
}
