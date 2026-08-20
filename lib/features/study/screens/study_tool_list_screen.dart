import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:echo_bible/features/study/models/study_tool_item.dart';
import 'package:echo_bible/features/study/services/study_tools_service.dart';
import 'package:flutter/material.dart';

typedef StudyToolItemLoader = Future<List<StudyToolItem>> Function(
  StudyToolType type,
);
typedef HistoryDeleteCallback = Future<void> Function(Iterable<int> ids);
typedef HistoryRestoreCallback = Future<void> Function(
  Iterable<StudyToolItem> items,
);

class StudyToolListScreen extends StatefulWidget {
  final StudyToolType type;
  final String title;
  final StudyToolItemLoader itemLoader;
  final HistoryDeleteCallback deleteHistory;
  final HistoryRestoreCallback restoreHistory;
  final Future<void> Function() clearHistory;
  final ValueChanged<StudyToolItem>? onOpenItem;

  const StudyToolListScreen({
    super.key,
    required this.type,
    required this.title,
    StudyToolItemLoader? itemLoader,
    HistoryDeleteCallback? deleteHistory,
    HistoryRestoreCallback? restoreHistory,
    Future<void> Function()? clearHistory,
    this.onOpenItem,
  })  : itemLoader = itemLoader ?? StudyToolsService.loadItems,
        deleteHistory = deleteHistory ?? StudyToolsService.deleteHistory,
        restoreHistory = restoreHistory ?? StudyToolsService.restoreHistory,
        clearHistory = clearHistory ?? StudyToolsService.clearHistory;

  @override
  State<StudyToolListScreen> createState() => _StudyToolListScreenState();
}

class _StudyToolListScreenState extends State<StudyToolListScreen> {
  List<StudyToolItem>? _items;
  Object? _error;
  final Set<int> _selectedIds = {};

