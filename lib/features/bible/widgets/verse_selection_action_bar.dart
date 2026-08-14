import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

class VerseSelectionActionBar extends StatelessWidget {
  final int selectionCount;
  final VoidCallback onHighlight;
  final VoidCallback onUnderline;
  final VoidCallback? onNote;
  final VoidCallback onFavorite;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onStudy;
  final VoidCallback? onAddToStudy;
  final bool isFavorite;

  const VerseSelectionActionBar({
    super.key,
    required this.selectionCount,
    required this.onHighlight,
    required this.onUnderline,
    required this.onNote,
    required this.onFavorite,
    required this.onCopy,
    required this.onShare,
    required this.onStudy,
    this.onAddToStudy,
    this.isFavorite = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Material(
        color: colors.surface,
        elevation: 12,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _SelectionAction(
                      icon: Icons.brush_outlined,
                      label: 'Surligner',
                      onTap: onHighlight,
                    ),
                  ),
                  Expanded(
                    child: _SelectionAction(
                      icon: Icons.format_underline_rounded,
                      label: 'Souligner',
                      onTap: onUnderline,
                    ),
                  ),
                  Expanded(
                    child: _SelectionAction(
                      icon: Icons.edit_note_rounded,
                      label: 'Note',
                      onTap: onNote,
                    ),
                  ),
                  Expanded(
                    child: _SelectionAction(
                      key: const Key('selected-verses-favorite-action'),
                      icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                      label: 'Favoris',
                      onTap: onFavorite,
                    ),
                  ),
                  Expanded(
                    child: _SelectionAction(
                      icon: Icons.copy_outlined,
                      label: 'Copier',
                      onTap: onCopy,
                    ),
                  ),
                  Expanded(
                    child: _SelectionAction(
                      icon: Icons.share_outlined,
                      label: 'Partager',
                      onTap: onShare,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('study-selected-verses'),
                      onPressed: onStudy,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                      ),
                      icon: const Icon(Icons.school_outlined),
                      label: const Text('ÉTUDIER'),
                    ),
                  ),
                  if (onAddToStudy != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        key: const Key('add-selected-verses-to-study'),
                        onPressed: onAddToStudy,
                        icon: const Icon(Icons.playlist_add),
                        label: const Text('AJOUTER'),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectionAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _SelectionAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: onTap == null ? .42 : 1,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 2),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10.5),
                ),
              ],
            ),
          ),
        ),
      );
}
