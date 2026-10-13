import '../../../core/services/pip.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt;
import '../../../app/routes/app_routes.dart';
import '../../../core/audio/audio_engine.dart';
import '../../../core/audio/interval_chime.dart';
import '../../../core/audio/engines.dart';
import '../../../core/audio/local_media.dart';
import '../../../core/audio/media_session.dart';
import '../../../core/data/contracts/repositories.dart';
import '../../../core/realtime/live_service.dart';
import '../../../core/realtime/presence_service.dart';
import '../../../core/services/access_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/catalog_service.dart';
import '../../../core/services/connectivity_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/painters.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/app_scaffold.dart' show StitchHeader;
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/surfaces.dart';
import '../../today/controllers/today_controller.dart';
import '../../today/views/today_widgets.dart';
import '../controllers/player_controller.dart';
import '../player_args.dart';

PlayerController _make(PlayerArgs args, AudioEngine engine) => Get.put(
      PlayerController(
        args, engine: engine, media: Get.find<MediaRepository>(), presence: Get.find<PresenceService>(), sync: Get.find<SyncService>(), analytics: Get.find<AnalyticsService>(),
        local: Get.find<LocalMedia>(), connectivity: Get.find<ConnectivityService>(), catalog: () => Get.find<CatalogService>().catalog.value, mediaSession: Get.find<MediaSessionPort>(),
        chime: Get.isRegistered<ChimePort>() ? Get.find<ChimePort>() : null),
      tag: args.sessionId ?? args.title,
    );

String mmss(Duration d) {
  final m = d.inMinutes, s = d.inSeconds.remainder(60);
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

PlayerArgs _args() {
  final a = Get.arguments;
  return a is PlayerArgs ? a : const PlayerArgs(kind: 'solo', title: 'Meditation');
}

/// Play/pause, ±15 s, progress and times — shared by the three players.
class TransportControls extends StatelessWidget {
  const TransportControls({super.key, required this.ctrl, this.live = false});
  final PlayerController ctrl;
  final bool live;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Obx(() {
      final playing = ctrl.phase.value == PlayerPhase.playing || ctrl.phase.value == PlayerPhase.buffering;
      return Column(children: [
        Semantics(
          label: 'Progress ${mmss(ctrl.position.value)} of ${mmss(ctrl.duration.value)}',
          child: AppProgressBar(ctrl.progress),
        ),
        const SizedBox(height: 8),
        Row(children: [
          Text(mmss(ctrl.position.value), key: const Key('pos'), style: AppText.bodySmall.copyWith(color: c.textSecondary, fontFeatures: AppText.tabular)),
          const Spacer(),
          Text(mmss(ctrl.duration.value), key: const Key('dur'), style: AppText.bodySmall.copyWith(color: c.textSecondary, fontFeatures: AppText.tabular)),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (!live) _RoundBtn(key: const Key('back15'), icon: Icons.replay_10_rounded, label: 'Back 15 seconds', text: '−15', onTap: ctrl.back15),
          const SizedBox(width: 24),
          Semantics(
            button: true, label: playing ? 'Pause' : 'Play',
            child: GestureDetector(
              key: const Key('play-pause'), onTap: ctrl.togglePlay,
              child: Container(width: 76, height: 76, decoration: BoxDecoration(color: c.ember, shape: BoxShape.circle), child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 40, color: c.onEmber)),
            ),
          ),
          const SizedBox(width: 24),
          if (!live) _RoundBtn(key: const Key('fwd15'), icon: Icons.forward_10_rounded, label: 'Forward 15 seconds', text: '+15', onTap: ctrl.forward15),
        ]),
      ]);
    });
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({super.key, required this.icon, required this.label, required this.text, required this.onTap});
  final IconData icon;
  final String label, text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true, label: label,
      child: GestureDetector(onTap: onTap, child: Container(width: 56, height: 56, alignment: Alignment.center, decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle, border: Border.all(color: c.border)), child: Text(text, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 14)))),
    );
  }
}

/// "Connection lost — continue when you're back" (auto-resumes), as a banner so it never blocks the meditation.
class StalledBanner extends StatelessWidget {
  const StalledBanner({super.key, required this.ctrl});
  final PlayerController ctrl;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Obx(() => !ctrl.stalledSheet.value
        ? const SizedBox.shrink()
        : Container(
            key: const Key('stalled'), margin: const EdgeInsets.only(bottom: 12), padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: c.infoBg, borderRadius: BorderRadius.circular(Radii.tile)),
            child: Row(children: [Icon(Icons.wifi_off_rounded, color: c.infoText), const SizedBox(width: 10), Expanded(child: Text('Connection lost — continue when you’re back. We’ll resume by ourselves.', style: AppText.bodySmall.copyWith(color: c.infoText, fontWeight: FontWeight.w600)))]),
          ));
  }
}

