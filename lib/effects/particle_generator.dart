import 'dart:math';
import 'dart:typed_data';
import 'dart:ui';

import 'dust_particle.dart';

/// Generates hundreds of tiny [DustParticle] instances by sampling pixel
/// colours from the snapshot's raw RGBA byte data.
class ParticleGenerator {
  ParticleGenerator._();

  static final _rng = Random();

  /// Creates particles by sampling the snapshot pixel buffer.
  ///
  /// [pixelData] must be in [ImageByteFormat.rawRgba] format.
  /// [imageWidth] / [imageHeight] are the snapshot dimensions in pixels.
  /// [cols] × [rows] controls how many sample points (≈ particle count).
  static List<DustParticle> generate({
    required ByteData pixelData,
    required int imageWidth,
    required int imageHeight,
    int cols = 20,
    int rows = 20,
  }) {
    final cellW = imageWidth / cols;
    final cellH = imageHeight / rows;
    final particles = <DustParticle>[];

    for (int r = 0; r < rows; r++) {
      for (int c = 0; c < cols; c++) {
        // Jittered sample position within the cell.
        final px = (c * cellW + _rng.nextDouble() * cellW)
            .clamp(0, imageWidth - 1)
            .toInt();
        final py = (r * cellH + _rng.nextDouble() * cellH)
            .clamp(0, imageHeight - 1)
            .toInt();

        // Read RGBA from the byte buffer.
        final offset = (py * imageWidth + px) * 4;
        final red = pixelData.getUint8(offset);
        final green = pixelData.getUint8(offset + 1);
        final blue = pixelData.getUint8(offset + 2);
        final alpha = pixelData.getUint8(offset + 3);

        // Skip fully transparent pixels.
        if (alpha == 0) continue;

        final color = Color.fromARGB(alpha, red, green, blue);

        // Origin is the logical position of this sample.
        final origin = Offset(c * cellW + cellW / 2, r * cellH + cellH / 2);

        // Random velocity — strong upward bias, slight horizontal drift.
        final vx = _randomRange(-50, 50);
        final vy = _randomRange(-100, -25);

        // Tiny radius for a dust look.
        final radius = _randomRange(1.2, 3.5);

        // Staggered start — particles on the right begin slightly later
        // to create a left‑to‑right dissolution wave.
        final normX = c / cols;
        final delay = normX * 0.30 + _rng.nextDouble() * 0.05;

        particles.add(
          DustParticle(
            color: color,
            origin: origin,
            velocity: Offset(vx, vy),
            radius: radius,
            delay: delay.clamp(0.0, 0.35),
          ),
        );
      }
    }

    return particles;
  }

  static double _randomRange(double min, double max) =>
      min + _rng.nextDouble() * (max - min);
}
