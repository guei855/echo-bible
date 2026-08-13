import 'package:echo_bible/core/services/database_service.dart';
import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/plans/services/reading_plan_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class CreatePlanScreen extends StatefulWidget {
  const CreatePlanScreen({super.key});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  late final TextEditingController _dateController;
  final _daysController = TextEditingController(text: '365');
  late final Future<List<BibleBook>> _books = _loadBooks();
  final Set<int> _selectedBookIds = {};
  DateTime _startDate = DateTime.now();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _dateController = TextEditingController(text: _formatDate(_startDate));
  }

  @override
  void dispose() {
    _dateController.dispose();
    _daysController.dispose();
    super.dispose();
  }

  Future<List<BibleBook>> _loadBooks() async {
    final db = await DatabaseService.database;
    final rows = await db.query('books', orderBy: 'position ASC, id ASC');
    final books = rows.map(BibleBook.fromMap).toList();
    _selectedBookIds.addAll(books.map((book) => book.id));
    return books;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Créer un plan')),
      body: FutureBuilder<List<BibleBook>>(
        future: _books,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final books = snapshot.data ?? const [];
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 110),
            children: [
              _TimeSpanCard(
                dateController: _dateController,
                daysController: _daysController,
                onChooseDate: _chooseDate,
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Livres à lire',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      if (_selectedBookIds.length == books.length) {
                        _selectedBookIds.clear();
                      } else {
                        _selectedBookIds.addAll(books.map((book) => book.id));
                      }
                    }),
                    child: Text(
                      _selectedBookIds.length == books.length
                          ? 'Tout retirer'
                          : 'Tout choisir',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final book in books)
                    FilterChip(
                      label: Text(book.abbreviation),
                      selected: _selectedBookIds.contains(book.id),
                      onSelected: (selected) => setState(() {
                        if (selected) {
                          _selectedBookIds.add(book.id);
                        } else {
                          _selectedBookIds.remove(book.id);
                        }
                      }),
                    ),
                ],
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(18),
        child: FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 15),
          ),
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: const Text('Créer et activer le plan'),
        ),
      ),
    );
  }

  Future<void> _chooseDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(DateTime.now().year - 1),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (date != null) {
      setState(() {
        _startDate = date;
        _dateController.text = _formatDate(date);
      });
    }
  }

  Future<void> _save() async {
    final duration = int.tryParse(_daysController.text.trim());
    if (_selectedBookIds.isEmpty ||
        duration == null ||
        duration < 1 ||
        duration > 3650) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Choisissez au moins un livre et 1 à 3650 jours.'),
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ReadingPlanService.createPersonalPlan(
        title: 'Plan de lecture en $duration jours',
        startDate: _startDate,
        duration: duration,
        bookIds: _selectedBookIds.toList(),
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  static String _formatDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/${date.year}';
}

class _TimeSpanCard extends StatelessWidget {
  final TextEditingController dateController;
  final TextEditingController daysController;
  final VoidCallback onChooseDate;

  const _TimeSpanCard({
    required this.dateController,
    required this.daysController,
    required this.onChooseDate,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 16),
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'LAPS DE TEMPS',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: .6,
                ),
          ),
          const Divider(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: TextField(
                  controller: dateController,
                  readOnly: true,
                  onTap: onChooseDate,
                  decoration: InputDecoration(
                    labelText: 'Commencer',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      tooltip: 'Choisir la date',
                      onPressed: onChooseDate,
                      icon: const Icon(Icons.calendar_today_rounded),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 112,
                child: TextField(
                  controller: daysController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Jours',
                    hintText: '365',
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
