import 'package:flutter/material.dart';

import 'dust_particle.dart';

/// Draws hundreds of tiny coloured circles — the dust particles.
///
/// Unlike V1 which used `drawImageRect` (producing boxy artefacts),
/// this paints each particle as a `drawCircle` call with the colour
/// sampled from the original snapshot.
class DustPainter extends CustomPainter {
  final List<DustParticle> particles;
  final double progress;

  DustPainter({required this.particles, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in particles) {
      final opacity = p.opacityAt(progress);
      if (opacity <= 0.01) continue;

      final pos = p.positionAt(progress);
      final scale = p.scaleAt(progress);
      final r = p.radius * scale;

      paint.color = p.color.withOpacity(
        opacity *
            (p.color.opacity / 255.0 == 0 ? 1.0 : p.color.opacity / 255.0),
      );
      // Use the pre‑computed alpha from the sampled colour, scaled by
      // the animation opacity.
      paint.color = p.color.withValues(alpha: opacity);

      canvas.drawCircle(pos, r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant DustPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
