import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A reusable widget that wraps any [child] and, when [trigger] becomes
/// `true`, captures a snapshot and plays a dust‑disintegration animation
/// driven by a GPU fragment shader.
class DisintegrateEffect extends StatefulWidget {
  final bool trigger;
  final Duration duration;
  final VoidCallback? onComplete;
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

  static ui.FragmentProgram? _program;

  ui.Image? _snapshotImage;
  bool _animating = false;
  late final Float32List _randoms;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration)
      ..addStatusListener(_onAnimationStatus);

    // Generate 16 random (x,y) values from -1.0 to 1.0
    _randoms = Float32List(32);
    final rng = Random();
    for (int i = 0; i < 32; i++) {
      _randoms[i] = (rng.nextDouble() - 0.5) * 2.0;
    }

    _loadShader();
  }

  Future<void> _loadShader() async {
    if (_program != null) return;
    try {
      _program = await ui.FragmentProgram.fromAsset('assets/shaders/dust.frag');
    } catch (e) {
      debugPrint("Error loading shader: \$e");
    }
  }

  @override
  void didUpdateWidget(covariant DisintegrateEffect oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.trigger && !oldWidget.trigger) {
      _startDisintegration();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _snapshotImage?.dispose();
    super.dispose();
  }

  Future<void> _startDisintegration() async {
    final boundary =
        _boundaryKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 1.0);

    if (!mounted) {
      image.dispose();
      return;
    }

    setState(() {
      _snapshotImage = image;
      _animating = true;
    });

    _controller.forward(from: 0);
  }

  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      widget.onComplete?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Opacity(
          opacity: _animating ? 0 : 1,
          child: RepaintBoundary(key: _boundaryKey, child: widget.child),
        ),

        if (_animating && _snapshotImage != null && _program != null)
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return CustomPaint(
                  painter: _ShaderDustPainter(
                    program: _program!,
                    image: _snapshotImage!,
                    progress: _controller.value,
                    randoms: _randoms,
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

class _ShaderDustPainter extends CustomPainter {
  final ui.FragmentProgram program;
  final ui.Image image;
  final double progress;
  final Float32List randoms;

  _ShaderDustPainter({
    required this.program,
    required this.image,
    required this.progress,
    required this.randoms,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final shader = program.fragmentShader();

    // 1. u_resolution
    shader.setFloat(0, size.width);
    shader.setFloat(1, size.height);

    // 2. u_progress
    shader.setFloat(2, progress);

    // 3. u_randoms[16] (16 vec2 = 32 floats starting at index 3)
    for (int i = 0; i < 32; i++) {
      shader.setFloat(3 + i, randoms[i]);
    }

    // 4. u_image
    shader.setImageSampler(0, image);

    final paint = Paint()..shader = shader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  bool shouldRepaint(covariant _ShaderDustPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}
