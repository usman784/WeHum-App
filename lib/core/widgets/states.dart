import 'dart:async';
import 'package:flutter/material.dart';
import '../errors/error_code.dart';
import '../theme/app_colors.dart';
import '../theme/app_text.dart';
import '../theme/tokens.dart';
import 'buttons.dart';

enum ViewKind { loading, content, empty, error, offline }

/// Per-screen state (spec §6.1). Controllers expose `Rx<ViewState>`.
class ViewState {
  const ViewState._(this.kind, [this.error]);
  static const loading = ViewState._(ViewKind.loading);
  static const content = ViewState._(ViewKind.content);
  static const empty = ViewState._(ViewKind.empty);
  static const offline = ViewState._(ViewKind.offline);
  factory ViewState.error(ApiException e) => ViewState._(ViewKind.error, e);
  final ViewKind kind;
  final ApiException? error;

  /// Maps a failure to offline (network/timeout) or error.
  factory ViewState.fromError(Object e) {
    final a = e is ApiException ? e : ApiException(ErrorCode.internal, message: '$e');
    return (a.code == ErrorCode.network || a.code == ErrorCode.timeout) ? ViewState.offline : ViewState.error(a);
  }
}

/// loading → skeleton (only after 300 ms, so quick loads do not flash), content, empty, error (retry), offline.
class StateSwitcher extends StatelessWidget {
  const StateSwitcher({super.key, required this.state, required this.content, this.skeleton, this.empty, this.onRetry, this.skeletonDelay = const Duration(milliseconds: 300)});
  final ViewState state;
  final Widget Function() content;
  final Widget? skeleton, empty;
  final VoidCallback? onRetry;
  final Duration skeletonDelay;

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: Motion.state,
        child: switch (state.kind) {
          ViewKind.loading => _Delayed(delay: skeletonDelay, child: skeleton ?? const SkeletonList()),
          ViewKind.content => KeyedSubtree(key: const ValueKey('content'), child: content()),
          ViewKind.empty => empty ?? const EmptyState(title: 'Nothing here yet', body: ''),
          ViewKind.error => ErrorState(code: state.error?.code.wire, traceId: state.error?.traceId, onRetry: onRetry),
          ViewKind.offline => ErrorState(offline: true, onRetry: onRetry),
        },
      );
}

class _Delayed extends StatefulWidget {
  const _Delayed({required this.delay, required this.child});
  final Duration delay;
  final Widget child;
  @override
  State<_Delayed> createState() => _DelayedState();
}

class _DelayedState extends State<_Delayed> {
  bool show = false;
  Timer? t;
  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      show = true;
    } else {
      t = Timer(widget.delay, () => mounted ? setState(() => show = true) : null);
    }
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => show ? widget.child : const SizedBox.expand();
}

/// Shimmering block.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height = 16, this.radius = 8});
  final double? width;
  final double height, radius;
  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return ExcludeSemantics(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) => Container(
          width: widget.width, height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: reduce ? null : LinearGradient(colors: [c.surface, c.surfaceAlt, c.surface], stops: [(_c.value - .3).clamp(0, 1), _c.value, (_c.value + .3).clamp(0, 1)]),
            color: reduce ? c.surface : null,
          ),
        ),
      ),
    );
  }
}

class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.rows = 5});
  final int rows;
  @override
  Widget build(BuildContext context) => Padding(
        key: const ValueKey('skeleton'),
        padding: const EdgeInsets.all(Gap.gutter),
        child: SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(children: [
            const Skeleton(height: 200, radius: Radii.cardLarge),
            for (var i = 0; i < rows; i++) ...[const SizedBox(height: 14), const Skeleton(height: 64, radius: Radii.card)],
          ]),
        ),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.title, required this.body, this.icon = Icons.spa_outlined, this.ctaLabel, this.onCta});
  final String title, body;
  final IconData icon;
  final String? ctaLabel;
  final VoidCallback? onCta;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(child: Icon(icon, size: 48, color: c.textTertiary)),
          const SizedBox(height: 16),
          Text(title, textAlign: TextAlign.center, style: AppText.title.copyWith(color: c.textPrimary)),
          if (body.isNotEmpty) ...[const SizedBox(height: 8), Text(body, textAlign: TextAlign.center, style: AppText.body.copyWith(color: c.textSecondary))],
          if (ctaLabel != null) ...[const SizedBox(height: 24), PrimaryButton(ctaLabel!, onPressed: onCta, fullWidth: false)],
        ]),
      ),
    );
  }
}

/// Error (code shown small, Retry, Contact) or offline.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, this.code, this.traceId, this.offline = false, this.onRetry});
  final String? code, traceId;
  final bool offline;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ExcludeSemantics(child: Icon(offline ? Icons.wifi_off_rounded : Icons.error_outline_rounded, size: 48, color: c.textTertiary)),
          const SizedBox(height: 16),
          Text(offline ? "You're offline" : 'Something went wrong', style: AppText.title.copyWith(color: c.textPrimary)),
          const SizedBox(height: 8),
          Text(offline ? "You're offline. Downloads still work." : 'Please try again in a moment.', textAlign: TextAlign.center, style: AppText.body.copyWith(color: c.textSecondary)),
          if (code != null && !offline) Padding(padding: const EdgeInsets.only(top: 8), child: Text(traceId == null ? code! : '$code · $traceId', style: AppText.micro.copyWith(color: c.textTertiary))),
          if (onRetry != null) ...[const SizedBox(height: 24), PrimaryButton('Try again', onPressed: onRetry, fullWidth: false)],
        ]),
      ),
    );
  }
}

/// Thin banner shown on cached screens while offline.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key, this.text = "You're offline. Downloads still work."});
  final String text;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      child: Container(
        width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: Gap.gutter, vertical: 10), color: c.infoBg,
        child: Row(children: [
          Icon(Icons.wifi_off_rounded, size: 16, color: c.infoText),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: AppText.caption.copyWith(color: c.infoText, fontWeight: FontWeight.w600))),
        ]),
      ),
    );
  }
}

abstract final class AppSnack {
  static void success(BuildContext c, String m) => _show(c, m, false);
  static void error(BuildContext c, String m) => _show(c, m, true);
  static void _show(BuildContext context, String m, bool err) {
    final col = context.colors;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating, backgroundColor: err ? col.dangerTint.withValues(alpha: 1) : col.surfaceAlt,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Radii.tile), side: BorderSide(color: err ? col.dangerBorder : col.border)),
        content: Text(m, style: AppText.bodySmall.copyWith(color: err ? col.dangerText : col.textPrimary, fontWeight: FontWeight.w600)),
      ));
  }
}
