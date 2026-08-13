import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/services/personal_study_service.dart';
import 'package:flutter/material.dart';

class PersonalStudyEditorScreen extends StatefulWidget {
  final PersonalStudy? study;

  const PersonalStudyEditorScreen({super.key, this.study});

  @override
  State<PersonalStudyEditorScreen> createState() =>
      _PersonalStudyEditorScreenState();
}

class _PersonalStudyEditorScreenState extends State<PersonalStudyEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  late final TextEditingController _reference;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.study?.title ?? '');
    _content = TextEditingController(text: widget.study?.content ?? '');
    _reference = TextEditingController(text: widget.study?.reference ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _reference.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        titleSpacing: 0,
        title: TextField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          decoration: const InputDecoration(
            hintText: 'Document sans titre',
            border: InputBorder.none,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Enregistrer',
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox.square(
                    dimension: 19,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_rounded),
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'reference') _showReferenceEditor();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'reference',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.menu_book_rounded),
                  title: Text('Référence biblique'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_reference.text.trim().isNotEmpty)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(18, 12, 18, 0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8EEFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.primary,
                    size: 19,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      _reference.text,
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Modifier la référence',
                    onPressed: _showReferenceEditor,
                    icon: const Icon(Icons.edit_outlined, size: 18),
                  ),
                ],
              ),
            ),
          Expanded(
            child: TextField(
              controller: _content,
              expands: true,
              minLines: null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              textCapitalization: TextCapitalization.sentences,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 17,
                height: 1.55,
              ),
              decoration: const InputDecoration(
                hintText: 'Créer votre étude…',
                hintStyle: TextStyle(fontStyle: FontStyle.italic),
                contentPadding: EdgeInsets.fromLTRB(22, 22, 22, 80),
                border: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: _FormattingBar(
          onBold: () => _wrapSelection('**', '**'),
          onItalic: () => _wrapSelection('_', '_'),
          onUnderline: () => _wrapSelection('<u>', '</u>'),
          onBullet: () => _prefixSelection('• '),
          onReference: _showReferenceEditor,
        ),
      ),
    );
  }

  Future<void> _showReferenceEditor() async {
    final controller = TextEditingController(text: _reference.text);
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Référence biblique'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ex. Jean 3:16',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Ajouter'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value != null && mounted) {
      setState(() => _reference.text = value);
    }
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Écrivez le contenu de votre étude.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await PersonalStudyService.save(
        id: widget.study?.id,
        title: title.isEmpty ? 'Document sans titre' : title,
        content: content,
        reference: _reference.text,
      );
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _wrapSelection(String before, String after) {
    final value = _content.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final replacement = '$before${value.text.substring(start, end)}$after';
    _content.value = value.copyWith(
      text: value.text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  void _prefixSelection(String prefix) {
    final value = _content.value;
    final selection = value.selection;
    final start = selection.isValid ? selection.start : value.text.length;
    final end = selection.isValid ? selection.end : value.text.length;
    final replacement = value.text
        .substring(start, end)
        .split('\n')
        .map((line) => '$prefix$line')
        .join('\n');
    _content.value = value.copyWith(
      text: value.text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }
}

class _FormattingBar extends StatelessWidget {
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onBullet;
  final VoidCallback onReference;

  const _FormattingBar({
    required this.onBold,
    required this.onItalic,
    required this.onUnderline,
    required this.onBullet,
    required this.onReference,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          const Text(
            'Normal',
            style: TextStyle(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(onPressed: onBold, icon: const Icon(Icons.format_bold)),
          IconButton(
              onPressed: onItalic, icon: const Icon(Icons.format_italic)),
          IconButton(
            onPressed: onUnderline,
            icon: const Icon(Icons.format_underlined),
          ),
          IconButton(
            onPressed: onBullet,
            icon: const Icon(Icons.format_list_bulleted),
          ),
          IconButton(
            tooltip: 'Ajouter une référence',
            onPressed: onReference,
            icon: const Icon(Icons.add_box_outlined),
          ),
        ],
      ),
    );
  }
}
