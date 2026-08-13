import 'package:echo_bible/features/dictionary/data/repository/dictionary_repository.dart';
import 'package:echo_bible/features/dictionary/models/dictionary_entry.dart';
import 'package:echo_bible/features/dictionary/screens/dictionary_detail_screen.dart';
import 'package:echo_bible/core/resources/resource_descriptor.dart';
import 'package:echo_bible/core/resources/resource_manager.dart';
import 'package:echo_bible/shared/widgets/resource_install_card.dart';
import 'package:flutter/material.dart';

class DictionaryScreen extends StatefulWidget {
  final Future<bool>? availability;

  const DictionaryScreen({super.key, this.availability});

  @override
  State<DictionaryScreen> createState() => _DictionaryScreenState();
}

class _DictionaryScreenState extends State<DictionaryScreen> {
  static const _repository = DictionaryRepository();
  final _controller = TextEditingController();
  late final Future<bool> _available =
      widget.availability ?? _repository.isAvailable();
  List<DictionaryEntry> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.isEmpty) return;
    setState(() => _loading = true);
    final results = await _repository.search(query);
    if (!mounted) return;
    setState(() {
      _results = results;
      _loading = false;
    });
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
          if (snapshot.data != true) return const _UnavailableDictionary();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _controller,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _search(),
                  decoration: InputDecoration(
                    labelText: 'Rechercher un article',
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
              if (_loading) const LinearProgressIndicator(),
              Expanded(
                child: ListView.separated(
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
                          builder: (_) => DictionaryDetailScreen(entry: entry),
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
  const _UnavailableDictionary();

  @override
  Widget build(BuildContext context) {
    const manager = ResourceManager();
    final resource = manager.descriptor(OfflineResourceId.dictionary);
    return FutureBuilder<OfflineResourceState>(
      future: manager.state(OfflineResourceId.dictionary),
      builder: (context, snapshot) => ResourceInstallCard(
        resource: resource,
        state: snapshot.data ?? OfflineResourceState.preparing,
        onLater: () => Navigator.maybePop(context),
      ),
    );
  }
}
