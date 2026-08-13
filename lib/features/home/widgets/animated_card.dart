import 'package:flutter/material.dart';

class AnimatedCard extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final String? heroTag; // Optionnel pour la Hero Animation

  const AnimatedCard({
    super.key,
    required this.child,
    required this.onTap,
    this.heroTag,
  });

  @override
  State<AnimatedCard> createState() => _AnimatedCardState();
}

class _AnimatedCardState extends State<AnimatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) {
    _controller.forward();
  }

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  void _onTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    Widget cardContent = GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            splashColor: Colors.blue.withValues(alpha: 0.1),
            highlightColor: Colors.blue.withValues(alpha: 0.05),
            child: widget.child,
          ),
        ),
      ),
    );

    // Si un tag Hero est fourni, on enveloppe dans un Hero widget
    if (widget.heroTag != null) {
      return Hero(
        tag: widget.heroTag!,
        child: Material(color: Colors.transparent, child: cardContent),
      );
    }

    return cardContent;
  }
}
