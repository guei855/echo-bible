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
  final Future<void> Function() onInsert;
  final VoidCallback onDivider;
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
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          child: Row(
            children: [
              Builder(
                builder: (anchor) => TextButton(
                  key: const Key('rich-style'),
                  onPressed: () => _showStyles(anchor),
                  child: const Text('Style'),
                ),
              ),
              _toggleButton(
                Attribute.bold,
                Icons.format_bold,
                'Gras',
                'rich-bold',
              ),
              _toggleButton(
                Attribute.italic,
                Icons.format_italic,
                'Italique',
                'rich-italic',
              ),
              _toggleButton(
                Attribute.underline,
                Icons.format_underlined,
                'Souligné',
                'rich-underline',
              ),
              Builder(
                builder: (anchor) => IconButton(
                  key: const Key('rich-more'),
                  tooltip: 'Plus de formats',
                  onPressed: () => _showMore(anchor),
                  icon: const Icon(Icons.more_horiz),
                ),
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
    );
  }

  Widget _toggleButton(
    Attribute attribute,
    IconData icon,
    String tooltip,
    String keyName,
  ) {
    final active = widget.controller
            .getSelectionStyle()
            .attributes[attribute.key]
            ?.value ==
        attribute.value;
    return IconButton(
      key: Key(keyName),
      tooltip: tooltip,
      style: active
          ? IconButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            )
          : null,
      onPressed: () => _applyToSelection((controller) {
        final selected =
            controller.getSelectionStyle().attributes[attribute.key]?.value ==
                attribute.value;
        controller.formatSelection(
          selected ? Attribute.clone(attribute, null) : attribute,
        );
      }),
      icon: Icon(icon),
    );
  }

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

  Future<T?> _showAnchored<T>(
    BuildContext anchor,
    List<PopupMenuEntry<T>> items,
  ) {
    return _showAt<T>(_menuPosition(anchor), items);
  }

  RelativeRect _menuPosition(BuildContext anchor) {
    final button = anchor.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final origin = button.localToGlobal(Offset.zero, ancestor: overlay);
    return RelativeRect.fromRect(
      origin & button.size,
      Offset.zero & overlay.size,
    );
  }

  Future<T?> _showAt<T>(
    RelativeRect position,
    List<PopupMenuEntry<T>> items,
  ) {
    return showMenu<T>(
      context: context,
      requestFocus: false,
      position: position,
      items: items,
    );
  }

  Future<void> _showStyles(BuildContext anchor) async {
    final selection = _captureSelection();
    final choice = await _showAnchored<String>(
      anchor,
      [
        for (final item in _styles.entries)
          PopupMenuItem(value: item.key, child: Text(item.value)),
      ],
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

  Future<void> _showMore(BuildContext anchor) async {
    final selection = _captureSelection();
    final position = _menuPosition(anchor);
    final action = await _showAt<String>(position, [
      _item('strike', Icons.format_strikethrough, 'Barré'),
      _item('size', Icons.format_size, 'Taille'),
      _item('color', Icons.format_color_text, 'Couleur texte'),
      _item('highlight', Icons.highlight, 'Surlignage'),
      _item('quote', Icons.format_quote, 'Citation'),
      _item('bullet', Icons.format_list_bulleted, 'Puces'),
      _item('number', Icons.format_list_numbered, 'Numérotation'),
      _item('indent+', Icons.format_indent_increase, 'Retrait +'),
      _item('indent-', Icons.format_indent_decrease, 'Retrait -'),
      _item('align', Icons.format_align_left, 'Alignement'),
      _item('divider', Icons.horizontal_rule, 'Séparateur'),
      _item('undo', Icons.undo, 'Annuler'),
      _item('redo', Icons.redo, 'Rétablir'),
    ]);
    if (!mounted) return;
    _restoreSelection(selection);
    switch (action) {
      case 'strike':
        _toggle(Attribute.strikeThrough);
      case 'size':
        await _showSizes(position, selection);
      case 'color':
        await _showPalette(position, selection, background: false);
      case 'highlight':
        await _showPalette(position, selection, background: true);
      case 'quote':
        _toggle(Attribute.blockQuote);
      case 'bullet':
        _toggle(Attribute.ul);
      case 'number':
        _toggle(Attribute.ol);
      case 'indent+':
        widget.controller.indentSelection(true);
      case 'indent-':
        widget.controller.indentSelection(false);
      case 'align':
        await _showAlignments(position, selection);
      case 'divider':
        widget.onDivider();
      case 'undo':
        if (widget.controller.hasUndo) {
          widget.controller.undo();
        } else if (widget.canUndoBlocks) {
          widget.onUndoBlocks();
        }
      case 'redo':
        if (widget.controller.hasRedo) {
          widget.controller.redo();
        } else if (widget.canRedoBlocks) {
          widget.onRedoBlocks();
        }
      case null:
        break;
    }
    _restoreSelection(selection);
  }

  PopupMenuItem<String> _item(String value, IconData icon, String label) =>
      PopupMenuItem(
        value: value,
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Text(label),
          ],
        ),
      );

  void _toggle(Attribute attribute) {
    final selected = widget.controller
            .getSelectionStyle()
            .attributes[attribute.key]
            ?.value ==
        attribute.value;
    widget.controller.formatSelection(
      selected ? Attribute.clone(attribute, null) : attribute,
    );
  }

  Future<void> _showSizes(
    RelativeRect position,
    TextSelection selection,
  ) async {
    final size = await _showAt<String>(position, const [
      PopupMenuItem(value: 'small', child: Text('Petite')),
      PopupMenuItem(value: 'normal', child: Text('Normale')),
      PopupMenuItem(value: 'large', child: Text('Grande')),
      PopupMenuItem(value: 'huge', child: Text('Très grande')),
    ]);
    if (!mounted) return;
    _restoreSelection(selection);
    if (size != null) {
      widget.controller.formatSelection(
        Attribute.clone(Attribute.size, size == 'normal' ? null : size),
      );
    }
  }

  Future<void> _showPalette(
    RelativeRect position,
    TextSelection selection, {
    required bool background,
  }) async {
    const colors = <String, Color>{
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
    final value = await _showAt<String>(position, [
      for (final color in colors.entries)
        PopupMenuItem(
          value: color.key,
          child: Row(
            children: [
              Container(
                key: Key(
                  '${background ? 'highlight' : 'color'}-${color.key}',
                ),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: color.value,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.black26),
                ),
              ),
              const SizedBox(width: 12),
              Text(color.key),
            ],
          ),
        ),
    ]);
    if (!mounted) return;
    _restoreSelection(selection);
    if (value != null) {
      widget.controller.formatSelection(
        Attribute.clone(
          background ? Attribute.background : Attribute.color,
          value,
        ),
      );
    }
  }

  Future<void> _showAlignments(
    RelativeRect position,
    TextSelection selection,
  ) async {
    final value = await _showAt<Attribute<String?>>(position, [
      const PopupMenuItem(
        value: Attribute.leftAlignment,
        child: Text('Gauche'),
      ),
      const PopupMenuItem(
        value: Attribute.centerAlignment,
        child: Text('Centre'),
      ),
      const PopupMenuItem(
        value: Attribute.rightAlignment,
        child: Text('Droite'),
      ),
      const PopupMenuItem(
        value: Attribute.justifyAlignment,
        child: Text('Justifié'),
      ),
    ]);
    if (!mounted) return;
    _restoreSelection(selection);
    if (value != null) widget.controller.formatSelection(value);
  }

  Future<void> _insert() async {
    final selection = _captureSelection();
    await widget.onInsert();
    if (mounted) _restoreSelection(selection);
  }
}