  bool get _isHistory => widget.type == StudyToolType.history;
  bool get _isSelecting => _selectedIds.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final items = await widget.itemLoader(widget.type);
      if (!mounted) return;
      setState(() {
        _items = items;
        _error = null;
        _selectedIds.removeWhere(
          (id) => !items.any((item) => item.sourceId == id),
        );
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: _buildAppBar(),
        body: _buildBody(),
      );

  PreferredSizeWidget _buildAppBar() {
    if (_isHistory && _isSelecting) {
      final count = _selectedIds.length;
      return AppBar(
        key: const Key('history-selection-app-bar'),
        leading: IconButton(
          tooltip: 'Fermer la sélection',
          onPressed: () => setState(_selectedIds.clear),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text('$count sélectionné${count > 1 ? 's' : ''}'),
        actions: [
          IconButton(
            key: const Key('history-select-all'),
            tooltip: 'Tout sélectionner',
            onPressed: _selectAll,
            icon: const Icon(Icons.select_all_rounded),
          ),
          IconButton(
            key: const Key('history-delete-selected'),
            tooltip: 'Supprimer',
            onPressed: _deleteSelected,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      );
    }
    return AppBar(
      title: Text(widget.title),
      actions: [
        if (_isHistory)
          PopupMenuButton<String>(
            key: const Key('history-menu'),
            tooltip: 'Plus d’options',
            onSelected: (value) {
              if (value == 'clear') _clearAll();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'clear',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep_outlined),
                    SizedBox(width: 10),
                    Text('Tout effacer'),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }

  Widget _buildBody() {
    if (_items == null && _error == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return const _EmptyState(
        icon: Icons.error_outline_rounded,
        text: 'Impossible de charger ces éléments.',
      );
    }
    final items = _items ?? const <StudyToolItem>[];
    if (items.isEmpty) {
      return _EmptyState(icon: _emptyIcon, text: _emptyText);
    }
    final colors = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(
        height: 1,
        color: colors.outlineVariant,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final selected =
            item.sourceId != null && _selectedIds.contains(item.sourceId);
        return ListTile(
          key: item.sourceId == null
              ? null
              : Key('history-item-${item.sourceId}'),
          selected: selected,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 18,
            vertical: 8,
          ),
          leading: _leading(item, selected),
          title: Text(
            '${item.bookName} ${item.chapterNumber}:${item.verseNumber}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (item.title?.trim().isNotEmpty ?? false)
                  Text(
                    item.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                if (item.detail?.trim().isNotEmpty ?? false)
                  Text(
                    item.detail!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                Text(
                  item.verseText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.onSurfaceVariant,
                    fontStyle: item.detail == null
                        ? FontStyle.normal
                        : FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          trailing: _isSelecting && _isHistory
              ? null
              : const Icon(Icons.chevron_right_rounded),
          onLongPress: _isHistory ? () => _toggleSelection(item) : null,
          onTap: () => _isHistory && _isSelecting
              ? _toggleSelection(item)
              : _openItem(item),
        );
      },
    );
  }

  Widget _leading(StudyToolItem item, bool selected) {
    if (_isHistory && _isSelecting) {
      return Checkbox(
        value: selected,
        onChanged: (_) => _toggleSelection(item),
      );
    }
    if (widget.type == StudyToolType.highlights) {
      return CircleAvatar(backgroundColor: _highlightColor(item.color));
    }
    return CircleAvatar(
      backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
      foregroundColor: AppColors.primary,
      child: Icon(
        switch (widget.type) {
          StudyToolType.notes => Icons.edit_note_rounded,
          StudyToolType.highlights => Icons.brush_rounded,
          StudyToolType.bookmarks => Icons.bookmark_rounded,
          StudyToolType.history => Icons.history_rounded,
        },
      ),
    );
  }

  void _toggleSelection(StudyToolItem item) {
    final id = item.sourceId;
    if (id == null) return;
    setState(() {
      if (!_selectedIds.remove(id)) _selectedIds.add(id);
    });
  }

  void _selectAll() {
    final ids = (_items ?? const <StudyToolItem>[])
        .map((item) => item.sourceId)
        .whereType<int>()
        .toSet();
    setState(() {
      if (_selectedIds.length == ids.length) {
        _selectedIds.clear();
      } else {
        _selectedIds
          ..clear()
          ..addAll(ids);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final items = (_items ?? const <StudyToolItem>[])
        .where((item) => _selectedIds.contains(item.sourceId))
        .toList();
    if (items.isEmpty) return;
    if (items.length > 1 && !await _confirmDelete(items.length)) return;
    final ids = items.map((item) => item.sourceId).whereType<int>().toList();
    setState(() {
      _items = _items!.where((item) => !ids.contains(item.sourceId)).toList();
      _selectedIds.clear();
    });
    try {
      await widget.deleteHistory(ids);
    } catch (_) {
      if (mounted) await _load();
      return;
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          items.length == 1
              ? 'Entrée supprimée.'
              : '${items.length} entrées supprimées.',
        ),
        action: SnackBarAction(
          label: 'ANNULER',
          onPressed: () async {
            await widget.restoreHistory(items);
            await _load();
          },
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(int count) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer la sélection ?'),
            content: Text('Supprimer ces $count entrées de l’historique ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _clearAll() async {
    if ((_items ?? const <StudyToolItem>[]).isEmpty) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Supprimer tout l’historique ?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Supprimer'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    setState(() {
      _items = [];
      _selectedIds.clear();
    });
    try {
      await widget.clearHistory();
    } catch (_) {
      if (mounted) await _load();
    }
  }

  Future<void> _openItem(StudyToolItem item) async {
    if (widget.onOpenItem != null) {
      widget.onOpenItem!(item);
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChapterReaderScreen(
          book: BibleBook(
            id: item.bookId,
            name: item.bookName,
            abbreviation: '',
            testament: '',
            chaptersCount: item.chaptersCount,
          ),
          initialChapter: item.chapterNumber,
          initialVerse: item.verseNumber,
          initialVersionId: item.versionId,
        ),
      ),
    );
    if (mounted && _isHistory) await _load();
  }

  Color _highlightColor(String? color) => switch (color) {
        'yellow' => Colors.amber,
        'green' => Colors.green,
        'pink' => Colors.pink,
        'blue' => Colors.lightBlue,
        _ => AppColors.secondary,
      };

  IconData get _emptyIcon => switch (widget.type) {
        StudyToolType.notes => Icons.edit_note_outlined,
        StudyToolType.highlights => Icons.brush_outlined,
        StudyToolType.bookmarks => Icons.bookmark_border_rounded,
        StudyToolType.history => Icons.history_rounded,
      };

  String get _emptyText => switch (widget.type) {
        StudyToolType.notes => 'Aucune note personnelle pour le moment.',
        StudyToolType.highlights => 'Aucun verset surligné pour le moment.',
        StudyToolType.bookmarks => 'Aucun signet pour le moment.',
        StudyToolType.history => 'Aucun passage récent pour le moment.',
      };
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const _EmptyState({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.onSurfaceVariant;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 14),
            Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
