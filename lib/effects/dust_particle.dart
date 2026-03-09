import 'dart:ui';

/// A single dust particle — tiny, coloured from the source snapshot.
///
/// Each particle is a small circle drawn at its own position.
/// It has a staggered [delay] so particles don't all move at once,
/// producing a more organic wave‑like disintegration.
class DustParticle {
  /// Colour sampled from the snapshot at this particle's origin.
  final Color color;

  /// Starting position (centre of the sampled pixel region).
  final Offset origin;

  /// Random velocity (upward bias + horizontal drift).
  final Offset velocity;

  /// Base radius of the particle circle (1.5 – 4.0 px).
  final double radius;

  /// Normalised delay before this particle starts moving (0.0 – 0.35).
  /// Allows a staggered, wave‑like dissolution.
  final double delay;

  DustParticle({
    required this.color,
    required this.origin,
    required this.velocity,
    required this.radius,
    this.delay = 0.0,
  });

  /// Compute current position given the overall animation [progress] (0→1).
  Offset positionAt(double progress) {
    final t = _effectiveProgress(progress);
    return origin + velocity * t;
  }

  /// Opacity fades from 1 → 0 over this particle's active window.
  double opacityAt(double progress) {
    final t = _effectiveProgress(progress);
    // Ease‑out cubic for a soft fade.
    return (1.0 - t * t).clamp(0.0, 1.0);
  }

  /// Scale shrinks slightly over time for a vanishing feel.
  double scaleAt(double progress) {
    final t = _effectiveProgress(progress);
    return (1.0 - 0.5 * t).clamp(0.3, 1.0);
  }

  /// Map the global progress into this particle's local progress,
  /// accounting for its [delay].
  double _effectiveProgress(double globalProgress) {
    if (globalProgress <= delay) return 0.0;
    return ((globalProgress - delay) / (1.0 - delay)).clamp(0.0, 1.0);
  }
}
