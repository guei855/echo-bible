import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class StudyRichToolbar extends StatefulWidget {
  static const double height = 58;

  const StudyRichToolbar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onInsert,
    required this.onDivider,
    required this.onHideKeyboard,
    required this.onUndoBlocks,
    required this.onRedoBlocks,
    required this.canUndoBlocks,
    required this.canRedoBlocks,
  });

  final QuillController controller;
  final FocusNode focusNode;
  final Future<void> Function(TextSelection selection) onInsert;
  final ValueChanged<TextSelection> onDivider;
  final VoidCallback onHideKeyboard;
  final VoidCallback onUndoBlocks;
  final VoidCallback onRedoBlocks;
  final bool canUndoBlocks;
  final bool canRedoBlocks;

  @override
  State<StudyRichToolbar> createState() => _StudyRichToolbarState();
}

class _StudyRichToolbarState extends State<StudyRichToolbar> {
  static const _styles = <String, String>{
    'normal': 'Normal',
    'title': 'Titre',
    'h1': 'Titre 1',
    'h2': 'Titre 2',
    'h3': 'Titre 3',
    'subtitle': 'Sous-titre',
    'strong': 'Parole forte',
    'application': 'Application',
    'note': 'Note personnelle',
    'quote': 'Citation',
  };
  static const _palette = <String, Color>{
    '#111827': Color(0xFF111827),
    '#1E3A8A': Color(0xFF1E3A8A),
    '#B91C1C': Color(0xFFB91C1C),
    '#047857': Color(0xFF047857),
    '#7E22CE': Color(0xFF7E22CE),
    '#FFF59D': Color(0xFFFFF59D),
    '#BBF7D0': Color(0xFFBBF7D0),
    '#BFDBFE': Color(0xFFBFDBFE),
    '#FBCFE8': Color(0xFFFBCFE8),
    '#FED7AA': Color(0xFFFED7AA),
  };

  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_refresh);
  }

  @override
  void didUpdateWidget(covariant StudyRichToolbar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;
    oldWidget.controller.removeListener(_refresh);
    widget.controller.addListener(_refresh);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_refresh);
    _scrollController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      elevation: 12,
      color: colors.surface,
      child: SizedBox(
        height: StudyRichToolbar.height,
        child: Scrollbar(
          controller: _scrollController,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: SingleChildScrollView(
            key: const Key('study-toolbar-horizontal-scroll'),
            controller: _scrollController,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(7, 4, 7, 6),
            child: Row(
              children: [
                TextButton(
                  key: const Key('rich-style'),
                  onPressed: _showStyles,
                  child: const Text('Style'),
                ),
                _toggleButton(
                    Attribute.bold, Icons.format_bold, 'Gras', 'rich-bold'),
                _toggleButton(Attribute.italic, Icons.format_italic, 'Italique',
                    'rich-italic'),
                _toggleButton(Attribute.underline, Icons.format_underlined,
                    'Souligné', 'rich-underline'),
                _toggleButton(Attribute.strikeThrough,
                    Icons.format_strikethrough, 'Barré', 'rich-strike'),
                _actionButton(
                    Icons.format_size, 'Taille', 'rich-size', _showSizes),
                _actionButton(Icons.format_color_text, 'Couleur du texte',
                    'rich-color', () => _showPalette(background: false)),
                _actionButton(Icons.format_color_fill, 'Surlignage',
                    'rich-highlight', () => _showPalette(background: true)),
                _actionButton(Icons.format_align_left, 'Alignement',
                    'rich-alignment', _showAlignments),
                _toggleButton(Attribute.blockQuote, Icons.format_quote,
                    'Citation', 'rich-quote'),
                _toggleButton(Attribute.ul, Icons.format_list_bulleted,
                    'Liste à puces', 'rich-bullets'),
                _toggleButton(Attribute.ol, Icons.format_list_numbered,
                    'Liste numérotée', 'rich-numbering'),
                _actionButton(
                    Icons.format_indent_decrease,
                    'Retrait -',
                    'rich-indent-decrease',
                    () => _applyToSelection((c) => c.indentSelection(false))),
                _actionButton(
                    Icons.format_indent_increase,
                    'Retrait +',
                    'rich-indent-increase',
                    () => _applyToSelection((c) => c.indentSelection(true))),
                _actionButton(
                  Icons.horizontal_rule,
                  'Séparateur',
                  'rich-divider',
                  () => widget.onDivider(_captureSelection()),
                ),
                _actionButton(
                  Icons.undo,
                  'Annuler',
                  'rich-undo',
                  _undo,
                  enabled: widget.controller.hasUndo || widget.canUndoBlocks,
                ),
                _actionButton(
                  Icons.redo,
                  'Rétablir',
                  'rich-redo',
                  _redo,
                  enabled: widget.controller.hasRedo || widget.canRedoBlocks,
                ),
                IconButton(
                  key: const Key('insert-study-block'),
                  tooltip: 'Insérer une ressource',
                  onPressed: _insert,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: AppColors.primary,
                  ),
                ),
                IconButton(
                  key: const Key('hide-study-keyboard'),
                  tooltip: 'Masquer le clavier',
                  onPressed: widget.onHideKeyboard,
                  icon: const Icon(Icons.keyboard_hide),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _actionButton(
    IconData icon,
    String tooltip,
    String keyName,
    VoidCallback action, {
    bool enabled = true,
  }) =>
      IconButton(
        key: Key(keyName),
        tooltip: tooltip,
        onPressed: enabled ? action : null,
        icon: Icon(icon),
      );

  Widget _toggleButton(
    Attribute attribute,
    IconData icon,
    String tooltip,
    String keyName,
  ) {
    final active = _isActive(attribute);
    return IconButton(
      key: Key(keyName),
      tooltip: tooltip,
      style: active
          ? IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            )
          : null,
      onPressed: () => _applyToSelection((controller) {
        controller.formatSelection(
          _isActive(attribute) ? Attribute.clone(attribute, null) : attribute,
        );
      }),
      icon: Icon(icon),
    );
  }

  bool _isActive(Attribute attribute) =>
      widget.controller.getSelectionStyle().attributes[attribute.key]?.value ==
      attribute.value;

  TextSelection _captureSelection() => widget.controller.selection;

  void _restoreSelection(TextSelection selection) {
    if (!mounted) return;
    final maxOffset = widget.controller.document.length;
    if (selection.isValid && selection.end <= maxOffset) {
      widget.controller.updateSelection(selection, ChangeSource.local);
    }
    widget.focusNode.requestFocus();
  }

  void _applyToSelection(void Function(QuillController controller) action) {
    final selection = _captureSelection();
    _restoreSelection(selection);
    action(widget.controller);
    _restoreSelection(selection);
  }

  Future<T?> _showCompactDialog<T>({
    required String title,
    required Widget Function(BuildContext dialogContext) content,
  }) =>
      showDialog<T>(
        context: context,
        requestFocus: false,
        builder: (dialogContext) {
          final media = MediaQuery.of(dialogContext);
          return AnimatedPadding(
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              24 + media.viewInsets.bottom,
            ),
            duration: const Duration(milliseconds: 120),
            child: Dialog(
              insetPadding: EdgeInsets.zero,
              child: ConstrainedBox(
                key: const Key('study-secondary-menu-scrollable'),
                constraints: BoxConstraints(
                  maxWidth: 360,
                  maxHeight: (media.size.height -
                          media.viewInsets.bottom -
                          media.padding.vertical -
                          48)
                      .clamp(120, 520),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(title,
                          style: Theme.of(dialogContext).textTheme.titleMedium),
                      const SizedBox(height: 12),
                      content(dialogContext),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );

  Future<void> _showStyles() async {
    final selection = _captureSelection();
    final choice = await _showCompactDialog<String>(
      title: 'Style',
      content: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in _styles.entries)
            ListTile(
              dense: true,
              title: Text(item.value),
              onTap: () => Navigator.pop(dialogContext, item.key),
            ),
        ],
      ),
    );
    if (!mounted) return;
    _restoreSelection(selection);
    if (choice == null) return;
    _clearParagraphStyle();
    switch (choice) {
      case 'title':
      case 'h1':
        widget.controller.formatSelection(Attribute.h1);
      case 'h2':
        widget.controller.formatSelection(Attribute.h2);
      case 'h3':
        widget.controller.formatSelection(Attribute.h3);
      case 'subtitle':
        widget.controller
          ..formatSelection(Attribute.h3)
          ..formatSelection(Attribute.italic);
      case 'strong':
        widget.controller
          ..formatSelection(Attribute.bold)
          ..formatSelection(Attribute.clone(Attribute.color, '#1E3A8A'))
          ..formatSelection(Attribute.clone(Attribute.size, 'large'));
      case 'application':
        widget.controller
          ..formatSelection(Attribute.blockQuote)
          ..formatSelection(Attribute.clone(Attribute.background, '#DCFCE7'));
      case 'note':
        widget.controller
          ..formatSelection(Attribute.italic)
          ..formatSelection(Attribute.clone(Attribute.background, '#FEF3C7'));
      case 'quote':
        widget.controller.formatSelection(Attribute.blockQuote);
      case 'normal':
        break;
    }
    _restoreSelection(selection);
  }

  void _clearParagraphStyle() {
    for (final attribute in <Attribute>[
      Attribute.header,
      Attribute.blockQuote,
      Attribute.list,
      Attribute.indent,
      Attribute.size,
      Attribute.color,
      Attribute.background,
    ]) {
      widget.controller.formatSelection(Attribute.clone(attribute, null));
    }
  }

  Future<void> _showSizes() async {
    final selection = _captureSelection();
    final size = await _showCompactDialog<String>(
      title: 'Taille',
      content: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final item in const {
            'small': 'Petite',
            'normal': 'Normale',
            'large': 'Grande',
            'huge': 'Très grande',
          }.entries)
            ListTile(
              dense: true,
              title: Text(item.value),
              onTap: () => Navigator.pop(dialogContext, item.key),
            ),
        ],
      ),
    );
    if (!mounted) return;
    _restoreSelection(selection);
    if (size != null) {
      widget.controller.formatSelection(
        Attribute.clone(Attribute.size, size == 'normal' ? null : size),
      );
    }
  }

  Future<void> _showPalette({required bool background}) async {
    final selection = _captureSelection();
    final current = widget.controller
        .getSelectionStyle()
        .attributes[background ? Attribute.background.key : Attribute.color.key]
        ?.value;
    final value = await _showCompactDialog<String>(
      title: background ? 'Surlignage' : 'Couleur du texte',
      content: (dialogContext) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (current is String && _palette.containsKey(current)) ...[
            const Text('Récente'),
            const SizedBox(height: 8),
            _colorChoice(
                dialogContext, current, _palette[current]!, background),
            const SizedBox(height: 12),
          ],
          const Text('Couleurs standards'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final color in _palette.entries)
                _colorChoice(dialogContext, color.key, color.value, background),
              IconButton(
                tooltip: 'Aucune couleur',
                onPressed: () => Navigator.pop(dialogContext, 'clear'),
                icon: const Icon(Icons.format_color_reset),
              ),
            ],
          ),
        ],
      ),
    );
    if (!mounted) return;
    _restoreSelection(selection);
    if (value != null) {
      widget.controller.formatSelection(
        Attribute.clone(
          background ? Attribute.background : Attribute.color,
          value == 'clear' ? null : value,
        ),
      );
    }
  }

  Widget _colorChoice(
    BuildContext dialogContext,
    String value,
    Color color,
    bool background,
  ) =>
      InkWell(
        key: Key('${background ? 'highlight' : 'color'}-$value'),
        customBorder: const CircleBorder(),
        onTap: () => Navigator.pop(dialogContext, value),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: CircleAvatar(
            radius: 16,
            backgroundColor: color,
            child: color.computeLuminance() > .75
                ? const Icon(Icons.check, color: Colors.black38, size: 16)
                : null,
          ),
        ),
      );

  Future<void> _showAlignments() async {
    final selection = _captureSelection();
    final value = await _showCompactDialog<Attribute<String?>>(
      title: 'Alignement',
      content: (dialogContext) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (final item in <(Attribute<String?>, IconData, String)>[
            (Attribute.leftAlignment, Icons.format_align_left, 'Gauche'),
            (Attribute.centerAlignment, Icons.format_align_center, 'Centre'),
            (Attribute.rightAlignment, Icons.format_align_right, 'Droite'),
            (
              Attribute.justifyAlignment,
              Icons.format_align_justify,
              'Justifié'
            ),
          ])
            IconButton(
              tooltip: item.$3,
              onPressed: () => Navigator.pop(dialogContext, item.$1),
              icon: Icon(item.$2),
            ),
        ],
      ),
    );
    if (!mounted) return;
    _restoreSelection(selection);
    if (value != null) widget.controller.formatSelection(value);
  }

  void _undo() {
    if (widget.controller.hasUndo) {
      widget.controller.undo();
    } else if (widget.canUndoBlocks) {
      widget.onUndoBlocks();
    }
    widget.focusNode.requestFocus();
  }

  void _redo() {
    if (widget.controller.hasRedo) {
      widget.controller.redo();
    } else if (widget.canRedoBlocks) {
      widget.onRedoBlocks();
    }
    widget.focusNode.requestFocus();
  }

  Future<void> _insert() => widget.onInsert(_captureSelection());
}
