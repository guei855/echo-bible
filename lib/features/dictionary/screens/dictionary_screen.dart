import 'package:echo_bible/features/dictionary/data/repository/dictionary_repository.dart';
import 'package:echo_bible/features/dictionary/models/dictionary_entry.dart';
import 'package:echo_bible/features/dictionary/screens/dictionary_detail_screen.dart';
import 'package:echo_bible/features/settings/screens/download_manager_screen.dart';
import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:echo_bible/shared/widgets/resource_install_card.dart';
import 'package:flutter/material.dart';

typedef DictionaryEntryLoader = Future<List<DictionaryEntry>> Function(
  String value,
);
typedef DictionaryLetterLoader = Future<List<DictionaryEntry>> Function(
  String letter,
);

class DictionaryScreen extends StatefulWidget {
  final Future<bool>? availability;
  final DictionaryEntryLoader? searchLoader;
  final DictionaryLetterLoader? letterLoader;

  const DictionaryScreen({
    super.key,
    this.availability,
    this.searchLoader,
    this.letterLoader,
  });

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  static const _repository = DictionaryRepository();
  final _controller = TextEditingController();
  late Future<bool> _available =
      widget.availability ?? _repository.isAvailable();
  List<DictionaryEntry> _results = const [];
  bool _loading = false;
  bool _initialLoaded = false;
  int _requestGeneration = 0;
  String? _selectedLetter;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    setState(() {
      _selectedLetter = null;
    });
    await _runQuery(
      () =>
          widget.searchLoader?.call(query) ??
          (query.isEmpty
              ? _repository.listAlphabetically()
              : _repository.search(query)),
    );
  }

  Future<void> _loadLetter(String letter) async {
    setState(() {
      _selectedLetter = letter;
      _controller.clear();
    });
    await _runQuery(
      () =>
          widget.letterLoader?.call(letter) ??
          _repository.listAlphabetically(letter: letter),
    );
  }

  Future<void> _runQuery(
    Future<List<DictionaryEntry>> Function() query,
  ) async {
    final generation = ++_requestGeneration;
    setState(() {
      _loading = true;
      _errorMessage = null;
    });
    try {
      final results = await query();
      if (!mounted || generation != _requestGeneration) return;
      setState(() => _results = results);
    } catch (_) {
      if (!mounted || generation != _requestGeneration) return;
      setState(() {
        _results = const [];
        _errorMessage = 'Impossible de charger le dictionnaire.';
      });
    } finally {
      if (mounted && generation == _requestGeneration) {
        setState(() {
          _loading = false;
          _initialLoaded = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Dictionnaire biblique')),
      body: FutureBuilder<bool>(
        future: _available,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.data != true) {
            return _UnavailableDictionary(
              onReturn: () => setState(
                () => _available =
                    widget.availability ?? _repository.isAvailable(),
              ),
            );
          }
          if (!_initialLoaded && !_loading) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted && !_initialLoaded && !_loading) _loadLetter('A');
            });
          }
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    labelText: 'Rechercher un mot…',
                    hintText: 'Ex. Abraham, Alliance, Jérusalem',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      onPressed: _search,
                      tooltip: 'Rechercher',
                      icon: const Icon(Icons.search_rounded),
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  scrollDirection: Axis.horizontal,
                  itemCount: 26,
                  separatorBuilder: (_, __) => const SizedBox(width: 4),
                  itemBuilder: (context, index) {
                    final letter = String.fromCharCode(65 + index);
                    return ActionChip(
                      key: Key('dictionary-letter-$letter'),
                      label: Text(letter),
                      backgroundColor: _selectedLetter == letter
                          ? Theme.of(context).colorScheme.secondaryContainer
                          : null,
                      onPressed: () => _loadLetter(letter),
                    );
                  },
                ),
              ),
              if (_loading)
                const LinearProgressIndicator(
                  key: Key('dictionary-loading'),
                ),
              Expanded(
                child: _errorMessage != null ||
                        (!_loading && _initialLoaded && _results.isEmpty)
                    ? Center(
                        child: Text(
                          _errorMessage ?? 'Aucun article trouvé.',
                          key: const Key('dictionary-empty-message'),
                        ),
                      )
                    : ListView.separated(
                        itemCount: _results.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final entry = _results[index];
                          return ListTile(
                            title: Text(entry.title),
                            subtitle: Text(
                              entry.content,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    DictionaryDetailScreen(entry: entry),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _UnavailableDictionary extends StatelessWidget {
  final VoidCallback onReturn;

  const _UnavailableDictionary({required this.onReturn});

  @override
  Widget build(BuildContext context) {
    const manager = ResourceManager();
    final resource = manager.descriptor(OfflineResourceId.dictionary);
    return FutureBuilder<OfflineResourceState>(
      future: manager.state(OfflineResourceId.dictionary),
      builder: (context, snapshot) => ResourceInstallCard(
        resource: resource,
        state: snapshot.data ?? OfflineResourceState.preparing,
        onDownload: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const DownloadManagerScreen(
                initialCategory: ResourceCategory.dictionary,
              ),
            ),
          );
          onReturn();
        },
        onLater: () => Navigator.maybePop(context),
      ),
    );
  }
}
