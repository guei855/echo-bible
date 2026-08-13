import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

enum NoteScreenAction { save, delete }

class NoteScreenResult {
  final NoteScreenAction action;
  final String title;
  final String description;

  const NoteScreenResult({
    required this.action,
    this.title = '',
    this.description = '',
  });
}

class NoteEditorScreen extends StatefulWidget {
  final String reference;
  final String verseText;
  final String initialTitle;
  final String initialDescription;

  const NoteEditorScreen({
    super.key,
    required this.reference,
    required this.verseText,
    this.initialTitle = '',
    this.initialDescription = '',
  });

  @override
  State<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends State<NoteEditorScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  bool _canSave = false;
  bool _verseExpanded = true;

  bool get _isExisting => widget.initialDescription.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle);
    _descriptionController = TextEditingController(
      text: widget.initialDescription,
    )..addListener(_updateSaveState);
    _canSave = _descriptionController.text.trim().isNotEmpty;
  }

  @override
  void dispose() {
    _descriptionController.removeListener(_updateSaveState);
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _updateSaveState() {
    final canSave = _descriptionController.text.trim().isNotEmpty;
    if (canSave != _canSave) setState(() => _canSave = canSave);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Note', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(widget.reference, style: theme.textTheme.bodyMedium),
          ],
        ),
        actions: [
          if (_isExisting)
            IconButton(
              tooltip: 'Supprimer la note',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 140),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: colors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InkWell(
                  onTap: () => setState(() => _verseExpanded = !_verseExpanded),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.menu_book_outlined,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          widget.reference,
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: AppColors.secondary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Icon(
                        _verseExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                      ),
                    ],
                  ),
                ),
                if (_verseExpanded) ...[
                  const SizedBox(height: 16),
                  Text(
                    widget.verseText,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colors.onSurface,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 26),
          TextField(
            controller: _titleController,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Titre (facultatif)',
              filled: true,
              fillColor: colors.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _descriptionController,
            autofocus: !_isExisting,
            minLines: 10,
            maxLines: 18,
            textAlignVertical: TextAlignVertical.top,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Description',
              filled: true,
              fillColor: colors.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
          decoration: BoxDecoration(
            color: colors.surface,
            border: Border(top: BorderSide(color: colors.outlineVariant)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler'),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _canSave ? _save : null,
                child: const Text('Sauvegarder'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _save() {
    Navigator.pop(
      context,
      NoteScreenResult(
        action: NoteScreenAction.save,
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Supprimer la note ?'),
        content: Text('La note de ${widget.reference} sera supprimée.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    Navigator.pop(
      context,
      const NoteScreenResult(action: NoteScreenAction.delete),
    );
  }
}
