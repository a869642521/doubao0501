import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:starpath/core/theme.dart';

/// Glassmorphism card — Level 2 surface
/// surface-variant @ 40% opacity + 24px backdrop-blur + ghost border
class FrostedCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final double blurSigma;
  final double opacity;
  final VoidCallback? onTap;
  final Color? color;
  final bool showAmbientGlow;

  const FrostedCard({
    super.key,
    required this.child,
    this.borderRadius = 28,
    this.padding = const EdgeInsets.all(20),
    this.blurSigma = 24,
    this.opacity = 0.40,
    this.onTap,
    this.color,
    this.showAmbientGlow = false,
  });

  @override
  Widget build(BuildContext context) {
    final cardColor =
        (color ?? StarpathColors.surfaceContainer).withValues(alpha: opacity);

    final child_ = ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(borderRadius),
            // Ghost border — outline_variant @ 15% (DESIGN.md §4)
            border: Border.all(
              color: StarpathColors.outlineVariant,
              width: 1,
            ),
            boxShadow: showAmbientGlow
                ? [
                    BoxShadow(
                      color: StarpathColors.primary.withValues(alpha: 0.10),
                      blurRadius: 40,
                      spreadRadius: -5,
                    ),
                  ]
                : null,
          ),
          child: child,
        ),
      ),
    );

    if (onTap == null) return child_;

    return GestureDetector(
      onTap: onTap,
      child: child_,
    );
  }
}

/// Elevated variant — slightly brighter background for interactive items
class ElevatedCard extends StatefulWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const ElevatedCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  @override
  State<ElevatedCard> createState() => _ElevatedCardState();
}

class _ElevatedCardState extends State<ElevatedCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.975)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (_, child) => Transform.scale(scale: _scale.value, child: child),
      child: GestureDetector(
        onTapDown: widget.onTap != null ? (_) => _ctrl.forward() : null,
        onTapUp: widget.onTap != null
            ? (_) {
                _ctrl.reverse();
                widget.onTap!();
              }
            : null,
        onTapCancel: () => _ctrl.reverse(),
        child: Container(
          padding: widget.padding,
          decoration: BoxDecoration(
            color: StarpathColors.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            border: Border.all(
              color: StarpathColors.outlineVariant,
              width: 1,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
