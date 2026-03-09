import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'dust_painter.dart';
import 'dust_particle.dart';
import 'particle_generator.dart';

/// A reusable widget that wraps any [child] and, when [trigger] becomes
/// `true`, captures a snapshot and plays a dust‑disintegration animation.
///
/// ```dart
/// DisintegrateEffect(
///   trigger: isDeleting,
///   onComplete: () => removeMessage(),
///   child: ChatBubble(...),
/// )
/// ```
class DisintegrateEffect extends StatefulWidget {
  /// When this switches from `false` → `true` the animation starts.
  final bool trigger;

  /// Duration of the disintegration animation.
  final Duration duration;

  /// Called after the animation finishes (use to remove the widget).
  final VoidCallback? onComplete;

  /// The child widget to disintegrate.
  final Widget child;

  const DisintegrateEffect({
    super.key,
    required this.trigger,
    this.duration = const Duration(milliseconds: 900),
    this.onComplete,
    required this.child,
  });

  @override
  State<DisintegrateEffect> createState() => _DisintegrateEffectState();
}

class _DisintegrateEffectState extends State<DisintegrateEffect>
    with SingleTickerProviderStateMixin {
  final _boundaryKey = GlobalKey();

  late final AnimationController _controller;

  List<DustParticle>? _particles;
  bool _animating = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_onAnimationStatus);
  }

  @override
  void didUpdateWidget(covariant DisintegrateEffect oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Trigger fires when the flag changes from false → true.
    if (widget.trigger && !oldWidget.trigger) {
      _startDisintegration();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // ── Private ──────────────────────────────────────────────────────────

  Future<void> _startDisintegration() async {
    // 1. Capture snapshot.
    final boundary =
        _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 1.0);

    // 2. Extract raw RGBA pixel data.
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (byteData == null) {
      image.dispose();
      return;
    }

    // 3. Generate particles from pixel colours.
    final particles = ParticleGenerator.generate(
      pixelData: byteData,
      imageWidth: image.width,
      imageHeight: image.height,
    );

    image.dispose();

    if (!mounted) return;

    setState(() {
      _particles = particles;
      _animating = true;
    });

    // 4. Start the animation.
    _controller.forward(from: 0);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onComplete?.call();
    }
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The original child — hidden once animation starts.
        Opacity(
          opacity: _animating ? 0 : 1,
          child: RepaintBoundary(key: _boundaryKey, child: widget.child),
        ),

        // Particle overlay — visible only during animation.
        if (_animating && _particles != null)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (_, __) {
                return CustomPaint(
                  painter: DustPainter(
                    particles: _particles!,
                    progress: _controller.value,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
