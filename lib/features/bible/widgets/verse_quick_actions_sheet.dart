import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

enum VerseQuickAction {
  copy,
  share,
  highlight,
  note,
  favorite,
  compare,
  crossReferences,
  study,
}

class VerseQuickActionsSheet extends StatelessWidget {
  final String reference;
  final String verseText;

  const VerseQuickActionsSheet({
    super.key,
    required this.reference,
    required this.verseText,
  });

  static Future<VerseQuickAction?> show(
    BuildContext context, {
    required String reference,
    required String verseText,
  }) {
    return showModalBottomSheet<VerseQuickAction>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => VerseQuickActionsSheet(
        reference: reference,
        verseText: verseText,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              reference,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 7),
            Text(
              '« $verseText »',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: colors.onSurfaceVariant, height: 1.4),
            ),
            const SizedBox(height: 14),
            Divider(height: 1, color: colors.outlineVariant),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.35,
              children: const [
                _ActionTile(
                  action: VerseQuickAction.copy,
                  icon: Icons.copy_outlined,
                  label: 'Copier',
                ),
                _ActionTile(
                  action: VerseQuickAction.share,
                  icon: Icons.share_outlined,
                  label: 'Partager',
                ),
                _ActionTile(
                  action: VerseQuickAction.highlight,
                  icon: Icons.brush_outlined,
                  label: 'Surligner',
                ),
                _ActionTile(
                  action: VerseQuickAction.note,
                  icon: Icons.edit_note_rounded,
                  label: 'Note',
                ),
                _ActionTile(
                  action: VerseQuickAction.favorite,
                  icon: Icons.favorite_border_rounded,
                  label: 'Favoris',
                ),
                _ActionTile(
                  action: VerseQuickAction.compare,
                  icon: Icons.compare_arrows_rounded,
                  label: 'Comparer',
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  VerseQuickAction.crossReferences,
                ),
                icon: const Icon(Icons.account_tree_outlined),
                label: const Text('Références croisées'),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(
                  context,
                  VerseQuickAction.study,
                ),
                icon: const Icon(Icons.school_outlined),
                label: const Text('Étudier ce verset'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final VerseQuickAction action;
  final IconData icon;
  final String label;

  const _ActionTile({
    required this.action,
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surfaceContainerLow,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => Navigator.pop(context, action),
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.primary, size: 23),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: colors.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
