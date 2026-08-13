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
                      icon: Icons.favorite_border_rounded,
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
              SizedBox(
                width: double.infinity,
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