/// The player when something went wrong (not available, error).
class PlayerFailure extends StatelessWidget {
  const PlayerFailure({super.key, required this.ctrl});
  final PlayerController ctrl;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unavailable = ctrl.phase.value == PlayerPhase.unavailable;
    return Padding(
      padding: const EdgeInsets.all(32),
      child: SizedBox(width: double.infinity, child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline_rounded, size: 56, color: c.textTertiary),
        const SizedBox(height: 16),
        Text(unavailable ? 'Not available right now' : 'This session couldn’t load', textAlign: TextAlign.center, style: AppText.title.copyWith(color: c.textPrimary)),
        const SizedBox(height: 8),
        Text(unavailable ? 'Please try another meditation.' : 'Check your connection and try again. Downloaded sessions still play offline.', textAlign: TextAlign.center, style: AppText.body.copyWith(color: c.textSecondary)),
        const SizedBox(height: 24),
        if (!unavailable) PrimaryButton('Try again', fullWidth: false, onPressed: () => Get.offNamed(AppRoutes.playerPresenceRing, arguments: ctrl.args)),
        TextLink('Go to downloads', onPressed: () => Get.offNamed(AppRoutes.downloads), color: c.textSecondary),
        TextLink('Close', onPressed: () => Get.back<void>(), color: c.textSecondary),
      ])),
    );
  }
}

