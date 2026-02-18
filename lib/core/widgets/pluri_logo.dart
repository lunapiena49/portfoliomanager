import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class PluriLogo extends StatefulWidget {
  const PluriLogo({
    super.key,
    this.width,
    this.height,
    this.ariaLabel = 'PluriFin logo',
    this.lazyLoad = true,
    this.hoverSpeed = 1.5,
    this.startDelay = const Duration(milliseconds: 200),
    this.tintColor,
    this.showOrbital = false,
  });

  final double? width;
  final double? height;
  final String ariaLabel;
  final bool lazyLoad;
  final double hoverSpeed;
  final Duration startDelay;
  final Color? tintColor;
  final bool showOrbital;

  @override
  State<PluriLogo> createState() => _PluriLogoState();
}

class _PluriLogoState extends State<PluriLogo>
    with TickerProviderStateMixin {
  static const String _assetPath = 'assets/images/pluriFin-anim.json';
  static const Color _neonMint = Color(0xFF3DF2A7);
  static const double _aspectRatio = 681 / 260;
  static const double _baseSpeed = 1.0;
  static const double _baseGlowOpacity = 0.25;
  static const double _hoverGlowOpacity = 0.7;
  static const double _baseGlowBlur = 16.0;
  static const double _hoverGlowBlur = 28.0;

  late final AnimationController _controller;
  AnimationController? _orbitController;
  LottieComposition? _composition;
  bool _isHovered = false;
  bool _shouldLoad = false;
  bool _startDelayElapsed = false;
  Timer? _startTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener(_handleStatus);

    if (widget.showOrbital) {
      _orbitController = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 24),
      )..repeat();
    }

    _startTimer = Timer(widget.startDelay, () {
      if (!mounted) return;
      _startDelayElapsed = true;
      _maybeStart();
    });

    if (widget.lazyLoad) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() => _shouldLoad = true);
      });
    } else {
      _shouldLoad = true;
    }
  }

  @override
  void dispose() {
    _startTimer?.cancel();
    _orbitController?.dispose();
    _controller.removeStatusListener(_handleStatus);
    _controller.dispose();
    super.dispose();
  }

  void _handleStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      _controller.forward(from: 0.0);
    }
  }

  void _handleLoaded(LottieComposition composition) {
    _composition = composition;
    _controller.duration =
        _scaledDuration(_isHovered ? widget.hoverSpeed : _baseSpeed);
    _maybeStart();
  }

  void _maybeStart() {
    if (!mounted || _composition == null || !_shouldLoad) return;
    if (!_startDelayElapsed || _controller.isAnimating) return;
    _controller.forward(from: 0.0);
  }

  Duration _scaledDuration(double speed) {
    final base = _composition?.duration ?? const Duration(milliseconds: 1);
    return Duration(microseconds: (base.inMicroseconds / speed).round());
  }

  void _updateSpeed(double speed) {
    if (_composition == null) return;
    _controller.duration = _scaledDuration(speed);

    if (_controller.isAnimating) {
      _controller.forward(from: _controller.value);
    }
  }

  void _onHover(bool value) {
    if (_isHovered == value) return;
    setState(() => _isHovered = value);
    _updateSpeed(value ? widget.hoverSpeed : _baseSpeed);
  }

  @override
  Widget build(BuildContext context) {
    final glowOpacity = _isHovered
        ? _hoverGlowOpacity
        : (widget.tintColor != null ? 0.35 : _baseGlowOpacity);
    final glowBlur = _isHovered ? _hoverGlowBlur : _baseGlowBlur;

    final logo = _shouldLoad
        ? Lottie.asset(
            _assetPath,
            controller: _controller,
            fit: BoxFit.contain,
            frameRate: FrameRate.composition,
            onLoaded: _handleLoaded,
          )
        : const SizedBox.shrink();

    final content = AspectRatio(
      aspectRatio: _aspectRatio,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedOpacity(
            opacity: glowOpacity,
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOut,
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: glowBlur,
                sigmaY: glowBlur,
              ),
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  _neonMint,
                  BlendMode.srcATop,
                ),
                child: RepaintBoundary(child: logo),
              ),
            ),
          ),
          RepaintBoundary(child: logo),
        ],
      ),
    );

    final withOrbital = widget.showOrbital && _orbitController != null
        ? AnimatedBuilder(
            animation: _orbitController!,
            builder: (context, child) {
              return CustomPaint(
                painter: _OrbitalDetailPainter(
                  rotation: _orbitController!.value,
                  color: widget.tintColor ?? _neonMint,
                ),
                child: child,
              );
            },
            child: content,
          )
        : content;

    final sized = (widget.width != null || widget.height != null)
        ? SizedBox(width: widget.width, height: widget.height, child: withOrbital)
        : withOrbital;

    return Semantics(
      label: widget.ariaLabel,
      image: true,
      child: MouseRegion(
        onEnter: (_) => _onHover(true),
        onExit: (_) => _onHover(false),
        child: sized,
      ),
    );
  }
}

class _OrbitalDetailPainter extends CustomPainter {
  _OrbitalDetailPainter({
    required this.rotation,
    required this.color,
  });

  final double rotation;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r1 = size.shortestSide * 0.44;
    final r2 = size.shortestSide * 0.50;

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotation * 2 * pi);

    arcPaint
      ..color = color.withValues(alpha: 0.15)
      ..strokeWidth = 1.0;
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r1),
      -0.35,
      1.75,
      false,
      arcPaint,
    );

    arcPaint
      ..color = color.withValues(alpha: 0.08)
      ..strokeWidth = 0.7;
    canvas.drawArc(
      Rect.fromCircle(center: Offset.zero, radius: r2),
      2.6,
      1.15,
      false,
      arcPaint,
    );

    final dotPaint = Paint()..style = PaintingStyle.fill;

    dotPaint.color = color.withValues(alpha: 0.30);
    canvas.drawCircle(
      Offset(r1 * cos(-0.35), r1 * sin(-0.35)),
      1.6,
      dotPaint,
    );
    canvas.drawCircle(
      Offset(r1 * cos(-0.35 + 1.75), r1 * sin(-0.35 + 1.75)),
      1.6,
      dotPaint,
    );

    dotPaint.color = color.withValues(alpha: 0.18);
    canvas.drawCircle(
      Offset(r2 * cos(2.6 + 0.575), r2 * sin(2.6 + 0.575)),
      1.2,
      dotPaint,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_OrbitalDetailPainter old) => old.rotation != rotation;
}
