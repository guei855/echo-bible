import 'dart:async';

import 'package:flutter/material.dart';
import 'package:echo_bible/core/services/search_service.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:echo_bible/features/search/widgets/highlighted_text.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _controller = TextEditingController();
  Timer? _searchTimer;
  List<SearchResultItem> _results = [];
  bool _isLoading = false;
  String _lastQuery = '';
  String? _errorMessage;
  int _requestId = 0;

  @override
  void dispose() {
    _searchTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSearch(String query) {
    _searchTimer?.cancel();
    if (query.trim().isEmpty) {
      _onSearch(query);
      return;
    }
    _searchTimer =
        Timer(const Duration(milliseconds: 350), () => _onSearch(query));
  }

  Future<void> _onSearch(String query) async {
    final normalizedQuery = query.trim();
    final requestId = ++_requestId;
    if (normalizedQuery.isEmpty) {
      setState(() {
        _results = [];
        _lastQuery = '';
        _errorMessage = null;
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _lastQuery = normalizedQuery;
      _errorMessage = null;
    });

    try {
      final results = await SearchService.searchVerses(normalizedQuery);
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = results;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted || requestId != _requestId) return;
      setState(() {
        _results = [];
        _errorMessage = 'La recherche est momentanément indisponible.';
        _isLoading = false;
      });
    }
  }

  void _clearSearch() {
    _searchTimer?.cancel();
    _controller.clear();
    _onSearch('');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E3A8A),
        foregroundColor: Colors.white,
        title: TextField(
          controller: _controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Rechercher un mot ou une expression...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white, fontSize: 18),
          onChanged: (query) {
            setState(() {});
            _scheduleSearch(query);
          },
          onSubmitted: (query) {
            _searchTimer?.cancel();
            _onSearch(query);
          },
        ),
        actions: [
          if (_controller.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              tooltip: 'Effacer la recherche',
              onPressed: _clearSearch,
            ),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: 'Rechercher',
            onPressed: () => _onSearch(_controller.text),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return _buildMessage(Icons.error_outline, _errorMessage!);
    }
    if (_lastQuery.isEmpty) {
      return _buildMessage(
        Icons.manage_search_rounded,
        'Saisissez un mot ou une expression pour rechercher dans la Bible.',
      );
    }
    if (_results.isEmpty) {
      return _buildMessage(
        Icons.search_off_rounded,
        'Aucun verset ne contient « $_lastQuery ».',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '${_results.length} résultat${_results.length > 1 ? 's' : ''}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            itemCount: _results.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = _results[index];
              return ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                title: Text(
                  '${item.bookName} ${item.chapterNumber}:${item.verseNumber}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).primaryColor,
                    fontSize: 14,
                  ),
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: HighlightedText(
                    text: item.text,
                    query: _lastQuery,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontSize: 15,
                        ),
                  ),
                ),
                onTap: () => _openResult(item),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMessage(IconData icon, String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: Colors.grey),
            const SizedBox(height: 16),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }

  void _openResult(SearchResultItem item) {
    final book = BibleBook(
      id: item.bookId,
      name: item.bookName,
      abbreviation: '',
      testament: '',
      chaptersCount: item.chaptersCount,
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ChapterReaderScreen(book: book, initialChapter: item.chapterNumber),
      ),
    );
  }
}
