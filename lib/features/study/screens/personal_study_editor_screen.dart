import 'dart:async';

import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/features/bible/models/bible_book.dart';
import 'package:echo_bible/features/bible/models/bible_version.dart';
import 'package:echo_bible/features/bible/repositories/bible_version_repository.dart';
import 'package:echo_bible/features/bible/screens/chapter_reader_screen.dart';
import 'package:echo_bible/features/dictionary/data/repository/dictionary_repository.dart';
import 'package:echo_bible/features/dictionary/models/dictionary_entry.dart';
import 'package:echo_bible/features/dictionary/screens/dictionary_detail_screen.dart';
import 'package:echo_bible/features/study/models/personal_study.dart';
import 'package:echo_bible/features/study/models/cross_reference.dart';
import 'package:echo_bible/features/study/models/verse_study_data.dart';
import 'package:echo_bible/features/study/repositories/cross_reference_repository.dart';
import 'package:echo_bible/features/study/repositories/strong_repository.dart';
import 'package:echo_bible/features/study/screens/strong_word_screen.dart';
import 'package:echo_bible/features/study/services/personal_study_service.dart';
import 'package:echo_bible/features/study/services/study_export_service.dart';
import 'package:echo_bible/features/study/services/study_rich_text_codec.dart';
import 'package:echo_bible/features/study/widgets/study_rich_toolbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

@visibleForTesting
double studyToolbarBottomInset(MediaQueryData mediaQuery) =>
    mediaQuery.viewInsets.bottom;

class _StudyInsertionAnchor {
  const _StudyInsertionAnchor(this.blockId, this.selection);

  final String blockId;
  final TextSelection selection;
}

class PersonalStudyEditorScreen extends StatefulWidget {
  const PersonalStudyEditorScreen({
    super.key,
    required this.study,
    this.saveDocument,
    this.autosaveDelay = const Duration(milliseconds: 700),
    this.onActiveController,
    this.onActiveFocusNode,
    this.focusOnOpen = false,
    this.openingBlockId,
    this.openingMessage,
  });
  final PersonalStudy study;
  final Future<void> Function(PersonalStudy study)? saveDocument;
  final Duration autosaveDelay;
  final ValueChanged<QuillController>? onActiveController;
  final ValueChanged<FocusNode>? onActiveFocusNode;
  final bool focusOnOpen;
  final String? openingBlockId;
  final String? openingMessage;

  @override
  State<PersonalStudyEditorScreen> createState() =>
      _PersonalStudyEditorScreenState();
}