/// 42 Audio player (Stitch "Active practice"): header, the presence ring with the telemetry in its core, the live signal,
/// phase and scrubber, controls, the acoustic balance desk and the end-early safeguard.
class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  String _eyebrow(PlayerArgs a) {
    final cat = Get.isRegistered<CatalogService>() ? Get.find<CatalogService>().catalog.value : null;
    final s = a.sessionId == null ? null : cat?.session(a.sessionId!);
    final theme = s?.themeId == null ? null : cat?.theme(s!.themeId!)?.name;
    if (theme != null) return theme;
    return switch (a.kind) { 'motd' => 'Meditation of the Day', 'group' => 'Group sit', 'sos' => 'SoS', 'custom' => 'Build your own', 'program' => 'Program', _ => 'Active practice' };
  }

  @override
  Widget build(BuildContext context) {
    final args = _args();
    final ctrl = _make(args, args.recipe != null ? Get.find<PlayerEngines>().recipe() : Get.find<PlayerEngines>().audio());
    final live = Get.find<LiveService>();
    final c = context.colors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ctrl.endEarly();
      },
      child: Scaffold(
        body: SafeArea(
          child: Obx(() {
            if (ctrl.phase.value == PlayerPhase.unavailable || ctrl.phase.value == PlayerPhase.error) return PlayerFailure(ctrl: ctrl);
            final t = ctrl.togetherRx.value;
            final quiet = live.agg.value?.quiet ?? false;
            final people = t?.people ?? 0;
            final belts = live.agg.value?.belts ?? const <String, int>{};
            final playing = ctrl.phase.value == PlayerPhase.playing || ctrl.phase.value == PlayerPhase.buffering;
            final left = ctrl.duration.value - ctrl.position.value;
            const bpm = 60 / 10; // 4 s in + 6 s out
            return Column(children: [
              _PlayerHeader(ctrl.endEarly),
              Expanded(
                child: ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 4, Gap.gutter, 24), children: staggered([
                  Row(children: [
                    _SquareBtn(key: const Key('minimize'), icon: Icons.keyboard_arrow_down_rounded, label: 'Minimise', onTap: ctrl.endEarly),
                    Expanded(child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.center, children: [Container(width: 6, height: 6, decoration: BoxDecoration(color: c.success, shape: BoxShape.circle)), const SizedBox(width: 6), Flexible(child: Text(_eyebrow(args).toUpperCase(), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.overline.copyWith(color: c.tealText, fontSize: 10)))]),
                      Text(args.title, key: const Key('player-title'), maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 18)),
                      Text(args.programDay != null ? 'Raphael · Day ${args.programDay}' : (args.subtitle ?? 'Raphael'), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: c.textSecondary)),
                    ])),
                    const SizedBox(width: 40),
                  ]),
                  SizedBox(
                    height: 330,
                    child: Stack(alignment: Alignment.center, children: [
                      SessionRing(
                        progress: ctrl.progress, people: people, size: 310,
                        center: Stack(alignment: Alignment.center, children: [
                          Opacity(opacity: .10, child: ClipOval(child: ThumbImage(args.coverUrl, key: const Key('player-art'), seed: args.sessionId ?? args.title, width: 170, height: 170))),
                          Column(mainAxisSize: MainAxisSize.min, children: [
                            _PhaseLabel(),
                            const SizedBox(height: 2),
                            Text(mmss(ctrl.position.value), key: const Key('pos-big'), style: AppText.display.copyWith(color: c.textPrimary, fontSize: 44, fontFeatures: AppText.tabular)),
                            const SizedBox(height: 2),
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              Text('-${mmss(left.isNegative ? Duration.zero : left)}', style: AppText.caption.copyWith(color: c.textSecondary, fontFeatures: AppText.tabular)),
                              Text('  •  ', style: AppText.caption.copyWith(color: c.textTertiary)),
                              Text('${bpm.toStringAsFixed(1)} BPM', style: AppText.overline.copyWith(color: c.emberText, fontSize: 10.5)),
                            ]),
                          ]),
                        ]),
                      ),
                      if (!live.paused && !quiet) ..._hubs(c, belts),
                    ]),
                  ),
                  _TogetherPill(people: people, countries: t?.countries ?? 0, quiet: quiet, meditatedToday: live.agg.value?.meditatedToday ?? 0, paused: live.paused),
                  Column(children: [
                    Row(children: [
                      Icon(Icons.radio_button_checked_rounded, size: 18, color: c.emberText),
                      const SizedBox(width: 8),
                      Expanded(child: Text(ctrl.chapter == null ? 'Guided practice' : 'Phase ${ctrl.chapter!.n}: ${ctrl.chapter!.title}', key: const Key('phase-chip'), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 17))),
                      if (ctrl.chapter != null) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3), decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(99)), child: Text('PART ${ctrl.chapter!.n}/${ctrl.chapter!.of}', style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10))),
                    ]),
                    const SizedBox(height: 10),
                    Semantics(label: 'Progress ${mmss(ctrl.position.value)} of ${mmss(ctrl.duration.value)}', child: AppProgressBar(ctrl.progress)),
                    const SizedBox(height: 8),
                    Row(children: [
                      Text(mmss(ctrl.position.value), key: const Key('pos'), style: AppText.bodySmall.copyWith(color: c.textSecondary, fontFeatures: AppText.tabular)),
                      const Spacer(),
                      Text(mmss(ctrl.duration.value), key: const Key('dur'), style: AppText.bodySmall.copyWith(color: c.textSecondary, fontFeatures: AppText.tabular)),
                    ]),
                  ]),
                  StalledBanner(ctrl: ctrl),
                  if (ctrl.phase.value == PlayerPhase.loading)
                    const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: Center(child: CircularProgressIndicator()))
                  else
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (!(args.live || args.recipe != null)) _RoundBtn(key: const Key('back15'), icon: Icons.replay_10_rounded, label: 'Back 15 seconds', text: '−15', onTap: ctrl.back15),
                      const SizedBox(width: 28),
                      Semantics(
                        button: true, label: playing ? 'Pause' : 'Play',
                        child: GestureDetector(
                          key: const Key('play-pause'), onTap: ctrl.togglePlay,
                          child: Pressable(scale: .94, child: Container(width: 80, height: 80, decoration: BoxDecoration(color: c.ember, shape: BoxShape.circle, boxShadow: [BoxShadow(color: c.ember.withValues(alpha: .35), blurRadius: 24, offset: const Offset(0, 8))]), child: Icon(playing ? Icons.pause_rounded : Icons.play_arrow_rounded, size: 42, color: c.onEmber))),
                        ),
                      ),
                      const SizedBox(width: 28),
                      if (!(args.live || args.recipe != null)) _RoundBtn(key: const Key('fwd15'), icon: Icons.forward_10_rounded, label: 'Forward 15 seconds', text: '+15', onTap: ctrl.forward15),
                    ]),
                  _MixDesk(ctrl: ctrl, args: args),
                  Row(children: [
                    Icon(Icons.bolt_rounded, size: 16, color: c.success),
                    const SizedBox(width: 6),
                    Expanded(child: Text('Streak guarded at completion', style: AppText.caption.copyWith(color: c.textSecondary))),
                    TextButton(key: const Key('end'), onPressed: ctrl.endEarly, child: Text('End practice early', style: AppText.caption.copyWith(color: c.textSecondary))),
                  ]),
                ].map((w) => Padding(padding: const EdgeInsets.only(bottom: 14), child: w)).toList())),
              ),
            ]);
          }),
        ),
      ),
    );
  }

  /// Region hubs around the ring (Stitch "NYC • 84"): real counts by belt from the live aggregate.
  List<Widget> _hubs(AppColors c, Map<String, int> belts) {
    Widget hub(String label, int n, Alignment a, Color dot) => n <= 0
        ? const SizedBox.shrink()
        : Align(alignment: a, child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
            const SizedBox(height: 3),
            Text('$label • $n', style: AppText.overline.copyWith(color: c.textTertiary, fontSize: 8.5)),
          ]));
    return [
      hub('AMERICAS', belts['americas'] ?? 0, const Alignment(-.82, -.42), c.ember),
      hub('EMEA', belts['emea'] ?? 0, const Alignment(.02, -.86), c.success),
      hub('APAC', belts['apac'] ?? 0, const Alignment(.82, -.38), c.tealText),
    ];
  }
}

