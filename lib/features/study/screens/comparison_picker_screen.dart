import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/screens/parallel_comparison_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ComparisonPickerScreen extends StatefulWidget {
  const ComparisonPickerScreen({super.key});

  @override
  State<ComparisonPickerScreen> createState() => _ComparisonPickerScreenState();
}

class _ComparisonPickerScreenState extends State<ComparisonPickerScreen> {
  late final Future<List<BibleBook>> _books = _loadBooks();
  BibleBook? _book;
  int _chapter = 1;
  int _verse = 1;
  int _maximumVerse = 1;
  bool _loadingVerses = false;

  Future<List<BibleBook>> _loadBooks() async {
    final db = await DatabaseService.database;
    final rows = await db.query('books', orderBy: 'position, id');
    return rows.map(BibleBook.fromMap).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Comparer un verset')),
      body: FutureBuilder<List<BibleBook>>(
        future: _books,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final books = snapshot.data ?? const [];
          if (_book == null && books.isNotEmpty) {
            _book = books.first;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadMaximumVerse();
            });
          }
          return ListView(
            padding: const EdgeInsets.all(18),
            children: [
              DropdownButtonFormField<BibleBook>(
                initialValue: _book,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Livre',
                  prefixIcon: Icon(Icons.menu_book_rounded),
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final book in books)
                    DropdownMenuItem(
                      value: book,
                      child: Text(
                        book.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                selectedItemBuilder: (_) => [
                  for (final book in books)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        book.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (book) {
                  setState(() {
                    _book = book;
                    _chapter = 1;
                    _verse = 1;
                  });
                  _loadMaximumVerse();
                },
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _chapter,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Chapitre',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (var chapter = 1;
                            chapter <= (_book?.chaptersCount ?? 1);
                            chapter++)
                          DropdownMenuItem(
                            value: chapter,
                            child: Text('$chapter'),
                          ),
                      ],
                      onChanged: (chapter) {
                        setState(() {
                          _chapter = chapter ?? 1;
                          _verse = 1;
                        });
                        _loadMaximumVerse();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      key: ValueKey('${_book?.id}-$_chapter'),
                      initialValue: '1',
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(3),
                      ],
                      decoration: InputDecoration(
                        labelText: 'Verset',
                        helperText: _loadingVerses
                            ? 'Vérification…'
                            : '1 à $_maximumVerse',
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (value) => _verse = int.tryParse(value) ?? 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                onPressed: _book == null ? null : _openComparison,
                icon: const Icon(Icons.compare_arrows_rounded),
                label: const Text('Comparer les versions'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openComparison() {
    if (_verse < 1 || _verse > _maximumVerse) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ce chapitre contient les versets 1 à $_maximumVerse.',
          ),
        ),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ParallelComparisonScreen(
          book: _book!,
          chapter: _chapter,
          verse: _verse,
        ),
      ),
    );
  }

  Future<void> _loadMaximumVerse() async {
    final book = _book;
    if (book == null) return;
    setState(() => _loadingVerses = true);
    final db = await DatabaseService.database;
    final rows = await db.rawQuery(
      'SELECT verses_count FROM chapters '
      'WHERE book_id = ? AND chapter_number = ? LIMIT 1',
      [book.id, _chapter],
    );
    if (!mounted) return;
    setState(() {
      _maximumVerse = rows.isEmpty
          ? 1
          : (rows.first['verses_count'] as int? ?? 1).clamp(1, 200);
      _loadingVerses = false;
    });
  }
}
