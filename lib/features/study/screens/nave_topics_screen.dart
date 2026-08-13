import 'package:echo_bible/core/database/bundled_database.dart';
import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:echo_bible/features/settings/screens/download_manager_screen.dart';
import 'package:echo_bible/features/study/models/nave_topic.dart';
import 'package:echo_bible/features/study/repositories/nave_repository.dart';
import 'package:echo_bible/shared/widgets/empty_resource_state.dart';
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
  late Future<List<NaveTopic>> _results;

  @override
  void initState() {
    super.initState();
    final initialQuery = widget.initialQuery?.trim() ?? '';
    _controller.text = initialQuery;
    _results = initialQuery.isEmpty
        ? _repository.browse()
        : _repository.search(initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() => setState(() {
        _results = _repository.search(_controller.text);
      });

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Bible thématique Nave')),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _controller,
                onChanged: (_) => _search(),
                onSubmitted: (_) => _search(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: 'Rechercher un thème...',
                  hintText: 'Foi, Prière, Mariage, Grâce…',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    onPressed: _search,
                    icon: const Icon(Icons.search),
                  ),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<NaveTopic>>(
                future: _results,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return _resourceError(context, snapshot.error);
                  }
                  final topics = snapshot.data ?? const [];
                  if (topics.isEmpty) {
                    return const _NaveMessage('Aucun thème trouvé.');
                  }
                  return ListView.separated(
                    itemCount: topics.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) => ListTile(
                      title: Text(topics[index].title),
                      subtitle: topics[index].isTranslated
                          ? Text(topics[index].titleEnglish)
                          : null,
                      leading: const Icon(Icons.hub_outlined),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              NaveTopicDetailScreen(topic: topics[index]),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      );
}

class NaveTopicDetailScreen extends StatelessWidget {
  final NaveTopic topic;
  const NaveTopicDetailScreen({super.key, required this.topic});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(topic.title)),
        body: FutureBuilder<List<NaveReference>>(
          future: const NaveRepository().references(topic.id),
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _resourceError(context, snapshot.error);
            }
            final refs = snapshot.data ?? const [];
            if (refs.isEmpty) {
              return const _NaveMessage('Aucune référence disponible.');
            }
            final groups = <int, List<NaveReference>>{};
            for (final ref in refs) {
              (groups[ref.subtopicId] ??= []).add(ref);
            }
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Source : Nave's Topical Bible",
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (topic.isTranslated)
                        Text(
                          'Original anglais : ${topic.titleEnglish}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
                ...groups.values.map((items) => ExpansionTile(
                      initiallyExpanded: groups.length < 5,
                      title: Row(
                        children: [
                          Expanded(child: Text(items.first.subtopic)),
                          if (items.first.subtopic ==
                              items.first.subtopicEnglish)
                            const Padding(
                              padding: EdgeInsets.only(left: 8),
                              child: Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text('EN'),
                              ),
                            ),
                        ],
                      ),
                      children: items.map((ref) {
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
                    )),
              ],
            );
          },
        ),
      );
}

Widget _resourceError(BuildContext context, Object? error) =>
    EmptyResourceState(
      icon: error is ResourceNotInstalledException
          ? Icons.download_for_offline_outlined
          : Icons.error_outline,
      message: error is ResourceNotInstalledException
          ? 'Nave n’est pas installé.'
          : 'Impossible de charger les thèmes de Nave.',
      actionLabel: 'Télécharger',
      onAction: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DownloadManagerScreen(
            initialCategory: ResourceCategory.nave,
          ),
        ),
      ),
    );

class _NaveMessage extends StatelessWidget {
  final String text;
  const _NaveMessage(this.text);

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(text, textAlign: TextAlign.center),
        ),
      );
}