/// "Inhale · Anchor" / "Exhale · Release" in step with the ring (4 s in, 6 s out).
class _PhaseLabel extends StatefulWidget {
  @override
  State<_PhaseLabel> createState() => _PhaseLabelState();
}

class _PhaseLabelState extends State<_PhaseLabel> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: Motion.breatheIn + Motion.breatheOut)..repeat();
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Text(_c.value < .4 ? 'INHALE · ANCHOR' : 'EXHALE · RELEASE', key: const Key('breath-cue'), style: AppText.overline.copyWith(color: c.tealText, fontSize: 10, letterSpacing: 1.4)),
    );
  }
}

class _PlayerHeader extends StatelessWidget {
  const _PlayerHeader(this.onBack);
  final VoidCallback onBack;
  @override
  Widget build(BuildContext context) => StitchHeader(title: 'Active practice', onBack: onBack);
}

class _SquareBtn extends StatelessWidget {
  const _SquareBtn({super.key, required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(button: true, label: label, child: GestureDetector(onTap: onTap, child: Container(width: 40, height: 40, decoration: BoxDecoration(color: c.surface, shape: BoxShape.circle), child: Icon(icon, size: 22, color: c.textPrimary))));
  }
}

/// "412 synchronized worldwide · Global field active" — quiet rule: never a small number as if it were a crowd; paused: no numbers.
class _TogetherPill extends StatelessWidget {
  const _TogetherPill({required this.people, required this.countries, required this.quiet, required this.meditatedToday, required this.paused});
  final int people, countries, meditatedToday;
  final bool quiet, paused;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = paused
        ? 'Live counts paused'
        : (people <= 0 ? '' : (quiet ? (meditatedToday > 0 ? 'You’re meditating · ${groupNumber(meditatedToday)} meditated today' : 'You’re meditating') : '${groupNumber(people)} synchronized worldwide'));
    if (text.isEmpty) return const SizedBox(height: 4);
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8), decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(99)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          paused || quiet ? Container(width: 8, height: 8, decoration: BoxDecoration(color: c.textTertiary, shape: BoxShape.circle)) : PulseDot(color: c.success, size: 4),
          const SizedBox(width: 6),
          Flexible(child: Text(text, key: const Key('together-line'), maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 13, fontFeatures: AppText.tabular))),
          if (!paused && !quiet && countries > 0) ...[const SizedBox(width: 8), Icon(Icons.public_rounded, size: 14, color: c.success), const SizedBox(width: 4), Text('$countries countries', style: AppText.caption.copyWith(color: c.success))],
        ]),
      ),
    );
  }
}

