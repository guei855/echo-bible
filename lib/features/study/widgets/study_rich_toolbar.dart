import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class StudyRichToolbar extends StatefulWidget {
  const StudyRichToolbar({
    super.key,
    required this.controller,
    required this.onInsert,
    required this.onDivider,
    required this.onHideKeyboard,
    required this.onUndoBlocks,
    required this.onRedoBlocks,
    required this.canUndoBlocks,
    required this.canRedoBlocks,
  });

  final QuillController controller;
  final VoidCallback onInsert;
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
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
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
            IconButton(
              key: const Key('rich-more'),
              tooltip: 'Plus de formats',
              onPressed: _showMore,
              icon: const Icon(Icons.more_horiz),
            ),
            IconButton(
              key: const Key('insert-study-block'),
              tooltip: 'Insérer une ressource',
              onPressed: widget.onInsert,
              icon: const Icon(Icons.add_circle_outline,
                  color: AppColors.primary),
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
      onPressed: () => _toggle(attribute),
      icon: Icon(icon),
    );
  }

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

  Future<void> _showStyles() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => ListView(
        shrinkWrap: true,
        children: [
          for (final item in const {
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
          }.entries)
            ListTile(
              title: Text(item.value),
              onTap: () => Navigator.pop(context, item.key),
            ),
        ],
      ),
    );
    if (choice == null) return;
    _clearParagraphStyle();
    switch (choice) {
      case 'title':
      case 'h1':
        widget.controller.formatSelection(Attribute.h1);
        break;
      case 'h2':
        widget.controller.formatSelection(Attribute.h2);
        break;
      case 'h3':
        widget.controller.formatSelection(Attribute.h3);
        break;
      case 'subtitle':
        widget.controller
          ..formatSelection(Attribute.h3)
          ..formatSelection(Attribute.italic);
        break;
      case 'strong':
        widget.controller
          ..formatSelection(Attribute.bold)
          ..formatSelection(Attribute.clone(Attribute.color, '#1E3A8A'))
          ..formatSelection(Attribute.clone(Attribute.size, 'large'));
        break;
      case 'application':
        widget.controller
          ..formatSelection(Attribute.blockQuote)
          ..formatSelection(Attribute.clone(Attribute.background, '#DCFCE7'));
        break;
      case 'note':
        widget.controller
          ..formatSelection(Attribute.italic)
          ..formatSelection(Attribute.clone(Attribute.background, '#FEF3C7'));
        break;
      case 'quote':
        widget.controller.formatSelection(Attribute.blockQuote);
        break;
      case 'normal':
        break;
    }
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

  Future<void> _showMore() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => SingleChildScrollView(
        child: Wrap(
          children: [
            _action(context, 'strike', Icons.format_strikethrough, 'Barré'),
            _action(context, 'size', Icons.format_size, 'Taille'),
            _action(context, 'color', Icons.format_color_text, 'Couleur texte'),
            _action(context, 'highlight', Icons.highlight, 'Surlignage'),
            _action(context, 'quote', Icons.format_quote, 'Citation'),
            _action(context, 'bullet', Icons.format_list_bulleted, 'Puces'),
            _action(
                context, 'number', Icons.format_list_numbered, 'Numérotation'),
            _action(
                context, 'indent+', Icons.format_indent_increase, 'Retrait +'),
            _action(
                context, 'indent-', Icons.format_indent_decrease, 'Retrait -'),
            _action(context, 'align', Icons.format_align_left, 'Alignement'),
            _action(context, 'divider', Icons.horizontal_rule, 'Séparateur'),
            _action(context, 'undo', Icons.undo, 'Annuler'),
            _action(context, 'redo', Icons.redo, 'Rétablir'),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'strike':
        _toggle(Attribute.strikeThrough);
        break;
      case 'size':
        await _showSizes();
        break;
      case 'color':
        await _showPalette(background: false);
        break;
      case 'highlight':
        await _showPalette(background: true);
        break;
      case 'quote':
        _toggle(Attribute.blockQuote);
        break;
      case 'bullet':
        _toggle(Attribute.ul);
        break;
      case 'number':
        _toggle(Attribute.ol);
        break;
      case 'indent+':
        widget.controller.indentSelection(true);
        break;
      case 'indent-':
        widget.controller.indentSelection(false);
        break;
      case 'align':
        await _showAlignments();
        break;
      case 'divider':
        widget.onDivider();
        break;
      case 'undo':
        if (widget.controller.hasUndo) {
          widget.controller.undo();
        } else {
          widget.onUndoBlocks();
        }
        break;
      case 'redo':
        if (widget.controller.hasRedo) {
          widget.controller.redo();
        } else {
          widget.onRedoBlocks();
        }
        break;
    }
  }

  Widget _action(
    BuildContext context,
    String value,
    IconData icon,
    String label,
  ) =>
      SizedBox(
        width: MediaQuery.sizeOf(context).width / 3,
        child: ListTile(
          leading: Icon(icon),
          title: Text(label, style: const TextStyle(fontSize: 12)),
          onTap: () => Navigator.pop(context, value),
        ),
      );

  Future<void> _showSizes() async {
    final size = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                title: const Text('Petite'),
                onTap: () => Navigator.pop(context, 'small')),
            ListTile(
                title: const Text('Normale'),
                onTap: () => Navigator.pop(context, 'normal')),
            ListTile(
                title: const Text('Grande'),
                onTap: () => Navigator.pop(context, 'large')),
            ListTile(
                title: const Text('Très grande'),
                onTap: () => Navigator.pop(context, 'huge')),
          ],
        ),
      ),
    );
    if (!mounted || size == null) return;
    widget.controller.formatSelection(
      Attribute.clone(Attribute.size, size == 'normal' ? null : size),
    );
  }

  Future<void> _showPalette({required bool background}) async {
    const colors = {
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
    final value = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (final color in colors.entries)
                InkWell(
                  key:
                      Key('${background ? 'highlight' : 'color'}-${color.key}'),
                  onTap: () => Navigator.pop(context, color.key),
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: color.value,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black26),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (value == null) return;
    widget.controller.formatSelection(
      Attribute.clone(
          background ? Attribute.background : Attribute.color, value),
    );
  }

  Future<void> _showAlignments() async {
    final value = await showModalBottomSheet<Attribute<String?>>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: const Icon(Icons.format_align_left),
                title: const Text('Gauche'),
                onTap: () => Navigator.pop(context, Attribute.leftAlignment)),
            ListTile(
                leading: const Icon(Icons.format_align_center),
                title: const Text('Centre'),
                onTap: () => Navigator.pop(context, Attribute.centerAlignment)),
            ListTile(
                leading: const Icon(Icons.format_align_right),
                title: const Text('Droite'),
                onTap: () => Navigator.pop(context, Attribute.rightAlignment)),
            ListTile(
                leading: const Icon(Icons.format_align_justify),
                title: const Text('Justifié'),
                onTap: () =>
                    Navigator.pop(context, Attribute.justifyAlignment)),
          ],
        ),
      ),
    );
    if (value != null) widget.controller.formatSelection(value);
  }
}
