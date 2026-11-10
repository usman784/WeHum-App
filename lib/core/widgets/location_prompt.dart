import 'dart:math' as math;
import 'dart:ui' show PlatformDispatcher;
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import 'buttons.dart';
import 'painters.dart';

/// Our own explanation before the phone's location dialog: a dotted world map where your region pulses, then the
/// reason in one line, one clear button and a quiet "Not now". Static with Reduce Motion.
class LocationPromptCard extends StatefulWidget {
  const LocationPromptCard({super.key, required this.title, required this.body, required this.ok, required this.cancel, required this.onOk, required this.onCancel, this.icon = Icons.public_rounded});
  final String title, body, ok, cancel;
  final VoidCallback onOk, onCancel;
  final IconData icon;
  @override
  State<LocationPromptCard> createState() => _LocationPromptCardState();
}

class _LocationPromptCardState extends State<LocationPromptCard> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
  bool? _reduce;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final r = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (r != _reduce) {
      _reduce = r;
      r ? _c.value = .6 : _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  /// Where the pulse sits: the phone's region when we know it, otherwise a neutral spot.
  String get _code {
    final cc = PlatformDispatcher.instance.locale.countryCode?.toUpperCase();
    return cc != null && WorldDotMap.centroids.containsKey(cc) ? cc : 'GB';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1), duration: const Duration(milliseconds: 520), curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: Transform.scale(scale: .94 + .06 * t, child: child))),
      child: Dialog(
        backgroundColor: Colors.transparent, elevation: 0, insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28), border: Border.all(color: c.border),
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Color.alphaBlend(c.emberTint, c.surface), c.surface, c.surface], stops: const [0, .42, 1]), // solid: nothing shows through
          ),
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 14),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(
              height: 150,
              child: ExcludeSemantics(
                child: LayoutBuilder(builder: (_, box) {
                  final pos = WorldDotMap.centroids[_code]!;
                  final at = Offset((pos.$1 + 180) / 360 * box.maxWidth, (80 - pos.$2) / 160 * 150);
                  return Stack(children: [
                    WorldDotMap(height: 150, hot: {_code: 1}),
                    Positioned.fill(child: AnimatedBuilder(animation: _c, builder: (_, __) => CustomPaint(painter: _PulsePainter(at, c.ember, _c.value)))),
                  ]);
                }),
              ),
            ),
            const SizedBox(height: 14),
            Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(widget.icon, color: c.emberText, size: 22),
              const SizedBox(width: 8),
              Flexible(child: Text(widget.title, textAlign: TextAlign.center, style: AppText.heroTitle.copyWith(color: c.textPrimary, fontSize: 24))),
            ]),
            const SizedBox(height: 10),
            Text(widget.body, textAlign: TextAlign.center, style: AppText.bodySmall.copyWith(color: c.textSecondary, height: 1.45)),
            const SizedBox(height: 18),
            PrimaryButton(widget.ok, key: const Key('location-allow'), onPressed: widget.onOk),
            const SizedBox(height: 2),
            TextLink(widget.cancel, key: const Key('location-not-now'), onPressed: widget.onCancel, color: c.textSecondary),
          ]),
        ),
      ),
    );
  }
}

class _PulsePainter extends CustomPainter {
  _PulsePainter(this.at, this.color, this.t);
  final Offset at;
  final Color color;
  final double t;
  @override
  void paint(Canvas canvas, Size s) {
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1; // three staggered ripples
      canvas.drawCircle(at, 6 + 34 * p, Paint()..style = PaintingStyle.stroke..strokeWidth = 2..color = color.withValues(alpha: (1 - p) * .7));
    }
    canvas.drawCircle(at, 9 + math.sin(t * math.pi * 2) * 1.5, Paint()..color = color.withValues(alpha: .25));
    canvas.drawCircle(at, 5, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_PulsePainter o) => o.t != t || o.at != at;
}