class _PersonalStudyEditorScreenState extends State<PersonalStudyEditorScreen>
    with WidgetsBindingObserver {
  late PersonalStudy _study;
  late final TextEditingController _title;
  final Map<String, QuillController> _controllers = {};
  final Map<String, FocusNode> _focusNodes = {};
  final Map<String, StreamSubscription<dynamic>> _documentSubscriptions = {};
  final Map<String, GlobalKey> _blockKeys = {};
  final List<List<StudyBlock>> _undo = [];
  final List<List<StudyBlock>> _redo = [];
  final ScrollController _scrollController = ScrollController();
  Timer? _saveTimer;
  Timer? _snackBarTimer;
  Timer? _highlightTimer;
  Future<void>? _saveInFlight;
  String? _activeBlockId;
  String? _selectedSpecialBlockId;
  bool _saving = false;
  bool _saved = true;
  bool _finishing = false;
  int _revision = 0;
  String? _highlightedBlockId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final normalized = StudyRichTextCodec.normalizeBlocks(widget.study.blocks);
    final migrated = normalized.length != widget.study.blocks.length ||
        widget.study.blocks.any((block) =>
            StudyRichTextCodec.isLegacyText(block) &&
            !StudyRichTextCodec.isRichText(block));
    _study = widget.study.copyWith(blocks: normalized);
    _title = TextEditingController(text: _study.title)..addListener(_changed);
    _syncControllers();
    if (widget.openingBlockId case final blockId?) {
      _highlightedBlockId = blockId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_revealOpeningBlock(blockId));
      });
    }
    if (migrated) _changed();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      unawaited(_saveNow());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _saveTimer?.cancel();
    _snackBarTimer?.cancel();
    _highlightTimer?.cancel();
    _scrollController.dispose();
    _title.removeListener(_changed);
    _title.dispose();
    for (final subscription in _documentSubscriptions.values) {
      subscription.cancel();
    }
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes.values) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _syncControllers() {
    final ids = _study.blocks
        .where(StudyRichTextCodec.isRichText)
        .map((block) => block.id)
        .toSet();
    for (final id
        in _controllers.keys.where((id) => !ids.contains(id)).toList()) {
      final subscription = _documentSubscriptions.remove(id);
      final controller = _controllers.remove(id);
      final focusNode = _focusNodes.remove(id);
      // Let QuillEditor unmount before destroying objects it still depends on.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(subscription?.cancel());
        controller?.dispose();
        focusNode?.dispose();
      });
    }
    for (final block in _study.blocks.where(StudyRichTextCodec.isRichText)) {
      _controllers.putIfAbsent(block.id, () {
        final controller = QuillController(
          document: StudyRichTextCodec.documentFromBlock(block),
          selection: const TextSelection.collapsed(offset: 0),
        );
        _documentSubscriptions[block.id] = controller.document.changes
            .listen((_) => _onDocumentChanged(block.id));
        final focusNode = FocusNode(debugLabel: 'study-rich-${block.id}');
        focusNode.addListener(() {
          if (!focusNode.hasFocus ||
              !mounted ||
              _focusNodes[block.id] != focusNode) {
            return;
          }
          setState(() {
            _activeBlockId = block.id;
            _selectedSpecialBlockId = null;
          });
          widget.onActiveController?.call(controller);
          widget.onActiveFocusNode?.call(focusNode);
        });
        _focusNodes[block.id] = focusNode;
        return controller;
      });
    }
    if (!ids.contains(_activeBlockId)) {
      _activeBlockId = ids.isEmpty ? null : ids.first;
    }
    final active = _activeController;
    if (active != null) widget.onActiveController?.call(active);
    final activeFocus = _activeFocusNode;
    if (activeFocus != null) widget.onActiveFocusNode?.call(activeFocus);
  }

  void _onDocumentChanged(String id) {
    final index = _study.blocks.indexWhere((block) => block.id == id);
    final controller = _controllers[id];
    if (index < 0 || controller == null) return;
    final blocks = [..._study.blocks];
    blocks[index] = blocks[index].copyWith(
      payload: StudyRichTextCodec.payloadFromDocument(controller.document),
      updatedAt: DateTime.now(),
    );
    _study = _study.copyWith(blocks: blocks);
    _changed(rebuild: false);
  }

  void _changed({bool rebuild = true}) {
    _saveTimer?.cancel();
    _revision++;
    if (mounted && _saved) {
      setState(() => _saved = false);
    } else if (mounted && rebuild) {
      setState(() {});
    }
    _saveTimer = Timer(widget.autosaveDelay, _saveNow);
  }

  Future<void> _saveNow() async {
    _saveTimer?.cancel();
    while (!_saved) {
      final running = _saveInFlight;
      if (running != null) {
        await running;
        continue;
      }
      final revision = _revision;
      final operation = _persist(revision);
      _saveInFlight = operation;
      try {
        await operation;
      } finally {
        if (identical(_saveInFlight, operation)) _saveInFlight = null;
      }
    }
  }

  Future<void> _persist(int revision) async {
    _saving = true;
    if (mounted) setState(() {});
    final title =
        _title.text.trim().isEmpty ? 'Document sans titre' : _title.text.trim();
    final blocks = [
      for (final block in _study.blocks)
        if (_controllers[block.id] case final controller?)
          block.copyWith(
            payload:
                StudyRichTextCodec.payloadFromDocument(controller.document),
          )
        else
          block,
    ];
    final snapshot = _study.copyWith(
      title: title,
      blocks: blocks,
      updatedAt: DateTime.now(),
    );
    try {
      await (widget.saveDocument ??
          PersonalStudyService.saveDocument)(snapshot);
      final savedLatestRevision = revision == _revision;
      if (savedLatestRevision) _study = snapshot;
      _saved = savedLatestRevision;
      if (mounted) setState(() {});
    } finally {
      _saving = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _finish() async {
    if (_finishing) return;
    _finishing = true;
    FocusManager.instance.primaryFocus?.unfocus();
    _snackBarTimer?.cancel();
    if (mounted) ScaffoldMessenger.of(context).hideCurrentSnackBar();
    try {
      await _saveNow();
      if (mounted) Navigator.pop(context, true);
    } on Object {
      _finishing = false;
      if (mounted) _message('Impossible d\u2019enregistrer le document.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: colors.surface,
        appBar: AppBar(
          leading: IconButton(
            tooltip: 'Retour',
            onPressed: _finish,
            icon: const Icon(Icons.arrow_back),
          ),
          titleSpacing: 0,
          title: TextField(
            key: const Key('study-title'),
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            decoration: const InputDecoration(
              hintText: 'Document sans titre',
              border: InputBorder.none,
            ),
          ),
          actions: [
            Center(
              child: Text(
                _saving ? 'Enregistrement…' : (_saved ? 'Sauvegardé' : ''),
                key: const Key('autosave-status'),
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
            ),
            IconButton(
              tooltip: 'Terminer',
              onPressed: _finish,
              icon: const Icon(Icons.check),
            ),
            PopupMenuButton<String>(
              onSelected: _documentAction,
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rename', child: Text('Renommer')),
                const PopupMenuItem(
                    value: 'duplicate', child: Text('Dupliquer')),
                PopupMenuItem(
                  value: 'favorite',
                  child: Text(_study.isFavorite
                      ? 'Retirer des favoris'
                      : 'Ajouter aux favoris'),
                ),
                PopupMenuItem(
                  value: 'pin',
                  child: Text(_study.isPinned ? 'Désépingler' : 'Épingler'),
                ),
                const PopupMenuItem(
                    value: 'metadata', child: Text('Référence et tags')),
                PopupMenuItem(
                  value: 'status',
                  child: Text(_study.status == StudyStatus.draft
                      ? 'Marquer comme finalisé'
                      : 'Repasser en brouillon'),
                ),
                const PopupMenuItem(
                    value: 'export', child: Text('Exporter / partager')),
                const PopupMenuDivider(),
                const PopupMenuItem(
                    value: 'delete', child: Text('Supprimer le document')),
              ],
            ),
          ],
        ),
        body: Column(
          children: [
            if (_study.primaryReference?.isNotEmpty ?? false)
              _ReferenceBanner(reference: _study.primaryReference!),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) => ListView.builder(
                  key: const Key('study-block-list'),
                  controller: _scrollController,
                  padding: const EdgeInsets.only(bottom: 96),
                  itemCount: _study.blocks.length,
                  itemBuilder: (context, index) {
                    final block = _study.blocks[index];
                    late final Widget child;
                    if (StudyRichTextCodec.isRichText(block)) {
                      final controller = _controllers[block.id]!;
                      child = QuillEditor.basic(
                        key: Key('study-rich-editor-${block.id}'),
                        controller: controller,
                        focusNode: _focusNodes[block.id],
                        config: QuillEditorConfig(
                          scrollable: false,
                          expands: false,
                          autoFocus: index == 0 &&
                              (widget.focusOnOpen ||
                                  controller.document
                                      .toPlainText()
                                      .trim()
                                      .isEmpty),
                          minHeight: index == _study.blocks.length - 1
                              ? constraints.maxHeight * .62
                              : 72,
                          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                          placeholder: 'Écrivez votre étude…',
                          enableAlwaysIndentOnTab: true,
                        ),
                      );
                    } else {
                      child = _SpecialStudyBlock(
                        key: ValueKey(block.id),
                        block: block,
                        selected: _selectedSpecialBlockId == block.id,
                        onOpen: () => _openBlock(block),
                        onSelect: () => setState(
                          () => _selectedSpecialBlockId = block.id,
                        ),
                        onDelete: () => _deleteBlock(index),
                        onMoveUp:
                            index > 0 ? () => _moveBlock(index, -1) : null,
                        onMoveDown: index < _study.blocks.length - 1
                            ? () => _moveBlock(index, 1)
                            : null,
                      );
                    }
                    final highlighted = _highlightedBlockId == block.id;
                    return AnimatedContainer(
                      key: _blockKeys.putIfAbsent(block.id, GlobalKey.new),
                      duration: const Duration(milliseconds: 220),
                      decoration: BoxDecoration(
                        color: highlighted
                            ? colors.primaryContainer.withValues(alpha: .48)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: child,
                    );
                  },
                ),
              ),
            ),
          ],
        ),
        bottomNavigationBar: AnimatedPadding(
          key: const Key('study-toolbar-ime-padding'),
          padding: EdgeInsets.only(
            bottom: studyToolbarBottomInset(MediaQuery.of(context)),
          ),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          child: SafeArea(
            top: false,
            child: _activeController == null
                ? const SizedBox.shrink()
                : StudyRichToolbar(
                    key: const Key('study-rich-toolbar'),
                    controller: _activeController!,
                    focusNode: _activeFocusNode!,
                    onInsert: _showInsertMenu,
                    onDivider: (selection) => _insertBlock(
                      StudyBlockType.divider,
                      const {},
                      anchor: _insertionAnchor(selection),
                    ),
                    onHideKeyboard: () =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    onUndoBlocks: _undoBlocks,
                    onRedoBlocks: _redoBlocks,
                    canUndoBlocks: _undo.isNotEmpty,
                    canRedoBlocks: _redo.isNotEmpty,
                  ),
          ),
        ),
      ),
    );
  }

  Future<void> _revealOpeningBlock(String blockId) async {
    await Future<void>.delayed(const Duration(milliseconds: 120));
    if (!mounted) return;
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
      );
    }
    if (!mounted) return;
    final blockContext = _blockKeys[blockId]?.currentContext;
    if (blockContext != null && blockContext.mounted) {
      await Scrollable.ensureVisible(
        blockContext,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        alignment: .35,
      );
    }
    if (!mounted) return;
    if (widget.openingMessage case final message?) {
      final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          MediaQuery.viewInsetsOf(context).bottom +
              MediaQuery.paddingOf(context).bottom +
              StudyRichToolbar.height +
              8,
        ),
      ));
    }
    _highlightTimer?.cancel();
    _highlightTimer = Timer(const Duration(milliseconds: 1400), () {
      if (mounted) setState(() => _highlightedBlockId = null);
    });
  }

  void _remember() {
    _undo.add([..._study.blocks]);
    if (_undo.length > 30) _undo.removeAt(0);
    _redo.clear();
  }

  void _replaceBlocks(List<StudyBlock> blocks) {
    final normalized = StudyRichTextCodec.normalizeBlocks(blocks);
    setState(() => _study = _study.copyWith(blocks: normalized));
    _syncControllers();
    _changed(rebuild: false);
  }

  void _moveBlock(int index, int delta) {
    final newIndex = index + delta;
    if (newIndex < 0 || newIndex >= _study.blocks.length) return;
    _remember();
    final blocks = [..._study.blocks];
    blocks.insert(newIndex, blocks.removeAt(index));
    _replaceBlocks([
      for (var index = 0; index < blocks.length; index++)
        blocks[index].copyWith(position: index, updatedAt: DateTime.now()),
    ]);
  }

  void _deleteBlock(int index) {
    final removed = _study.blocks[index];
    _remember();
    final blocks = [..._study.blocks]..removeAt(index);
    _replaceBlocks(blocks);
    _snackBarTimer?.cancel();
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      duration: const Duration(seconds: 2),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(
        16,
        8,
        16,
        MediaQuery.viewInsetsOf(context).bottom +
            MediaQuery.paddingOf(context).bottom +
            StudyRichToolbar.height +
            8,
      ),
      content: const Text('Bloc supprimé.'),
      action: SnackBarAction(
        label: 'Annuler',
        onPressed: () {
          if (!mounted) return;
          _snackBarTimer?.cancel();
          final restored = [..._study.blocks]..insert(index, removed);
          _replaceBlocks(restored);
          messenger.hideCurrentSnackBar();
        },
      ),
    ));
    _snackBarTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) messenger.hideCurrentSnackBar();
    });
  }

  QuillController? get _activeController {
    final active = _controllers[_activeBlockId];
    if (active != null) return active;
    return _controllers.values.isEmpty ? null : _controllers.values.last;
  }

  FocusNode? get _activeFocusNode {
    final active = _focusNodes[_activeBlockId];
    if (active != null) return active;
    return _focusNodes.values.isEmpty ? null : _focusNodes.values.last;
  }

  /* Legacy markup toolbar removed in V1.1.
  void _wrapSelection(String before, String after) {
    final controller = _activeController;
    if (controller == null) return;
    _remember();
    final value = controller.value;
    final start =
        value.selection.isValid ? value.selection.start : value.text.length;
    final end =
        value.selection.isValid ? value.selection.end : value.text.length;
    final replacement = '$before${value.text.substring(start, end)}$after';
    controller.value = value.copyWith(
      text: value.text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  void _prefixSelection(String prefix) {
    final controller = _activeController;
    if (controller == null) return;
    _remember();
    final value = controller.value;
    final start =
        value.selection.isValid ? value.selection.start : value.text.length;
    final end =
        value.selection.isValid ? value.selection.end : value.text.length;
    final replacement = value.text
        .substring(start, end)
        .split('\n')
        .map((line) => '$prefix$line')
        .join('\n');
    controller.value = value.copyWith(
      text: value.text.replaceRange(start, end, replacement),
      selection: TextSelection.collapsed(offset: start + replacement.length),
    );
  }

  Future<void> _chooseStyle() async {
    const styles = [
      'Normal',
      'Titre 1',
      'Titre 2',
      'Titre 3',
      'Sous-titre',
      'Parole forte',
      'Application',
      'Note personnelle'
    ];
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final style in styles)
              ListTile(
                  title: Text(style),
                  onTap: () => Navigator.pop(context, style))
          ],
        ),
      ),
    );
    if (value == null) return;
    final controller = _activeController;
    String? id;
    for (final entry in _controllers.entries) {
      if (entry.value == controller) {
        id = entry.key;
        break;
      }
    }
    final index = _study.blocks.indexWhere((block) => block.id == id);
    if (index < 0) return;
    _remember();
    final blocks = [..._study.blocks];
    final heading = value.startsWith('Titre') || value == 'Sous-titre';
    blocks[index] = blocks[index].copyWith(
      type: heading ? StudyBlockType.heading : StudyBlockType.text,
      payload: {
        ...blocks[index].payload,
        'style': {'name': value.toLowerCase()}
      },
    );
    _replaceBlocks(blocks);
  }

  Future<void> _moreFormatting() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Wrap(children: [
          _formatTile(context, 'strike', Icons.format_strikethrough, 'Barré'),
          _formatTile(
              context, 'color', Icons.format_color_text, 'Couleur texte'),
          _formatTile(context, 'highlight', Icons.highlight, 'Surlignage'),
          _formatTile(context, 'quote', Icons.format_quote, 'Citation'),
          _formatTile(
              context, 'bullet', Icons.format_list_bulleted, 'Liste à puces'),
          _formatTile(
              context, 'number', Icons.format_list_numbered, 'Liste numérotée'),
          _formatTile(context, 'divider', Icons.horizontal_rule, 'Séparateur'),
          _formatTile(context, 'undo', Icons.undo, 'Annuler'),
          _formatTile(context, 'redo', Icons.redo, 'Rétablir'),
        ]),
      ),
    );
    switch (action) {
      case 'strike':
        _wrapSelection('~~', '~~');
        break;
      case 'color':
        _wrapSelection('<color=#2563EB>', '</color>');
        break;
      case 'highlight':
        _wrapSelection('<mark>', '</mark>');
        break;
      case 'quote':
        _prefixSelection('> ');
        break;
      case 'bullet':
        _prefixSelection('• ');
        break;
      case 'number':
        _prefixSelection('1. ');
        break;
      case 'divider':
        _insertBlock(StudyBlockType.divider, const {});
        break;
      case 'undo':
        _undoBlocks();
        break;
      case 'redo':
        _redoBlocks();
        break;
    }
  }

  Widget _formatTile(
          BuildContext context, String value, IconData icon, String label) =>
      SizedBox(
        width: MediaQuery.sizeOf(context).width / 3,
        child: ListTile(
          leading: Icon(icon),
          title: Text(label, style: const TextStyle(fontSize: 12)),
          onTap: () => Navigator.pop(context, value),
        ),
      );

  */
  void _undoBlocks() {
    if (_undo.isEmpty) return;
    _redo.add([..._study.blocks]);
    _replaceBlocks(_undo.removeLast());
  }

  void _redoBlocks() {
    if (_redo.isEmpty) return;
    _undo.add([..._study.blocks]);
    _replaceBlocks(_redo.removeLast());
  }

  _StudyInsertionAnchor _insertionAnchor(TextSelection selection) =>
      _StudyInsertionAnchor(
        _activeBlockId ?? _study.blocks.last.id,
        selection,
      );

  void _restoreInsertionAnchor(_StudyInsertionAnchor anchor) {
    final controller = _controllers[anchor.blockId];
    final focusNode = _focusNodes[anchor.blockId];
    if (controller == null || focusNode == null) return;
    final maxOffset = controller.document.length;
    if (anchor.selection.isValid && anchor.selection.end <= maxOffset) {
      controller.updateSelection(anchor.selection, ChangeSource.local);
    }
    focusNode.requestFocus();
  }

  Future<void> _showInsertMenu(TextSelection savedSelection) async {
    final anchor = _insertionAnchor(savedSelection);
    final type = await showModalBottomSheet<StudyBlockType>(
      context: context,
      isScrollControlled: true,
      requestFocus: false,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) {
        final media = MediaQuery.of(context);
        return Padding(
          padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: (media.size.height -
                      media.viewInsets.bottom -
                      media.padding.vertical -
                      32)
                  .clamp(180, 620),
            ),
            child: ListView(
              key: const Key('study-insert-menu-scrollable'),
              shrinkWrap: true,
              children: [
                const ListTile(title: Text('Insérer dans l’étude')),
                _insertTile(
                    context, StudyBlockType.verse, Icons.menu_book, 'Verset'),
                _insertTile(context, StudyBlockType.verseRange,
                    Icons.library_books, 'Passage'),
                _insertTile(context, StudyBlockType.verseLink, Icons.link,
                    'Référence cliquable'),
                _insertTile(context, StudyBlockType.strong, Icons.translate,
                    'Bloc Strong'),
                _insertTile(context, StudyBlockType.dictionary,
                    Icons.menu_book_outlined, 'Définition Vigouroux'),
                _insertTile(context, StudyBlockType.crossReferences,
                    Icons.account_tree, 'Références croisées'),
                _insertTile(context, StudyBlockType.comparison,
                    Icons.compare_arrows, 'Comparaison'),
                _insertTile(context, StudyBlockType.divider,
                    Icons.horizontal_rule, 'Séparateur'),
                _insertTile(context, StudyBlockType.image, Icons.image_outlined,
                    'Image'),
              ],
            ),
          ),
        );
      },
    );
    if (!mounted) return;
    if (type == null) {
      _restoreInsertionAnchor(anchor);
      return;
    }
    if (type == StudyBlockType.divider) {
      _insertBlock(type, const {}, anchor: anchor);
    } else if (type == StudyBlockType.strong) {
      await _insertStrong(anchor);
    } else if (type == StudyBlockType.dictionary) {
      await _insertDictionary(anchor);
    } else if (type == StudyBlockType.image) {
      await _insertImagePlaceholder(anchor);
    } else {
      await _insertBible(type, anchor);
    }
    if (mounted && _controllers.containsKey(anchor.blockId)) {
      _restoreInsertionAnchor(anchor);
    }
  }

  Widget _insertTile(BuildContext context, StudyBlockType type, IconData icon,
          String label) =>
      ListTile(
        leading: Icon(icon),
        title: Text(label),
        onTap: () => Navigator.pop(context, type),
      );

  void _insertBlock(
    StudyBlockType type,
    Map<String, Object?> payload, {
    required _StudyInsertionAnchor anchor,
  }) {
    _remember();
    final now = DateTime.now();
    final result = StudyRichTextCodec.insertAtSelection(
      blocks: _study.blocks,
      richBlockId: anchor.blockId,
      selection: anchor.selection,
      type: type,
      payload: payload,
      now: now,
      idSeed: '${now.microsecondsSinceEpoch}-${_study.blocks.length}',
    );
    _activeBlockId = result.continuationBlockId;
    _replaceBlocks(result.blocks);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final controller = _controllers[result.continuationBlockId];
      final focusNode = _focusNodes[result.continuationBlockId];
      controller?.updateSelection(
        const TextSelection.collapsed(offset: 0),
        ChangeSource.local,
      );
      focusNode?.requestFocus();
    });
  }

  Future<void> _insertBible(
    StudyBlockType type,
    _StudyInsertionAnchor anchor,
  ) async {
    final selection = await _pickPassage();
    if (selection == null) return;
    final book = selection.book;
    final version = selection.version;
    final rows = await BibleVersionRepository.getChapter(
      bookId: book.id,
      chapterNumber: selection.chapter,
      versionId: version.id,
    );
    final selectedRows = rows.where((row) {
      final verse = row['verse_number'] as int;
      return verse >= selection.start && verse <= selection.end;
    }).toList();
    final reference =
        '${book.name} ${selection.chapter}:${selection.start}${selection.end == selection.start ? '' : '-${selection.end}'}';
    final base = <String, Object?>{
      'translationId': version.id,
      'translationLabel': version.abbreviation,
      'bookId': book.id,
      'bookName': book.name,
      'chaptersCount': book.chaptersCount,
      'chapter': selection.chapter,
      'verseStart': selection.start,
      'verseEnd': selection.end,
      'reference': reference,
      'text': selectedRows
          .map((row) => '${row['verse_number']} ${row['text']}')
          .join('\n'),
    };
    if (type == StudyBlockType.comparison) {
      final versions = await BibleVersionRepository.getInstalledVersions();
      if (!mounted) return;
      final selectedVersions = await _pickVersions(versions);
      if (selectedVersions == null || selectedVersions.isEmpty) return;
      final comparisons = <Map<String, Object?>>[];
      for (final installed in selectedVersions) {
        final verseRows = await BibleVersionRepository.getChapter(
          bookId: book.id,
          chapterNumber: selection.chapter,
          versionId: installed.id,
        );
        comparisons.add({
          'id': installed.id,
          'label': installed.abbreviation,
          'text': verseRows
              .where((row) {
                final verse = row['verse_number'] as int;
                return verse >= selection.start && verse <= selection.end;
              })
              .map((row) => '${row['verse_number']} ${row['text']}')
              .join('\n'),
        });
      }
      base['versions'] = comparisons;
    } else if (type == StudyBlockType.crossReferences) {
      final references = await const CrossReferenceRepository().forVerse(
        book.id,
        selection.chapter,
        selection.start,
        versionId: version.id,
      );
      if (!mounted) return;
      final selectedReferences = await _pickCrossReferences(references);
      if (selectedReferences == null || selectedReferences.isEmpty) return;
      base['references'] = selectedReferences
          .map((item) =>
              '${item.bookName} ${item.chapter}:${item.verseLabel} — ${item.text}')
          .toList();
    }
    _insertBlock(type, base, anchor: anchor);
  }

  Future<List<BibleVersion>?> _pickVersions(
    List<BibleVersion> versions,
  ) async {
    final selected = versions.take(3).map((version) => version.id).toSet();
    return showDialog<List<BibleVersion>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Versions à comparer'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final version in versions)
                  CheckboxListTile(
                    value: selected.contains(version.id),
                    title: Text(version.name),
                    subtitle: Text(version.abbreviation),
                    onChanged: (value) => setDialogState(() {
                      if (value == true) {
                        selected.add(version.id);
                      } else {
                        selected.remove(version.id);
                      }
                    }),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(
                        context,
                        versions
                            .where((version) => selected.contains(version.id))
                            .toList(),
                      ),
              child: const Text('Comparer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<List<CrossReference>?> _pickCrossReferences(
    List<CrossReference> references,
  ) async {
    final selected = <int>{};
    return showDialog<List<CrossReference>>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choisir les références'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: references.length,
              itemBuilder: (context, index) {
                final item = references[index];
                return CheckboxListTile(
                  value: selected.contains(index),
                  title: Text(
                    '${item.bookName} ${item.chapter}:${item.verseLabel}',
                  ),
                  subtitle: Text(
                    item.text,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onChanged: (_) => setDialogState(() {
                    if (!selected.add(index)) selected.remove(index);
                  }),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.pop(
                        context,
                        selected.map((index) => references[index]).toList(),
                      ),
              child: const Text('Insérer'),
            ),
          ],
        ),
      ),
    );
  }

  Future<_PassageSelection?> _pickPassage() async {
    final versions = await BibleVersionRepository.getInstalledVersions();
    if (versions.isEmpty || !mounted) return null;
    var version = versions.first;
    var books = await BibleVersionRepository.getBooks(versionId: version.id);
    if (books.isEmpty || !mounted) return null;
    var book = books.first;
    var chapter = 1;
    var start = 1;
    var end = 1;
    return showDialog<_PassageSelection>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Choisir un passage'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              DropdownButtonFormField<BibleVersion>(
                initialValue: version,
                decoration: const InputDecoration(labelText: 'Version'),
                items: [
                  for (final item in versions)
                    DropdownMenuItem(
                        value: item, child: Text(item.abbreviation))
                ],
                onChanged: (value) async {
                  if (value == null) return;
                  final nextBooks = await BibleVersionRepository.getBooks(
                      versionId: value.id);
                  setDialogState(() {
                    version = value;
                    books = nextBooks;
                    book = books.first;
                    chapter = 1;
                  });
                },
              ),
              DropdownButtonFormField<BibleBook>(
                initialValue: book,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Livre'),
                items: [
                  for (final item in books)
                    DropdownMenuItem(value: item, child: Text(item.name))
                ],
                onChanged: (value) => setDialogState(() {
                  book = value ?? book;
                  chapter = 1;
                }),
              ),
              Row(children: [
                Expanded(
                    child: TextFormField(
                        initialValue: '1',
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Chapitre'),
                        onChanged: (value) =>
                            chapter = int.tryParse(value) ?? 1)),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        initialValue: '1',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Début'),
                        onChanged: (value) =>
                            start = int.tryParse(value) ?? 1)),
                const SizedBox(width: 8),
                Expanded(
                    child: TextFormField(
                        initialValue: '1',
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Fin'),
                        onChanged: (value) =>
                            end = int.tryParse(value) ?? start)),
              ]),
            ]),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Annuler')),
            FilledButton(
                onPressed: () => Navigator.pop(
                    context,
                    _PassageSelection(
                        version,
                        book,
                        chapter.clamp(1, book.chaptersCount),
                        start.clamp(1, 999),
                        end.clamp(start, 999))),
                child: const Text('Insérer')),
          ],
        ),
      ),
    );
  }

  Future<void> _insertStrong(_StudyInsertionAnchor anchor) async {
    final query = await _ask('Insérer un bloc Strong', 'Ex. G3056');
    if (query == null) return;
    try {
      final entry = await const StrongRepository().findByNumber(query);
      if (entry == null) return _message('Entrée Strong introuvable.');
      if (!mounted) return;
      final displayMode = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.link),
                title: const Text('Insérer un lien Strong'),
                onTap: () => Navigator.pop(context, 'link'),
              ),
              ListTile(
                leading: const Icon(Icons.view_agenda_outlined),
                title: const Text('Insérer un bloc Strong'),
                onTap: () => Navigator.pop(context, 'block'),
              ),
            ],
          ),
        ),
      );
      if (displayMode == null) return;
      _insertBlock(
          StudyBlockType.strong,
          {
            'code': entry.strongNumber,
            'originalWord': entry.originalWord,
            'transliteration': entry.transliteration,
            'definition': entry.frenchDefinition ??
                entry.shortDefinition ??
                entry.definition ??
                '',
            'language': entry.language,
            'displayMode': displayMode,
          },
          anchor: anchor);
    } on Object {
      _message(
          'Le lexique Strong n’est pas installé. Téléchargez-le depuis Ressources.');
    }
  }

  Future<void> _insertDictionary(_StudyInsertionAnchor anchor) async {
    final query = await _ask('Insérer une définition', 'Ex. Alliance');
    if (query == null) return;
    final entries = await const DictionaryRepository().search(query, limit: 10);
    if (!mounted) return;
    if (entries.isEmpty) {
      return _message('Dictionnaire non installé ou article introuvable.');
    }
    final entry = await showDialog<DictionaryEntry>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Choisir un article'),
        children: [
          for (final item in entries)
            SimpleDialogOption(
                onPressed: () => Navigator.pop(context, item),
                child: Text(item.title))
        ],
      ),
    );
    if (entry == null) return;
    _insertBlock(
        StudyBlockType.dictionary,
        {
          'entryId': entry.id,
          'title': entry.title,
          'excerpt': entry.content.length > 420
              ? '${entry.content.substring(0, 420)}…'
              : entry.content,
          'content': entry.content,
          'source': entry.source,
        },
        anchor: anchor);
  }

  Future<void> _insertImagePlaceholder(_StudyInsertionAnchor anchor) async {
    final caption = await _ask('Insérer une image', 'Légende ou chemin local');
    if (caption != null) {
      _insertBlock(
        StudyBlockType.image,
        {'caption': caption},
        anchor: anchor,
      );
    }
  }

  Future<String?> _ask(String title, String hint) async {
    final controller = TextEditingController();
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
                hintText: hint, border: const OutlineInputBorder())),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annuler')),
          FilledButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text('Continuer')),
        ],
      ),
    );
    controller.dispose();
    return value?.isEmpty == true ? null : value;
  }

  void _message(String text) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));

  Future<void> _openBlock(StudyBlock block) async {
    final payload = block.payload;
    if ({
      StudyBlockType.verse,
      StudyBlockType.verseRange,
      StudyBlockType.verseLink,
      StudyBlockType.crossReferences,
      StudyBlockType.comparison
    }.contains(block.type)) {
      final books = await BibleVersionRepository.getBooks(
          versionId: payload['translationId'] as int?);
      final bookId = payload['bookId'] as int?;
      final matches = books.where((book) => book.id == bookId);
      if (!mounted || matches.isEmpty) return;
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => ChapterReaderScreen(
                    book: matches.first,
                    initialChapter: payload['chapter'] as int? ?? 1,
                    initialVerse: payload['verseStart'] as int?,
                    initialVersionId: payload['translationId'] as int?,
                  )));
    } else if (block.type == StudyBlockType.strong) {
      final code = payload['code'] as String? ?? '';
      final entry = await const StrongRepository().findByNumber(code);
      if (!mounted || entry == null) return;
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => StrongWordScreen(
                      word: VerseStrongWord(
                    id: entry.id,
                    order: 0,
                    word: entry.transliteration ?? entry.originalWord,
                    code: entry.strongNumber,
                    originalWord: entry.originalWord,
                    language: entry.language,
                    definition: entry.definition,
                    transliteration: entry.transliteration,
                    frenchDefinition: entry.frenchDefinition,
                    shortDefinition: entry.shortDefinition,
                    source: entry.source,
                    license: entry.license,
                    numberKind: entry.numberKind,
                  ))));
    } else if (block.type == StudyBlockType.dictionary) {
      final content = payload['content'] as String?;
      if (content == null || !mounted) return;
      await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => DictionaryDetailScreen(
                      entry: DictionaryEntry(
                    id: payload['entryId'] as int? ?? 0,
                    headword: payload['title'] as String? ?? '',
                    content: content,
                    source: payload['source'] as String? ?? 'Vigouroux',
                    sourceKind: '',
                    sourceUrl: '',
                    quality: '',
                  ))));
    }
  }

  Future<void> _documentAction(String action) async {
    if (action == 'rename') {
      final value = await _ask('Renommer le document', _title.text);
      if (value == null) return;
      _title.text = value;
      _title.selection = TextSelection.collapsed(offset: value.length);
      return;
    }
    if (action == 'duplicate') {
      await _saveNow();
      await PersonalStudyService.duplicate(_study);
      if (mounted) _message('Copie créée.');
      return;
    }
    if (action == 'favorite') {
      _study = _study.copyWith(isFavorite: !_study.isFavorite);
      _changed();
      return;
    }
    if (action == 'pin') {
      _study = _study.copyWith(isPinned: !_study.isPinned);
      _changed();
      return;
    }
    if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Supprimer ce document ?'),
          content: const Text('Cette action supprimera aussi ses blocs.'),
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
      );
      if (confirmed != true) return;
      await PersonalStudyService.delete(_study.id);
      if (mounted) {
        _snackBarTimer?.cancel();
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        Navigator.pop(context, true);
      }
      return;
    }
    if (action == 'metadata') {
      final reference = TextEditingController(text: _study.primaryReference);
      final tags = TextEditingController(text: _study.tags.join(', '));
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
                title: const Text('Référence principale et tags'),
                content: Column(mainAxisSize: MainAxisSize.min, children: [
                  TextField(
                      controller: reference,
                      decoration: const InputDecoration(
                          labelText: 'Texte principal',
                          hintText: 'Éphésiens 2:8-10')),
                  TextField(
                      controller: tags,
                      decoration: const InputDecoration(
                          labelText: 'Tags', hintText: 'Grâce, Foi, Jeunesse')),
                ]),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Sauvegarder'))
                ],
              ));
      if (confirmed == true) {
        setState(() => _study = _study.copyWith(
            primaryReference: reference.text,
            tags: tags.text
                .split(',')
                .map((tag) => tag.trim())
                .where((tag) => tag.isNotEmpty)
                .toList()));
        _changed();
      }
      reference.dispose();
      tags.dispose();
    } else if (action == 'status') {
      setState(() => _study = _study.copyWith(
          status: _study.status == StudyStatus.draft
              ? StudyStatus.completed
              : StudyStatus.draft));
      _changed();
    } else if (action == 'export') {
      await _saveNow();
      await StudyExportService.share(_study);
    }
  }
}

