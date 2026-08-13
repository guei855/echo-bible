import 'package:echo_bible/features/bible/models/highlight_color_option.dart';
import 'package:echo_bible/features/bible/services/highlight_palette_service.dart';
import 'package:flutter/material.dart';

class HighlightPaletteSheet extends StatefulWidget {
  final int selectionCount;
  final String actionLabel;
  final bool canRemoveHighlight;

  const HighlightPaletteSheet({
    super.key,
    required this.selectionCount,
    this.actionLabel = 'surligné',
    required this.canRemoveHighlight,
  });

  static Future<HighlightPaletteResult?> show(
    BuildContext context, {
    required int selectionCount,
    String actionLabel = 'surligné',
    required bool canRemoveHighlight,
  }) {
    return showModalBottomSheet<HighlightPaletteResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => HighlightPaletteSheet(
        selectionCount: selectionCount,
        actionLabel: actionLabel,
        canRemoveHighlight: canRemoveHighlight,
      ),
    );
  }

  @override
  State<HighlightPaletteSheet> createState() => _HighlightPaletteSheetState();
}

class _HighlightPaletteSheetState extends State<HighlightPaletteSheet> {
  List<HighlightColorOption> _customColors = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final colors = await HighlightPaletteService.loadCustomColors();
    if (!mounted) return;
    setState(() => _customColors = colors);
  }

  Future<void> _editColor([HighlightColorOption? existing]) async {
    var selectedValue = existing?.colorValue ??
        HighlightPaletteService.availableCustomColors.first;
    final result = await showDialog<HighlightColorOption>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Ajouter une couleur' : 'Modifier'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final value
                        in HighlightPaletteService.availableCustomColors)
                      InkWell(
                        onTap: () => setDialogState(
                          () => selectedValue = value,
                        ),
                        customBorder: const CircleBorder(),
                        child: CircleAvatar(
                          backgroundColor: Color(value),
                          child: selectedValue == value
                              ? const Icon(Icons.check, color: Colors.white)
                              : null,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  HighlightPaletteService.create(selectedValue),
                );
              },
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
    if (result == null || !mounted) return;
    final colors = [..._customColors];
    if (existing != null) {
      colors.removeWhere((item) => item.key == existing.key);
    }
    colors.add(result);
    await HighlightPaletteService.saveCustomColors(colors);
    if (!mounted) return;
    setState(() => _customColors = colors);
  }

  Future<void> _deleteColor(HighlightColorOption color) async {
    final colors = [..._customColors]
      ..removeWhere((item) => item.key == color.key);
    await HighlightPaletteService.saveCustomColors(colors);
    if (!mounted) return;
    setState(() => _customColors = colors);
  }

  void _select(HighlightColorOption color) {
    Navigator.pop(context, HighlightPaletteResult.color(color.key));
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Choisir une couleur',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              widget.selectionCount == 1
                  ? '1 sélection sera ${widget.actionLabel}e.'
                  : '${widget.selectionCount} sélections seront ${widget.actionLabel}es.',
              style: TextStyle(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 18,
              runSpacing: 14,
              children: [
                for (final color in HighlightPaletteService.defaults)
                  _ColorChoice(color: color, onTap: () => _select(color)),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Mes couleurs',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _editColor,
                  icon: const Icon(Icons.add),
                  label: const Text('Ajouter une couleur'),
                ),
              ],
            ),
            if (_customColors.isNotEmpty)
              Wrap(
                spacing: 16,
                runSpacing: 12,
                children: [
                  for (final color in _customColors)
                    GestureDetector(
                      onTap: () => _select(color),
                      onLongPress: () => _deleteColor(color),
                      child: CircleAvatar(
                          backgroundColor: color.color, radius: 23),
                    ),
                ],
              ),
            if (widget.canRemoveHighlight) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(
                        context, const HighlightPaletteResult.remove());
                  },
                  icon: const Icon(Icons.format_color_reset_rounded),
                  label: const Text('Retirer le surlignage'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class HighlightPaletteResult {
  final String? colorKey;
  final bool shouldRemove;

  const HighlightPaletteResult.color(this.colorKey) : shouldRemove = false;
  const HighlightPaletteResult.remove()
      : colorKey = null,
        shouldRemove = true;
}

class _ColorChoice extends StatelessWidget {
  final HighlightColorOption color;
  final VoidCallback onTap;

  const _ColorChoice({required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(backgroundColor: color.color, radius: 23),
            const SizedBox(height: 5),
            Text(color.name, style: const TextStyle(fontSize: 12)),
          ],
        ),
      );
}
