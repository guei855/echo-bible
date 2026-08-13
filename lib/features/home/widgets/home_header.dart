import 'package:flutter/material.dart';
import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/core/theme/app_text_styles.dart';
import 'package:echo_bible/core/theme/app_spacing.dart';

class HomeHeader extends StatefulWidget {
  const HomeHeader({super.key});

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  bool _isReadMarked = false;

  void _toggleReadMark() {
    setState(() {
      _isReadMarked = !_isReadMarked;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isReadMarked ? "Marqué comme médité 📖" : "Marqué comme non lu",
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _copyVerse() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("Verset copié dans le presse-papier 📋"),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _shareVerse() {
    // Action de partage
  }

  void _readVerse() {
    // Action pour lire ou ouvrir le chapitre complet
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.xxl + 10,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bonjour,',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    const Text(
                      'Que la paix du Seigneur\nsoit avec vous !',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                padding: const EdgeInsets.all(AppSpacing.sm + 2),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.notifications_outlined,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),

          // Carte "Verset du jour" interactive
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.auto_stories,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          'Verset du jour',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      'Psaumes 23:1',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),

                const Text(
                  '« L\'Éternel est mon berger : je ne manquerai de rien. »',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimaryLight,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),

                const Divider(height: 1, color: Colors.black12),
                const SizedBox(height: AppSpacing.xs),

                // Barre d'actions interactive
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        // Remplacement du cœur par l'icône de lecture/étude (silhouette / livre)
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                          icon: Icon(
                            _isReadMarked
                                ? Icons.local_library
                                : Icons.local_library_outlined,
                            color: _isReadMarked
                                ? AppColors.primary
                                : AppColors.textSecondaryLight,
                            size: 20,
                          ),
                          onPressed: _toggleReadMark,
                          tooltip: "Marquer comme lu",
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                          icon: const Icon(
                            Icons.copy_rounded,
                            color: AppColors.textSecondaryLight,
                            size: 20,
                          ),
                          onPressed: _copyVerse,
                          tooltip: "Copier",
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                          icon: const Icon(
                            Icons.share_outlined,
                            color: AppColors.textSecondaryLight,
                            size: 20,
                          ),
                          onPressed: _shareVerse,
                          tooltip: "Partager",
                        ),
                      ],
                    ),
                    TextButton.icon(
                      onPressed: _readVerse,
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text("Lire"),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        textStyle: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
