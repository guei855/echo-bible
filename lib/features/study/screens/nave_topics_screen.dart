import 'package:echo_bible/core/database/bundled_database.dart';
import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:echo_bible/features/settings/screens/download_manager_screen.dart';
import 'package:echo_bible/features/study/models/nave_topic.dart';
import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/repositories/nave_repository.dart';
import 'package:echo_bible/features/study/screens/personal_study_editor_screen.dart';
import 'package:echo_bible/features/study/widgets/study_destination_sheet.dart';
import 'package:echo_bible/shared/widgets/empty_resource_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

typedef NaveStudyDestination = Future<PersonalStudy?> Function(
  BuildContext context,
  StudyBlock block,
);

class NaveTopicsScreen extends StatefulWidget {
  final String? initialQuery;
  final NaveRepository repository;
  const NaveTopicsScreen(
      {super.key, this.initialQuery, this.repository = const NaveRepository()});

  @override
  State<NaveTopicsScreen> createState() => _NaveTopicsScreenState();
}

class _NaveTopicsScreenState extends State<NaveTopicsScreen> {
  static const _letters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  final _controller = TextEditingController();
  late Future<List<NaveTopic>> _results;
  String? _letter;

  @override
  void initState() {
    super.initState();
    final initialQuery = widget.initialQuery?.trim() ?? '';
    _controller.text = initialQuery;
    _results = initialQuery.isEmpty
        ? widget.repository.browse()
        : widget.repository.search(initialQuery);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _search() {
    final query = _controller.text.trim();
    setState(() {
      _letter = null;
      _results = query.isEmpty
          ? widget.repository.browse()
          : widget.repository.search(query);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Bible thématique'),
              Text("Nave's Topical Bible",
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w400)),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                key: const Key('nave-search-field'),
                controller: _controller,
                onChanged: (_) => _search(),
                onSubmitted: (_) => _search(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Rechercher un thème...',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _controller.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: 'Effacer',
                          onPressed: () {
                            _controller.clear();
                            _search();
                          },
                          icon: const Icon(Icons.close),
                        ),
                ),
              ),
            ),
            if (_controller.text.trim().isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Résultats pour « ${_controller.text.trim()} »',
                    key: const Key('nave-search-context'),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
            SizedBox(
              height: 44,
              child: ListView(
                key: const Key('nave-alphabet-navigation'),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                children: [
                  for (final letter in _letters.split(''))
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: ChoiceChip(
                        label: Text(letter),
                        selected: _letter == letter,
                        onSelected: (selected) => setState(
                          () => _letter = selected ? letter : null,
                        ),
                      ),
                    ),
                ],
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
                  final allTopics = snapshot.data ?? const [];
                  final topics = _letter == null
                      ? allTopics
                      : allTopics
                          .where((topic) => widget.repository
                              .normalize(topic.title)
                              .toUpperCase()
                              .startsWith(_letter!))
                          .toList(growable: false);
                  if (topics.isEmpty) {
                    final query = _controller.text.trim();
                    return _NaveMessage(query.isEmpty
                        ? (_letter == null
                            ? 'Commencez à saisir un thème.'
                            : 'Aucun thème disponible pour cette lettre.')
                        : 'Aucun thème trouvé pour « $query »');
                  }
                  return ListView.separated(
                    itemCount: topics.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, index) {
                      final topic = topics[index];
                      return ListTile(
                        key: Key('nave-topic-${topic.id}'),
                        title: Text(topic.title.toUpperCase(),
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        subtitle: Text([
                          if (topic.isTranslated) topic.titleEnglish,
                          '${topic.sectionCount} sections · ${topic.referenceCount} références',
                          if (!topic.isTranslated) 'Non encore traduit',
                        ].join('\n')),
                        leading: const Icon(Icons.hub_outlined),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => NaveTopicDetailScreen(
                                    topic: topic,
                                    repository: widget.repository,
                                  )),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
}

class NaveTopicDetailScreen extends StatefulWidget {
  final NaveTopic topic;
  final NaveRepository repository;
  final ValueChanged<NaveReference>? onOpenReference;
  final NaveStudyDestination? studyDestination;
  final ValueChanged<PersonalStudy>? onStudyOpened;
  const NaveTopicDetailScreen({
    super.key,
    required this.topic,
    this.repository = const NaveRepository(),
    this.onOpenReference,
    this.studyDestination,
    this.onStudyOpened,
  });

  @override
  State<NaveTopicDetailScreen> createState() => _NaveTopicDetailScreenState();
}

class _NaveTopicDetailScreenState extends State<NaveTopicDetailScreen> {
  late final Future<List<NaveReference>> _references =
      widget.repository.references(widget.topic.id);
  final Set<int> _selectedIds = {};
  bool get _selecting => _selectedIds.isNotEmpty;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          leading: _selecting
              ? IconButton(
                  tooltip: 'Annuler la sélection',
                  onPressed: () => setState(_selectedIds.clear),
                  icon: const Icon(Icons.close),
                )
              : null,
          title: Text(_selecting
              ? '${_selectedIds.length} sélectionnée${_selectedIds.length > 1 ? 's' : ''}'
              : widget.topic.title),
          actions: _selecting
              ? [
                  IconButton(
                    key: const Key('nave-add-to-study'),
                    tooltip: 'Ajouter à une étude',
                    onPressed: _addToStudy,
                    icon: const Icon(Icons.note_add_outlined),
                  ),
                  IconButton(
                    key: const Key('nave-copy-selection'),
                    tooltip: 'Copier',
                    onPressed: _copySelection,
                    icon: const Icon(Icons.copy_outlined),
                  ),
                  IconButton(
                    key: const Key('nave-share-selection'),
                    tooltip: 'Partager',
                    onPressed: _shareSelection,
                    icon: const Icon(Icons.share_outlined),
                  ),
                ]
              : null,
        ),
        body: FutureBuilder<List<NaveReference>>(
          future: _references,
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
                      Text(widget.topic.title.toUpperCase(),
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800)),
                      const SizedBox(height: 4),
                      Text("Orville J. Nave · Nave's Topical Bible",
                          style: Theme.of(context).textTheme.bodyMedium),
                      if (widget.topic.isTranslated)
                        Text('Original anglais : ${widget.topic.titleEnglish}',
                            style: Theme.of(context).textTheme.bodySmall),
                      const SizedBox(height: 12),
                      Text('Sections',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                ...groups.values.map((items) => ExpansionTile(
                      initiallyExpanded: groups.length < 5,
                      title: Row(children: [
                        Expanded(child: Text(items.first.subtopic)),
                        Text('${items.length}'),
                        if (items.first.subtopic == items.first.subtopicEnglish)
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Tooltip(
                              message: 'Section non encore traduite',
                              child: Chip(
                                visualDensity: VisualDensity.compact,
                                label: Text('Non encore traduit'),
                              ),
                            ),
                          ),
                      ]),
                      children: [
                        if (_selecting)
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => _selectSection(items),
                              icon: const Icon(Icons.select_all),
                              label: const Text(
                                  'Tout sélectionner dans cette section'),
                            ),
                          ),
                        ...items.map(
                            (reference) => _referenceTile(context, reference)),
                      ],
                    )),
              ],
            );
          },
        ),
      );

  Widget _referenceTile(BuildContext context, NaveReference reference) {
    final selected = _selectedIds.contains(reference.id);
    return ListTile(
      key: Key('nave-reference-${reference.id}'),
      selected: selected,
      leading: _selecting
          ? Checkbox(value: selected, onChanged: (_) => _toggle(reference))
          : const Icon(Icons.menu_book_outlined),
      title: Text(reference.referenceLabel),
      subtitle: reference.verseText == null
          ? null
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(reference.verseText!,
                    maxLines: 3, overflow: TextOverflow.ellipsis),
                if (reference.versionAbbreviation != null)
                  Text(
                    '${reference.versionAbbreviation}'
                    '${reference.usesDefaultText ? ' · texte de secours' : ''}',
                    style: Theme.of(context).textTheme.labelSmall,
                  ),
              ],
            ),
      onLongPress: () => _toggle(reference),
      onTap: _selecting
          ? () => _toggle(reference)
          : () => _openReference(context, reference),
    );
  }

  void _toggle(NaveReference reference) => setState(() {
        if (!_selectedIds.add(reference.id)) _selectedIds.remove(reference.id);
      });

  void _selectSection(List<NaveReference> references) => setState(() {
        final ids = references.map((reference) => reference.id).toSet();
        _selectedIds.containsAll(ids)
            ? _selectedIds.removeAll(ids)
            : _selectedIds.addAll(ids);
      });

  Future<List<NaveReference>> _selectedReferences() async {
    final references = await _references;
    final seen = <String>{};
    return references
        .where((reference) => _selectedIds.contains(reference.id))
        .where((reference) => seen.add(
              '${reference.bookId}:${reference.chapter}:'
              '${reference.verseStart}:${reference.verseEnd}',
            ))
        .toList(growable: false);
  }

  String _selectionText(List<NaveReference> references) => [
        '${widget.topic.title.toUpperCase()} — Bible thématique Nave',
        '',
        ...references.map((reference) => reference.referenceLabel),
      ].join('\n');

  Future<void> _copySelection() async {
    final references = await _selectedReferences();
    await Clipboard.setData(ClipboardData(text: _selectionText(references)));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Références copiées.')),
      );
    }
  }

  Future<void> _shareSelection() async {
    final references = await _selectedReferences();
    await Share.share(_selectionText(references),
        subject: '${widget.topic.title} — Bible thématique Nave');
  }

  Future<void> _addToStudy() async {
    final references = await _selectedReferences();
    if (!mounted || references.isEmpty) return;
    final now = DateTime.now();
    final block = StudyBlock(
      id: '${now.microsecondsSinceEpoch}-nave',
      type: StudyBlockType.nave,
      position: 0,
      payload: {
        'topicId': widget.topic.id,
        'title': widget.topic.title,
        'titleEnglish': widget.topic.titleEnglish,
        'references': [
          for (final reference in references) reference.referenceLabel
        ],
      },
      createdAt: now,
      updatedAt: now,
    );
    final study = widget.studyDestination == null
        ? await StudyDestinationSheet.show(
            context,
            block,
            reference: widget.topic.title,
          )
        : await widget.studyDestination!(context, block);
    if (!mounted || study == null) return;
    if (widget.onStudyOpened != null) {
      widget.onStudyOpened!(study);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PersonalStudyEditorScreen(
          study: study,
          openingBlockId: block.id,
          openingMessage: 'Thème Nave ajouté à l’étude.',
        ),
      ),
    );
  }

  void _openReference(BuildContext context, NaveReference reference) {
    if (widget.onOpenReference != null) {
      widget.onOpenReference!(reference);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterReaderScreen(
          book: BibleBook(
            id: reference.bookId,
            name: reference.bookName,
            abbreviation: '',
            testament: '',
            chaptersCount: reference.chaptersCount,
          ),
          initialChapter: reference.chapter,
          initialVerse: reference.verseStart,
          initialVersionId: reference.versionId,
        ),
      ),
    );
  }
}

Widget _resourceError(BuildContext context, Object? error) =>
    EmptyResourceState(
      icon: error is ResourceNotInstalledException
          ? Icons.download_for_offline_outlined
          : Icons.error_outline,
      message: error is ResourceNotInstalledException
          ? 'Bible thématique non installée'
          : 'Impossible de charger la Bible thématique.',
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
