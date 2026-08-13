import 'package:flutter/material.dart';
import 'package:echo_bible/core/theme/app_colors.dart';
import 'package:echo_bible/core/theme/app_radius.dart';

class PageIndicator extends StatelessWidget {
  final int count;
  final int currentIndex;

  const PageIndicator({
    super.key,
    required this.count,
    required this.currentIndex,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (index) {
        bool isActive = index == currentIndex;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 4.0),
          height: 8.0,
          // Le point actif devient une pilule allongée (32px), les autres restent à 8px
          width: isActive ? 32.0 : 8.0,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary
                : AppColors.primary.withValues(alpha: 0.2),
            borderRadius: AppRadius.fullRadius,
          ),
        );
      }),
    );
  }
}
