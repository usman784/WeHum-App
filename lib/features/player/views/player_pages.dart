import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:video_player/video_player.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart' as yt;
import '../../../app/routes/app_routes.dart';
import '../../../core/audio/audio_engine.dart';
import '../../../core/audio/engines.dart';
import '../../../core/audio/local_media.dart';
import '../../../core/audio/recipe_engine.dart' show RecipeEngineFactory;
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
import '../../../core/widgets/app_scaffold.dart' show SosPill;
import '../../../core/widgets/surfaces.dart';
import '../../today/controllers/today_controller.dart';
import '../../today/views/today_widgets.dart';
import '../controllers/player_controller.dart';
import '../player_args.dart';

PlayerController _make(PlayerArgs args, AudioEngine engine) => Get.put(
      PlayerController(
        args, engine: engine, media: Get.find<MediaRepository>(), presence: Get.find<PresenceService>(), sync: Get.find<SyncService>(), analytics: Get.find<AnalyticsService>(),
        local: Get.find<LocalMedia>(), connectivity: Get.find<ConnectivityService>(), catalog: () => Get.find<CatalogService>().catalog.value),
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
      child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(Icons.error_outline_rounded, size: 56, color: c.textTertiary),
        const SizedBox(height: 16),
        Text(unavailable ? 'Not available right now' : 'This session couldn’t load', textAlign: TextAlign.center, style: AppText.title.copyWith(color: c.textPrimary)),
        const SizedBox(height: 8),
        Text(unavailable ? 'Please try another meditation.' : 'Check your connection and try again. Downloaded sessions still play offline.', textAlign: TextAlign.center, style: AppText.body.copyWith(color: c.textSecondary)),
        const SizedBox(height: 24),
        if (!unavailable) PrimaryButton('Try again', fullWidth: false, onPressed: () => Get.offNamed(AppRoutes.playerPresenceRing, arguments: ctrl.args)),
        TextLink('Go to downloads', onPressed: () => Get.offNamed(AppRoutes.downloads), color: c.textSecondary),
        TextLink('Close', onPressed: () => Get.back<void>(), color: c.textSecondary),
      ]),
    );
  }
}

/// 42 Audio player · presence ring.
class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});
  @override
  Widget build(BuildContext context) {
    final args = _args();
    final ctrl = _make(args, args.recipe != null ? Get.find<RecipeEngineFactory>()() : Get.find<AudioEngineFactory>()());
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
            return Padding(
              padding: const EdgeInsets.fromLTRB(Gap.gutterOnboarding, 8, Gap.gutterOnboarding, 16),
              child: Column(children: [
                const Align(alignment: Alignment.centerRight, child: SosPill()),
                const Spacer(),
                PresenceRing(people: people > 0 ? people : 8, size: 280),
                const Spacer(),
                const Overline('Now playing'),
                const SizedBox(height: 8),
                Text(args.title, key: const Key('player-title'), textAlign: TextAlign.center, style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                if (args.subtitle != null) Text(args.subtitle!, style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
                const SizedBox(height: 10),
                _TogetherLine(people: people, countries: t?.countries ?? 0, quiet: quiet, meditatedToday: live.agg.value?.meditatedToday ?? 0, paused: live.paused),
                const SizedBox(height: 20),
                StalledBanner(ctrl: ctrl),
                if (ctrl.phase.value == PlayerPhase.loading) const Padding(padding: EdgeInsets.symmetric(vertical: 24), child: CircularProgressIndicator()) else TransportControls(ctrl: ctrl, live: args.live || args.recipe != null),
                const SizedBox(height: 16),
                OutlineButton('End meditation', key: const Key('end'), onPressed: ctrl.endEarly),
                const SizedBox(height: 10),
                Text('Each dot is someone meditating with you. Dedications open when your meditation ends.', textAlign: TextAlign.center, style: AppText.caption.copyWith(color: c.textTertiary)),
              ]),
            );
          }),
        ),
      ),
    );
  }
}

/// "Meditating with 412 people · 37 countries" — quiet rule: never a small number as if it were a crowd; paused: no numbers.
class _TogetherLine extends StatelessWidget {
  const _TogetherLine({required this.people, required this.countries, required this.quiet, required this.meditatedToday, required this.paused});
  final int people, countries, meditatedToday;
  final bool quiet, paused;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final text = paused
        ? 'Live counts paused'
        : (people <= 0 ? '' : (quiet ? 'You’re meditating · $meditatedToday meditated today' : 'Meditating with ${groupNumber(people)} people · $countries countries'));
    if (text.isEmpty) return const SizedBox(height: 20);
    return Text(text, key: const Key('together-line'), textAlign: TextAlign.center, style: AppText.bodySmall.copyWith(color: paused || quiet ? c.textTertiary : c.success, fontWeight: FontWeight.w600));
  }
}

/// 43 Video player (premium).
class VideoPlayerPage extends StatelessWidget {
  const VideoPlayerPage({super.key});
  @override
  Widget build(BuildContext context) {
    final args = _args();
    final engine = Get.find<VideoEngineFactory>()();
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
              const SizedBox(height: 16),
              if (ctrl.togetherRx.value != null) Text('${ctrl.togetherRx.value!.people} people in this session now', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
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
    final engine = Get.find<YoutubeEngineFactory>()();
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
