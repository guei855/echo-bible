import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:echo_bible/features/settings/screens/download_manager_screen.dart';
import 'package:echo_bible/features/study/models/strong_entry.dart';
import 'package:echo_bible/features/study/models/verse_study_data.dart';
import 'package:echo_bible/features/study/repositories/strong_repository.dart';
import 'package:echo_bible/features/study/screens/strong_word_screen.dart';
import 'package:flutter/material.dart';

class LexiconScreen extends StatefulWidget {
  const LexiconScreen({
    super.key,
    this.initialQuery,
    this.repository = const StrongRepository(),
    this.resourceManager = const ResourceManager(),
    this.loadResourceState,
    this.searchEntries,
  });

  final String? initialQuery;
  final StrongRepository repository;
  final ResourceManager resourceManager;
  final Future<OfflineResourceState> Function()? loadResourceState;
  final Future<List<StrongEntry>> Function(String query)? searchEntries;

  @override
  State<LexiconScreen> createState() => _LexiconScreenState();
}

class _LexiconScreenState extends State<LexiconScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final TextEditingController _searchController;
  late Future<OfflineResourceState> _resourceState;
  List<StrongEntry> _results = const [];
  String _query = '';
  String? _error;
  bool _loading = false;

  bool get _hebrew => _tabs.index == 0;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (!_tabs.indexIsChanging && mounted) setState(() {});
      });
    _searchController = TextEditingController(text: widget.initialQuery ?? '');
    _resourceState = _loadState();
    if (widget.initialQuery?.trim().isNotEmpty ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _search());
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<OfflineResourceState> _loadState() async {
    try {
      return await (widget.loadResourceState?.call() ??
              widget.resourceManager.state(OfflineResourceId.strong))
          .timeout(const Duration(seconds: 8));
    } on Object {
      return OfflineResourceState.notInstalled;
    }
  }

  void _refreshResource() {
    setState(() => _resourceState = _loadState());
  }

  Future<void> _openDownloads() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const DownloadManagerScreen(
          initialCategory: ResourceCategory.strong,
        ),
      ),
    );
    if (mounted) _refreshResource();
  }

  Future<void> _search() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _query = '';
        _results = const [];
        _error = null;
        _loading = false;
      });
      return;
    }
    setState(() {
      _query = query;
      _error = null;
      _loading = true;
    });
    try {
      final results = await (widget.searchEntries?.call(query) ??
              widget.repository.search(query))
          .timeout(const Duration(seconds: 15));
      if (!mounted) return;
      setState(() => _results = results);
    } on Object {
      if (!mounted) return;
      setState(
          () => _error = 'Impossible d’interroger le lexique Strong installé.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Lexique hébreu & grec'),
          bottom: TabBar(
            controller: _tabs,
            tabs: const [Tab(text: 'Hébreu'), Tab(text: 'Grec')],
          ),
        ),
        body: FutureBuilder<OfflineResourceState>(
          future: _resourceState,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            final state = snapshot.data;
            final installed = state == OfflineResourceState.installed ||
                state == OfflineResourceState.updateAvailable;
            if (!installed) return _missingResource();
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    key: const Key('lexicon-search-field'),
                    controller: _searchController,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText:
                          'Mot, lemme, translittération ou numéro Strong…',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.manage_search),
                      suffixIcon: IconButton(
                        key: const Key('lexicon-search-button'),
                        tooltip: 'Rechercher',
                        onPressed: _search,
                        icon: const Icon(Icons.search),
                      ),
                    ),
                  ),
                ),
                Expanded(child: _content()),
              ],
            );
          },
        ),
      );

  Widget _missingResource() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.download_for_offline_outlined, size: 52),
              const SizedBox(height: 14),
              const Text(
                'Le lexique utilise la ressource Strong hébreu et grec.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                key: const Key('lexicon-download-button'),
                onPressed: _openDownloads,
                icon: const Icon(Icons.download),
                label: const Text('Télécharger Strong'),
              ),
            ],
          ),
        ),
      );

  Widget _content() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return _message(Icons.error_outline, _error!);
    if (_query.isEmpty) {
      return _message(
        Icons.abc_rounded,
        'Recherchez une forme originale, un lemme, une translittération, '
        'une définition ou un mot français réellement aligné.',
      );
    }
    final prefix = _hebrew ? 'H' : 'G';
    final visible = _results
        .where((entry) => entry.strongNumber.toUpperCase().startsWith(prefix))
        .toList(growable: false);
    if (visible.isEmpty) {
      return _message(
        Icons.search_off,
        'Aucun résultat ${_hebrew ? 'hébreu' : 'grec'} pour « $_query ».',
      );
    }
    return ListView.separated(
      key: const Key('lexicon-results'),
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: visible.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) => _resultTile(visible[index]),
    );
  }

  Widget _resultTile(StrongEntry entry) {
    final hebrew = entry.strongNumber.toUpperCase().startsWith('H');
    final morphology = VerseStrongWord(
      id: entry.id,
      order: 0,
      word: entry.originalWord,
      code: entry.strongNumber,
      morphology: entry.morphology,
    ).morphologyInFrench;
    final definition = entry.frenchDefinition?.trim().isNotEmpty == true
        ? entry.frenchDefinition!
        : entry.gloss?.trim().isNotEmpty == true
            ? entry.gloss!
            : entry.shortDefinition?.trim().isNotEmpty == true
                ? entry.shortDefinition!
                : entry.definition?.trim().isNotEmpty == true
                    ? entry.definition!
                    : 'Définition française non disponible.';
    return ListTile(
      key: Key('lexicon-entry-${entry.strongNumber}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 68,
            child: Text(
              entry.strongNumber,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Directionality(
              textDirection: hebrew ? TextDirection.rtl : TextDirection.ltr,
              child: Text(
                entry.originalWord,
                key: Key('lexicon-original-${entry.strongNumber}'),
                textAlign: hebrew ? TextAlign.right : TextAlign.left,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text([
          if (entry.transliteration?.trim().isNotEmpty ?? false)
            entry.transliteration!,
          if (morphology?.trim().isNotEmpty ?? false) morphology!,
          definition,
        ].join('\n')),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _openEntry(entry),
    );
  }

  void _openEntry(StrongEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StrongWordScreen(
          word: VerseStrongWord(
            id: entry.id,
            order: 0,
            word: entry.originalWord,
            code: entry.strongNumber,
            originalWord: entry.originalWord,
            lemma: entry.originalWord,
            morphology: entry.morphology,
            language: entry.language,
            definition: entry.definition,
            transliteration: entry.transliteration,
            pronunciation: entry.pronunciation,
            gloss: entry.gloss,
            shortDefinition: entry.shortDefinition,
            frenchDefinition: entry.frenchDefinition,
            source: entry.source,
            license: entry.license,
            numberKind: entry.numberKind,
          ),
        ),
      ),
    );
  }

  Widget _message(IconData icon, String text) => Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 48, color: Colors.grey),
              const SizedBox(height: 14),
              Text(text, textAlign: TextAlign.center),
            ],
          ),
        ),
      );
}
