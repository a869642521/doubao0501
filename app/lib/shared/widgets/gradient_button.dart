import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:starpath/core/theme.dart';

/// Primary button — ROUND_FULL pill · gradient fill · ambient glow on press
/// DESIGN.md §5 Buttons: "High-pill shape (ROUND_FULL). Fill with gradient of
/// primary to primary_dim. On hover/active, increase Ambient Glow."
class GradientButton extends StatefulWidget {
  final String text;
  final VoidCallback? onPressed;
  final LinearGradient? gradient;
  final double height;
  final double borderRadius;
  final bool isLoading;
  final IconData? leadingIcon;

  const GradientButton({
    super.key,
    required this.text,
    this.onPressed,
    this.gradient,
    this.height = 52,
    this.borderRadius = 100,
    this.isLoading = false,
    this.leadingIcon,
  });

  @override
  State<GradientButton> createState() => _GradientButtonState();
}

class _GradientButtonState extends State<GradientButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnim;
  late Animation<double> _glowAnim;
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 160),
      vsync: this,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.96).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    _glowAnim = Tween<double>(begin: 0.28, end: 0.55).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.onPressed == null) return;
    _controller.forward();
    HapticFeedback.lightImpact();
  }

  void _handleTapUp(TapUpDetails _) {
    _controller.reverse();
    widget.onPressed?.call();
  }

  void _handleTapCancel() {
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.onPressed != null && !widget.isLoading;
    final gradient = widget.gradient ?? StarpathColors.primaryGradient;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Transform.scale(
          scale: _scaleAnim.value,
          child: GestureDetector(
            onTapDown: isEnabled ? _handleTapDown : null,
            onTapUp: isEnabled ? _handleTapUp : null,
            onTapCancel: _handleTapCancel,
            child: Container(
              height: widget.height,
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: isEnabled ? gradient : null,
                color: isEnabled
                    ? null
                    : StarpathColors.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(widget.borderRadius),
                boxShadow: isEnabled
                    ? [
                        BoxShadow(
                          color: StarpathColors.primary
                              .withValues(alpha: _glowAnim.value),
                          blurRadius: 40,
                          spreadRadius: -5,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              alignment: Alignment.center,
              child: widget.isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: StarpathColors.onPrimary,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (widget.leadingIcon != null) ...[
                          Icon(
                            widget.leadingIcon,
                            color: isEnabled
                                ? StarpathColors.onPrimary
                                : StarpathColors.onSurfaceVariant,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(
                          widget.text,
                          style: TextStyle(
                            color: isEnabled
                                ? StarpathColors.onPrimary
                                : StarpathColors.onSurfaceVariant,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}

/// Secondary / Ghost button — glassmorphic background + ghost border
class GhostButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final double height;

  const GhostButton({
    super.key,
    required this.text,
    this.onPressed,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: StarpathColors.outlineVariant, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(100)),
          backgroundColor:
              StarpathColors.surfaceContainer.withValues(alpha: 0.4),
          foregroundColor: StarpathColors.primary,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
