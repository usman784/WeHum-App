import 'package:flutter/material.dart';

/// Motion shared by the screens (the Stitch design is calm but alive): a soft entrance, a press response and counting
/// numbers. Everything is skipped when the phone asks for reduced motion.
bool reduceMotion(BuildContext context) => MediaQuery.maybeOf(context)?.disableAnimations ?? false;

/// Fades in and rises a few points, [delay] after the screen appears. Use [staggered] for lists.
class Entrance extends StatefulWidget {
  const Entrance({super.key, required this.child, this.delay = Duration.zero, this.dy = 14, this.duration = const Duration(milliseconds: 420)});
  final Widget child;
  final Duration delay, duration;
  final double dy;
  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: widget.delay + widget.duration);
  late final Animation<double> _t = CurvedAnimation(
    parent: _c,
    curve: Interval(widget.delay.inMilliseconds / (widget.delay + widget.duration).inMilliseconds, 1, curve: Curves.easeOutCubic),
  );

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return widget.child;
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (_, child) => Opacity(opacity: _t.value, child: Transform.translate(offset: Offset(0, (1 - _t.value) * widget.dy), child: child)),
    );
  }
}

/// Wraps each child in an [Entrance] with a growing delay (capped, so long lists do not wait).
List<Widget> staggered(List<Widget> children, {Duration step = const Duration(milliseconds: 60), int maxSteps = 8, Duration start = Duration.zero}) => [
      for (var i = 0; i < children.length; i++) Entrance(delay: start + step * (i < maxSteps ? i : maxSteps), child: children[i]),
    ];

/// Scales down a little while a finger is on it (buttons, cards, rows).
class Pressable extends StatefulWidget {
  const Pressable({super.key, required this.child, this.enabled = true, this.scale = .97});
  final Widget child;
  final bool enabled;
  final double scale;
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;
  void _set(bool v) {
    if (widget.enabled && _down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) => Listener(
        onPointerDown: (_) => _set(true),
        onPointerUp: (_) => _set(false),
        onPointerCancel: (_) => _set(false),
        child: reduceMotion(context)
            ? widget.child
            : AnimatedScale(scale: _down ? widget.scale : 1, duration: const Duration(milliseconds: 110), curve: Curves.easeOut, child: widget.child),
      );
}

/// A whole number that counts up to its value (and between values), in the text style given.
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, required this.builder, this.duration = const Duration(milliseconds: 700)});
  final int value;
  final Widget Function(BuildContext context, int shown) builder;
  final Duration duration;
  @override
  Widget build(BuildContext context) {
    if (reduceMotion(context)) return builder(context, value);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: value.toDouble()), duration: duration, curve: Curves.easeOutCubic,
      builder: (ctx, v, _) => builder(ctx, v.round()),
    );
  }
}

/// A dot that breathes: used for "live" indicators.
class PulseDot extends StatefulWidget {
  const PulseDot({super.key, required this.color, this.size = 8});
  final Color color;
  final double size;
  @override
  State<PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<PulseDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600));
  @override
  void initState() {
    super.initState();
    _c.repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final still = reduceMotion(context);
    if (still && _c.isAnimating) _c.stop();
    return SizedBox(
      width: widget.size * 2, height: widget.size * 2,
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Stack(alignment: Alignment.center, children: [
          Container(width: widget.size * (1 + (still ? 0 : _c.value)), height: widget.size * (1 + (still ? 0 : _c.value)), decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color.withValues(alpha: .28 * (1 - (still ? 0 : _c.value))))),
          Container(width: widget.size, height: widget.size, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color)),
        ]),
      ),
    );
  }
}
