import 'package:flutter/material.dart';

class BibleAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String bookChapter;
  final String version;
  final VoidCallback onTextSizePressed;
  final VoidCallback onVersionChanged;
  final VoidCallback onDarkModePressed;
  final bool isDarkMode;

  const BibleAppBar({
    super.key,
    required this.bookChapter,
    required this.version,
    required this.onTextSizePressed,
    required this.onVersionChanged,
    required this.onDarkModePressed,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: isDarkMode ? Colors.grey[850] : Colors.white,
      elevation: 0,
      iconTheme:
          IconThemeData(color: isDarkMode ? Colors.white : Colors.black87),
      title: Row(
        children: [
          Text(
            bookChapter,
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black87,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onVersionChanged,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                // Bleu un peu plus doux en mode nuit/jour (#4A90E2)
                color: const Color(0xFF4A90E2).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                version,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF4A90E2),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        // Bouton Aa (style Kindle)
        IconButton(
          onPressed: onTextSizePressed,
          tooltip: "Options d'affichage et polices",
          icon: const Text(
            "Aᴀ",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.blueAccent,
            ),
          ),
        ),
        // Bouton Soleil / Lune avec rotation fluide implicite
        IconButton(
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return RotationTransition(
                turns: Tween<double>(begin: 0.5, end: 1.0).animate(animation),
                child: FadeTransition(opacity: animation, child: child),
              );
            },
            child: Icon(
              isDarkMode ? Icons.wb_sunny_rounded : Icons.nightlight_round,
              key: ValueKey<bool>(isDarkMode),
              color: isDarkMode ? Colors.amber : Colors.grey[700],
            ),
          ),
          onPressed: onDarkModePressed,
          tooltip: "Changer de thème",
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
