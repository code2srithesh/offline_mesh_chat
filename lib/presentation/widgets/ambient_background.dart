import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class AmbientBackground extends StatefulWidget {
  final Widget child;

  const AmbientBackground({
    super.key,
    required this.child,
  });

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late List<_AmbientParticle> _particles;
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    // Initialize background floating particles
    _particles = List.generate(30, (index) {
      return _AmbientParticle(
        x: _random.nextDouble(),
        y: _random.nextDouble(),
        speed: 0.01 + _random.nextDouble() * 0.02,
        radius: 1.0 + _random.nextDouble() * 2.0,
        opacity: 0.1 + _random.nextDouble() * 0.4,
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = ThemeManager.currentTheme;

    return Stack(
      children: [
        // Live animated gradient/particle background
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _AmbientBackgroundPainter(
                  progress: _controller.value,
                  particles: _particles,
                  palette: palette,
                ),
              );
            },
          ),
        ),
        // Glass overlay dark filter
        Positioned.fill(
          child: Container(
            color: palette.background.withOpacity(0.4),
          ),
        ),
        // Child content above the glass background
        Positioned.fill(
          child: widget.child,
        ),
      ],
    );
  }
}

class _AmbientParticle {
  double x;
  double y;
  final double speed;
  final double radius;
  final double opacity;

  _AmbientParticle({
    required this.x,
    required this.y,
    required this.speed,
    required this.radius,
    required this.opacity,
  });
}

class _AmbientBackgroundPainter extends CustomPainter {
  final double progress;
  final List<_AmbientParticle> particles;
  final ThemePalette palette;

  _AmbientBackgroundPainter({
    required this.progress,
    required this.particles,
    required this.palette,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();

    // 1. Draw base deep background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), Paint()..color = palette.background);

    // 2. Draw drifting ambient blur blobs
    final double baseRadius = min(size.width, size.height) * 0.6;
    
    // Blob 1: Top-Right drifting primary/purple glow
    final double blob1Angle = progress * 2 * pi;
    final double blob1X = size.width * 0.75 + cos(blob1Angle) * 60;
    final double blob1Y = size.height * 0.2 + sin(blob1Angle) * 80;
    final blob1Center = Offset(blob1X, blob1Y);
    final blob1Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          palette.accent.withOpacity(0.25),
          palette.accent.withOpacity(0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: blob1Center, radius: baseRadius));
    canvas.drawCircle(blob1Center, baseRadius, blob1Paint);

    // Blob 2: Bottom-Left drifting secondary/cyan/accentLight glow
    final double blob2Angle = (progress + 0.5) * 2 * pi;
    final double blob2X = size.width * 0.25 + cos(blob2Angle) * 80;
    final double blob2Y = size.height * 0.8 + sin(blob2Angle) * 60;
    final blob2Center = Offset(blob2X, blob2Y);
    final blob2Paint = Paint()
      ..shader = RadialGradient(
        colors: [
          palette.accentLight.withOpacity(0.2),
          palette.accentLight.withOpacity(0.05),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: blob2Center, radius: baseRadius * 1.2));
    canvas.drawCircle(blob2Center, baseRadius * 1.2, blob2Paint);

    // 3. Draw upward floating particles
    for (var particle in particles) {
      double drawY = (particle.y - progress * particle.speed) % 1.0;
      double drawX = particle.x;

      final position = Offset(drawX * size.width, drawY * size.height);
      paint.color = palette.accentLight.withOpacity(particle.opacity);
      canvas.drawCircle(position, particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
