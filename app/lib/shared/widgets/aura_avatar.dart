import 'dart:math' as math;
import 'package:flutter/material.dart';

enum CompanionState { active, thinking, creating, sleeping, excited }

class AuraAvatar extends StatefulWidget {
  final String? imageUrl;
  final String fallbackEmoji;
  final double size;
  final List<Color> gradientColors;
  final CompanionState state;

  const AuraAvatar({
    super.key,
    this.imageUrl,
    this.fallbackEmoji = '🤖',
    this.size = 64,
    required this.gradientColors,
    this.state = CompanionState.active,
  });

  @override
  State<AuraAvatar> createState() => _AuraAvatarState();
}

class _AuraAvatarState extends State<AuraAvatar>
    with TickerProviderStateMixin {
  late AnimationController _breathController;
  late AnimationController _pulseController;
  late Animation<double> _breathAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    _breathController = AnimationController(
      duration: const Duration(milliseconds: 2400),
      vsync: this,
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    )..repeat(reverse: true);

    _breathAnimation = Tween<double>(begin: 0.98, end: 1.02).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _breathController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  double get _auraOpacity {
    switch (widget.state) {
      case CompanionState.active:
        return 0.7;
      case CompanionState.thinking:
        return 0.9;
      case CompanionState.creating:
        return 0.85;
      case CompanionState.sleeping:
        return 0.3;
      case CompanionState.excited:
        return 1.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_breathAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Transform.scale(
          scale: _breathAnimation.value,
          child: SizedBox(
            width: widget.size + 24,
            height: widget.size + 24,
            child: CustomPaint(
              painter: _AuraPainter(
                colors: widget.gradientColors,
                opacity: _auraOpacity * _pulseAnimation.value,
                innerRadius: widget.size / 2,
              ),
              child: Center(
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: widget.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Center(
                    child: widget.imageUrl != null
                        ? ClipOval(
                            child: Image.network(
                              widget.imageUrl!,
                              width: widget.size - 4,
                              height: widget.size - 4,
                              fit: BoxFit.cover,
                            ),
                          )
                        : Text(
                            widget.fallbackEmoji,
                            style: TextStyle(fontSize: widget.size * 0.45),
                          ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _AuraPainter extends CustomPainter {
  final List<Color> colors;
  final double opacity;
  final double innerRadius;

  _AuraPainter({
    required this.colors,
    required this.opacity,
    required this.innerRadius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = size.width / 2;

    // Outer glow
    final outerPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          colors.first.withValues(alpha: opacity * 0.4),
          colors.last.withValues(alpha: 0),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: outerRadius))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

    canvas.drawCircle(center, outerRadius, outerPaint);

    // Inner aura ring
    final innerPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..shader = SweepGradient(
        colors: [colors.first, colors.last, colors.first],
        startAngle: 0,
        endAngle: 2 * math.pi,
      ).createShader(
          Rect.fromCircle(center: center, radius: innerRadius + 4));

    canvas.drawCircle(
      center,
      innerRadius + 4,
      innerPaint..color = innerPaint.color.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(covariant _AuraPainter oldDelegate) {
    return oldDelegate.opacity != opacity || oldDelegate.colors != colors;
  }
}