/// "Acoustic balance": the guide's volume (and the undercurrent's for a built meditation), the interval chime and haptic pacing.
class _MixDesk extends StatelessWidget {
  const _MixDesk({required this.ctrl, required this.args});
  final PlayerController ctrl;
  final PlayerArgs args;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    Widget bar(Key key, String left, String right, IconData icon, double value, ValueChanged<double> onChanged) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Expanded(child: Text(left, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodySmall.copyWith(color: c.textPrimary))), Text('${(value * 100).round()}%', style: AppText.caption.copyWith(color: c.emberText, fontWeight: FontWeight.w700, fontFeatures: AppText.tabular))]),
          const SizedBox(height: 4),
          LayoutBuilder(builder: (_, k) => GestureDetector(
            key: key, behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) => onChanged(((d.localPosition.dx) / k.maxWidth).clamp(0.0, 1.0)),
            onTapDown: (d) => onChanged(((d.localPosition.dx) / k.maxWidth).clamp(0.0, 1.0)),
            child: Container(
              height: 34, decoration: BoxDecoration(color: c.bgDeep, borderRadius: BorderRadius.circular(10)),
              child: Stack(children: [
                AnimatedContainer(duration: const Duration(milliseconds: 90), width: k.maxWidth * value, decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(10))),
                Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Row(children: [Icon(icon, size: 15, color: c.textSecondary), const SizedBox(width: 6), Expanded(child: Text(right, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.overline.copyWith(color: c.textSecondary, fontSize: 10)))])),
              ]),
            ),
          )),
        ]);
    Widget toggle(Key key, IconData icon, String label, bool on, VoidCallback onTap) => Expanded(
          child: GestureDetector(
            key: key, behavior: HitTestBehavior.opaque, onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9), decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(10)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 17, color: on ? c.emberText : c.textSecondary), const SizedBox(width: 6), Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: c.textPrimary))), Text(on ? ' ON' : ' OFF', style: AppText.caption.copyWith(color: on ? c.success : c.textTertiary, fontWeight: FontWeight.w800))]),
            ),
          ),
        );
    return AppCard(
      key: const Key('mix-desk'), padding: const EdgeInsets.all(14),
      child: Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.equalizer_rounded, size: 20, color: c.tealText),
              const SizedBox(width: 8),
              Expanded(child: Text('Acoustic balance', style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 16))),
              if (ctrl.offlinePlayback.value) Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: c.surfaceAlt, borderRadius: BorderRadius.circular(99)), child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(Icons.offline_pin_outlined, size: 13, color: c.success), const SizedBox(width: 4), Text('DOWNLOADED', style: AppText.overline.copyWith(color: c.textPrimary, fontSize: 9.5))])),
            ]),
            const SizedBox(height: 12),
            bar(const Key('volume-slider'), 'Guide • ${args.subtitle?.replaceFirst('with ', '') ?? 'Raphael'}', 'Direct voice', Icons.record_voice_over_outlined, ctrl.volume.value, ctrl.setVolume),
            const SizedBox(height: 12),
            Row(children: [
              toggle(const Key('chime-switch'), Icons.notifications_active_outlined, 'Chime every 5m:', ctrl.chimeEveryMin.value == 5, () => ctrl.setChime(ctrl.chimeEveryMin.value == 5 ? 0 : 5)),
              const SizedBox(width: 10),
              toggle(const Key('haptics-switch'), Icons.vibration_rounded, 'Haptics pacing', ctrl.haptics.value, () => ctrl.setHaptics(!ctrl.haptics.value)),
            ]),
          ])),
    );
  }
}

/// 43 Video player (premium).
class VideoPlayerPage extends StatelessWidget {
  const VideoPlayerPage({super.key});
  @override
  Widget build(BuildContext context) {
    final args = _args();
    final engine = Get.find<PlayerEngines>().video();
    final ctrl = _make(args, engine);
    final c = context.colors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ctrl.endEarly();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Obx(() {
            if (ctrl.phase.value == PlayerPhase.unavailable || ctrl.phase.value == PlayerPhase.error) return PlayerFailure(ctrl: ctrl);
            final vc = engine is VideoEngine ? engine.controller : null;
            return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 8, Gap.gutter, 16), children: [
              AspectRatio(
                aspectRatio: 16 / 9,
                child: ClipRRect(borderRadius: BorderRadius.circular(Radii.tile), child: vc != null && vc.value.isInitialized ? VideoPlayer(vc) : ColoredBox(color: c.surface, child: const Center(child: CircularProgressIndicator()))),
              ),
              const SizedBox(height: 12),
              const Row(children: [AppBadge(BadgeKind.premium), SizedBox(width: 8), AppBadge(BadgeKind.video)]),
              const SizedBox(height: 8),
              Text(args.title, style: AppText.title.copyWith(color: Colors.white)),
              if (args.subtitle != null) Text(args.subtitle!, style: AppText.bodySmall.copyWith(color: c.textSecondary)),
              const SizedBox(height: 12),
              StalledBanner(ctrl: ctrl),
              TransportControls(ctrl: ctrl),
              if (Pip.supported) const Align(child: TextLink('Picture in picture', key: Key('pip'), onPressed: Pip.enter)),
              const SizedBox(height: 16),
              if (ctrl.togetherRx.value != null) Text('${ctrl.togetherRx.value!.people} ${ctrl.togetherRx.value!.people == 1 ? 'person' : 'people'} in this session now', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
              const SizedBox(height: 12),
              OutlineButton('End meditation', key: const Key('end'), onPressed: ctrl.endEarly),
            ]);
          }),
        ),
      ),
    );
  }
}