class _PassageSelection {
  const _PassageSelection(
      this.version, this.book, this.chapter, this.start, this.end);
  final BibleVersion version;
  final BibleBook book;
  final int chapter;
  final int start;
  final int end;
}

class _ReferenceBanner extends StatelessWidget {
  const _ReferenceBanner({required this.reference});
  final String reference;
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Theme.of(context).colorScheme.primaryContainer,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(reference,
            style: TextStyle(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold)),
      );
}

class _SpecialStudyBlock extends StatelessWidget {
  const _SpecialStudyBlock({
    super.key,
    required this.block,
    required this.selected,
    required this.onOpen,
    required this.onSelect,
    required this.onDelete,
    this.onMoveUp,
    this.onMoveDown,
  });

  final StudyBlock block;
  final bool selected;
  final VoidCallback onOpen;
  final VoidCallback onSelect;
  final VoidCallback onDelete;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (block.type == StudyBlockType.divider) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onLongPress: onSelect,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              Divider(color: selected ? colors.primary : null),
              if (selected) _actions(context),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Material(
        color: _background(colors),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected ? colors.primary : colors.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onOpen,
          onLongPress: onSelect,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(_icon, size: 18, color: colors.primary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _label,
                        style: TextStyle(
                          color: colors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                if (block.plainText.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    block.plainText,
                    maxLines: 8,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                if (selected) ...[
                  const SizedBox(height: 8),
                  _actions(context),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actions(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: onOpen,
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Ouvrir'),
          ),
          PopupMenuButton<String>(
            tooltip: 'Actions du bloc',
            onSelected: (value) {
              if (value == 'up') onMoveUp?.call();
              if (value == 'down') onMoveDown?.call();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'up',
                enabled: onMoveUp != null,
                child: const Text('Déplacer vers le haut'),
              ),
              PopupMenuItem(
                value: 'down',
                enabled: onMoveDown != null,
                child: const Text('Déplacer vers le bas'),
              ),
              const PopupMenuItem(
                value: 'delete',
                child: Text('Supprimer'),
              ),
            ],
          ),
        ],
      );

  Color _background(ColorScheme colors) => switch (block.type) {
        StudyBlockType.verse ||
        StudyBlockType.verseRange =>
          colors.primaryContainer.withValues(alpha: .34),
        StudyBlockType.strong =>
          colors.tertiaryContainer.withValues(alpha: .38),
        StudyBlockType.dictionary =>
          colors.secondaryContainer.withValues(alpha: .38),
        _ => colors.surfaceContainerLow,
      };

  String get _label => switch (block.type) {
        StudyBlockType.verse => 'Verset',
        StudyBlockType.verseRange => 'Passage biblique',
        StudyBlockType.verseLink => 'Référence biblique',
        StudyBlockType.strong => 'Strong',
        StudyBlockType.dictionary => 'Dictionnaire Vigouroux',
        StudyBlockType.crossReferences => 'Références croisées',
        StudyBlockType.comparison => 'Comparaison de versions',
        StudyBlockType.image => 'Image',
        _ => 'Ressource',
      };

  IconData get _icon => switch (block.type) {
        StudyBlockType.verse || StudyBlockType.verseRange => Icons.menu_book,
        StudyBlockType.verseLink => Icons.link,
        StudyBlockType.strong => Icons.translate,
        StudyBlockType.dictionary => Icons.menu_book_outlined,
        StudyBlockType.crossReferences => Icons.account_tree,
        StudyBlockType.comparison => Icons.compare_arrows,
        StudyBlockType.image => Icons.image_outlined,
        _ => Icons.widgets_outlined,
      };
}

// ignore: unused_element
class _BlockEditor extends StatelessWidget {
  const _BlockEditor(
      {required super.key,
      required this.block,
      required this.index,
      required this.controller,
      required this.onEditingTap,
      required this.onTap,
      required this.onDelete});
  final StudyBlock block;
  final int index;
  final TextEditingController? controller;
  final VoidCallback onEditingTap;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    if (block.type == StudyBlockType.divider) {
      return _frame(context, const Divider(thickness: 1.4));
    }
    if (controller != null) {
      final heading = block.type == StudyBlockType.heading;
      return _frame(
          context,
          TextField(
            key: Key('study-block-${block.id}'),
            controller: controller,
            onTap: onEditingTap,
            minLines: heading ? 1 : 2,
            maxLines: null,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(
                fontSize: heading ? 20 : 16,
                fontWeight: heading ? FontWeight.bold : FontWeight.normal,
                height: 1.45),
            decoration: InputDecoration(
                hintText: heading ? 'Titre' : 'Écrivez ici…',
                border: InputBorder.none),
          ));
    }
    return _frame(
        context,
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(_icon(block.type), color: AppColors.primary, size: 19),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(_label(block.type),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary))),
                const Icon(Icons.open_in_new, size: 16)
              ]),
              const SizedBox(height: 8),
              Text(block.plainText.isEmpty ? 'Bloc vide' : block.plainText,
                  maxLines: 12, overflow: TextOverflow.ellipsis),
              if ({
                StudyBlockType.verse,
                StudyBlockType.verseRange,
                StudyBlockType.verseLink
              }.contains(block.type)) ...[
                const SizedBox(height: 8),
                const Text('Ouvrir dans la Bible →',
                    style: TextStyle(
                        color: AppColors.primary, fontWeight: FontWeight.bold))
              ],
            ]),
          ),
        ));
  }

  Widget _frame(BuildContext context, Widget child) => Card(
        margin: const EdgeInsets.only(bottom: 10),
        color: block.type == StudyBlockType.text ||
                block.type == StudyBlockType.heading
            ? Colors.transparent
            : null,
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ReorderableDragStartListener(
              index: index,
              child: const Padding(
                  padding: EdgeInsets.fromLTRB(8, 16, 4, 16),
                  child: Icon(Icons.drag_indicator, size: 20))),
          Expanded(child: child),
          IconButton(
              tooltip: 'Supprimer le bloc',
              onPressed: onDelete,
              icon: const Icon(Icons.close, size: 18)),
        ]),
      );

  static String _label(StudyBlockType type) => switch (type) {
        StudyBlockType.verse => 'Verset',
        StudyBlockType.verseRange => 'Passage',
        StudyBlockType.verseLink => 'Référence biblique',
        StudyBlockType.strong => 'Strong',
        StudyBlockType.dictionary => 'Dictionnaire Vigouroux',
        StudyBlockType.crossReferences => 'Références croisées',
        StudyBlockType.comparison => 'Comparaison',
        StudyBlockType.image => 'Image',
        _ => type.name,
      };
  static IconData _icon(StudyBlockType type) => switch (type) {
        StudyBlockType.strong => Icons.translate,
        StudyBlockType.dictionary => Icons.menu_book_outlined,
        StudyBlockType.crossReferences => Icons.account_tree,
        StudyBlockType.comparison => Icons.compare_arrows,
        StudyBlockType.image => Icons.image_outlined,
        _ => Icons.menu_book,
      };
}

