import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_text.dart';

String formatCountdown(Duration d) {
  if (d.isNegative) d = Duration.zero;
  final h = d.inHours, m = d.inMinutes.remainder(60), s = d.inSeconds.remainder(60);
  String two(int n) => n.toString().padLeft(2, '0');
  return h > 0 ? '$h:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
}

/// Counts down to [target] using [now] (the server-synced clock, never the bare device clock). Tabular numbers.
class CountdownText extends StatefulWidget {
  const CountdownText({super.key, required this.target, required this.now, this.style, this.prefix = '', this.onDone});
  final DateTime target;
  final DateTime Function() now;
  final TextStyle? style;
  final String prefix;
  final VoidCallback? onDone;
  @override
  State<CountdownText> createState() => _CountdownTextState();
}

class _CountdownTextState extends State<CountdownText> {
  Timer? _t;
  late Duration _left;
  @override
  void initState() {
    super.initState();
    _left = widget.target.difference(widget.now());
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      final l = widget.target.difference(widget.now());
      if (!mounted) return;
      setState(() => _left = l);
      if (l <= Duration.zero) {
        _t?.cancel();
        widget.onDone?.call();
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('${widget.prefix}${formatCountdown(_left)}', style: (widget.style ?? AppText.body).copyWith(fontFeatures: AppText.tabular));
}