/// 44 Free player (YouTube iframe). Free users see "Free for you" + the upsell; members see the plain library title.
class FreePlayerPage extends StatelessWidget {
  const FreePlayerPage({super.key});
  @override
  Widget build(BuildContext context) {
    final args = _args();
    final engine = Get.find<PlayerEngines>().youtube();
    final ctrl = _make(args, engine);
    final access = Get.find<AccessService>();
    final c = context.colors;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) ctrl.endEarly();
      },
      child: Scaffold(
        body: SafeArea(
          child: Obx(() {
            if (ctrl.phase.value == PlayerPhase.unavailable || ctrl.phase.value == PlayerPhase.error) return PlayerFailure(ctrl: ctrl);
            final ytc = engine is YoutubeEngine ? engine.controller : null;
            final member = access.isMember;
            return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 8, Gap.gutter, 16), children: [
              AspectRatio(aspectRatio: 16 / 9, child: ClipRRect(borderRadius: BorderRadius.circular(Radii.tile), child: ytc != null ? yt.YoutubePlayer(controller: ytc) : ColoredBox(color: c.surface))),
              const SizedBox(height: 12),
              if (!member) const Align(alignment: Alignment.centerLeft, child: AppBadge(BadgeKind.freeForYou)),
              const SizedBox(height: 8),
              Text(member ? 'Raphael’s online library' : 'Free for you', key: const Key('free-label'), style: AppText.overline.copyWith(color: c.tealText)),
              Text(args.title, key: const Key('player-title'), style: AppText.title.copyWith(color: c.textPrimary)),
              Text(args.subtitle ?? 'Raphael', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
              const SizedBox(height: 12),
              StalledBanner(ctrl: ctrl),
              TransportControls(ctrl: ctrl),
              const SizedBox(height: 16),
              if (!member)
                AppCard(
                  key: const Key('upsell'), onTap: () => openPaywall('lock'),
                  child: Row(children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('Meditate with the world', style: AppText.navTitle.copyWith(color: c.textPrimary)), Text('Try 7 days free: Meditation of the Day, group meditations and more.', style: AppText.bodySmall.copyWith(color: c.textSecondary))])),
                    Icon(Icons.chevron_right_rounded, color: c.textSecondary),
                  ]),
                ),
              const SizedBox(height: 12),
              if (!member) Center(child: Text('Dedications are for members', style: AppText.caption.copyWith(color: c.textTertiary))),
              const SizedBox(height: 12),
              OutlineButton('End meditation', key: const Key('end'), onPressed: ctrl.endEarly),
            ]);
          }),
        ),
      ),
    );
  }
}

/// "Mix & pacing" sheet: volume of this meditation, an interval chime and haptic breath pacing.
Future<void> showMixSheet(BuildContext context, PlayerController ctrl) {
  return showAppSheet<void>(context, title: 'Mix & pacing', builder: (ctx) {
    final c = ctx.colors;
    return Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('VOLUME', style: AppText.overline.copyWith(color: c.textTertiary)),
          Slider(key: const Key('volume-slider'), value: ctrl.volume.value, onChanged: ctrl.setVolume, activeColor: c.ember, inactiveColor: c.track),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Chime every 5 minutes', style: AppText.bodyLarge.copyWith(color: c.textPrimary)),
              Text('A soft bell on top of the meditation', style: AppText.caption.copyWith(color: c.textSecondary)),
            ])),
            AppToggle(key: const Key('chime-switch'), value: ctrl.chimeEveryMin.value == 5, onChanged: (v) => ctrl.setChime(v ? 5 : 0), label: 'Chime every 5 minutes'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Haptic breath pacing', style: AppText.bodyLarge.copyWith(color: c.textPrimary)),
              Text('A light tap at the start of every breath', style: AppText.caption.copyWith(color: c.textSecondary)),
            ])),
            AppToggle(key: const Key('haptics-switch'), value: ctrl.haptics.value, onChanged: ctrl.setHaptics, label: 'Haptic breath pacing'),
          ]),
        ]));
  });
}