// ignore: unused_element
class _FormattingBar extends StatelessWidget {
  const _FormattingBar(
      {required this.canUndo,
      required this.canRedo,
      required this.onStyle,
      required this.onBold,
      required this.onItalic,
      required this.onUnderline,
      required this.onMore,
      required this.onAdd,
      required this.onKeyboard});
  final bool canUndo;
  final bool canRedo;
  final VoidCallback onStyle;
  final VoidCallback onBold;
  final VoidCallback onItalic;
  final VoidCallback onUnderline;
  final VoidCallback onMore;
  final VoidCallback onAdd;
  final VoidCallback onKeyboard;

  @override
  Widget build(BuildContext context) => Material(
        elevation: 10,
        color: Theme.of(context).colorScheme.surface,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          child: Row(children: [
            TextButton(onPressed: onStyle, child: const Text('Style')),
            IconButton(onPressed: onBold, icon: const Icon(Icons.format_bold)),
            IconButton(
                onPressed: onItalic, icon: const Icon(Icons.format_italic)),
            IconButton(
                onPressed: onUnderline,
                icon: const Icon(Icons.format_underlined)),
            IconButton(
                tooltip: 'Plus de formats',
                onPressed: onMore,
                icon: const Icon(Icons.more_horiz)),
            IconButton(
                key: const Key('insert-study-block'),
                tooltip: 'Insérer un bloc',
                onPressed: onAdd,
                icon: const Icon(Icons.add_circle_outline,
                    color: AppColors.primary)),
            IconButton(
                tooltip: 'Masquer le clavier',
                onPressed: onKeyboard,
                icon: const Icon(Icons.keyboard_hide)),
          ]),
        ),
      );
}
