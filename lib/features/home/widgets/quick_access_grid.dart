import 'package:flutter/material.dart';
import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/core/theme/app_spacing.dart';
import 'package:echo_bible/features/home/models/quick_access_item_model.dart';

class QuickAccessGrid extends StatelessWidget {
  const QuickAccessGrid({super.key});

  static final List<QuickAccessItemModel> items = [
    QuickAccessItemModel(
      icon: Icons.menu_book_rounded,
      label: 'Lire la Bible',
      bgColor: Colors.blue.shade50,
      iconColor: Colors.blue,
    ),
    QuickAccessItemModel(
      icon: Icons.search_rounded,
      label: 'Recherche',
      bgColor: Colors.orange.shade50,
      iconColor: Colors.orange,
    ),
    QuickAccessItemModel(
      icon: Icons.calendar_month_rounded,
      label: 'Plans',
      bgColor: Colors.green.shade50,
      iconColor: Colors.green,
    ),
    QuickAccessItemModel(
      icon: Icons.edit_note_rounded,
      label: 'Notes',
      bgColor: Colors.purple.shade50,
      iconColor: Colors.purple,
    ),
    QuickAccessItemModel(
      icon: Icons.brush_rounded,
      label: 'Surlignages',
      bgColor: Colors.pink.shade50,
      iconColor: Colors.pink,
    ),
    QuickAccessItemModel(
      icon: Icons.headphones_rounded,
      label: 'Audio Bible',
      bgColor: Colors.teal.shade50,
      iconColor: Colors.teal,
    ),
    QuickAccessItemModel(
      icon: Icons.menu_book_outlined,
      label: 'Dictionnaire',
      bgColor: Colors.amber.shade50,
      iconColor: Colors.amber.shade800,
    ),
    QuickAccessItemModel(
      icon: Icons.rule_folder_outlined,
      label: 'Concordance',
      bgColor: Colors.indigo.shade50,
      iconColor: Colors.indigo,
    ),
    QuickAccessItemModel(
      icon: Icons.compare_arrows_rounded,
      label: 'Comparaison',
      bgColor: Colors.cyan.shade50,
      iconColor: Colors.cyan.shade700,
    ),
    QuickAccessItemModel(
      icon: Icons.smart_toy_outlined,
      label: 'IA Assistant',
      bgColor: Colors.deepPurple.shade50,
      iconColor: Colors.deepPurple,
    ),
    QuickAccessItemModel(
      icon: Icons.favorite_outline_rounded,
      label: 'Favoris',
      bgColor: Colors.red.shade50,
      iconColor: Colors.red,
    ),
    QuickAccessItemModel(
      icon: Icons.settings_outlined,
      label: 'Paramètres',
      bgColor: Colors.grey.shade100,
      iconColor: Colors.grey.shade700,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 0.95, // Cartes plus hautes et aérées
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(22), // Arrondi de carte à 22px
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 20,
                offset: const Offset(0, 8), // Ombre diffuse professionnelle
              ),
            ],
          ),
          child: InkWell(
            onTap: item.onTap ?? () {},
            borderRadius: BorderRadius.circular(22),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md - 4),
                  decoration: BoxDecoration(
                    color: item.bgColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(item.icon, color: item.iconColor, size: 24),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  item.label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryLight,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
