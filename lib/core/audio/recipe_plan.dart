import '../data/models/activity.dart';
import '../data/models/content.dart';

/// One piece of recorded audio on the timeline.
class PlanClip {
  const PlanClip({required this.startSec, required this.blockId, required this.durationSec, this.label = ''});
  final int startSec;
  final String blockId;
  final int durationSec;
  final String label;
  int get endSec => startSec + durationSec;
}

/// The whole "Build your own" meditation as a timeline (spec §13): opening → blocks (looped by their counts) →
/// silence filling the rest → exact total length (±1 s). Background sound runs underneath; bells fire at fixed seconds.
class RecipePlan {
  const RecipePlan({required this.totalSec, required this.clips, required this.bellsAt, this.soundId, this.soundVolume = .5, this.soundLoopSec});
  final int totalSec;
  final List<PlanClip> clips;
  final List<int> bellsAt;
  final String? soundId;
  final double soundVolume;
  final int? soundLoopSec;

  /// Seconds of the timeline that have recorded audio on them.
  int get voiceSec => clips.fold(0, (s, c) => s + c.durationSec);
  int get silenceSec => totalSec - voiceSec;
  Set<String> get blockIds => {for (final c in clips) c.blockId, if (soundId != null) soundId!};

  /// Summary line for the builder: "15 min · Gentle opening · Soft rain · bells".
  static String summary(Recipe r, Catalog? c) {
    final parts = <String>['${r.lengthMin} min'];
    final o = r.openingId == null ? null : c?.soundBlocks.where((b) => b.id == r.openingId).firstOrNull;
    if (o != null) parts.add(o.name);
    final s = r.soundId == null ? null : c?.soundBlocks.where((b) => b.id == r.soundId).firstOrNull;
    if (s != null) parts.add(s.name);
    if (r.bells.start || r.bells.end || r.bells.intervalMin > 0) parts.add('bells');
    return parts.join(' · ');
  }

  /// Builds the plan. Block lengths come from the catalog; a block that is not in the catalog is skipped (the builder
  /// disables options whose sound is missing, spec §12 #39). Never longer than [Recipe.lengthMin].
  static RecipePlan build(Recipe r, Catalog catalog) {
    final total = r.lengthMin * 60;
    final byId = {for (final b in catalog.soundBlocks) b.id: b};
    final clips = <PlanClip>[];
    var cursor = 0;

    void add(String id, {int times = 1}) {
      final b = byId[id];
      final d = b?.durationSec;
      if (b == null || d == null || d <= 0) return;
      for (var i = 0; i < times; i++) {
        if (cursor >= total) return;
        final dur = (cursor + d > total) ? total - cursor : d; // the last clip is cut at the end of the meditation
        clips.add(PlanClip(startSec: cursor, blockId: id, durationSec: dur, label: b.name));
        cursor += dur;
      }
    }

    if (r.openingId != null) add(r.openingId!);

    // advanced: recorded blocks in order; each silence entry takes an equal share of what is left
    final entries = r.blocks;
    final recordedSec = entries.fold<int>(0, (s, e) {
      if (e['type'] != 'block') return s;
      final d = byId[e['blockId']]?.durationSec ?? 0;
      return s + d * ((e['count'] as num?)?.toInt() ?? 1);
    });
    final silences = entries.where((e) => e['type'] == 'silence').length;
    final leftover = (total - cursor - recordedSec).clamp(0, total);
    final gap = silences == 0 ? 0 : leftover ~/ silences;
    for (final e in entries) {
      if (e['type'] == 'silence') {
        cursor += gap;
      } else if (e['type'] == 'block') {
        add(e['blockId'] as String, times: ((e['count'] as num?)?.toInt() ?? 1).clamp(1, 21));
      }
    }

    final bells = <int>{};
    if (r.bells.start) bells.add(0);
    if (r.bells.end) bells.add(total);
    if (r.bells.intervalMin > 0) {
      for (var t = r.bells.intervalMin * 60; t < total; t += r.bells.intervalMin * 60) {
        bells.add(t);
      }
    }

    final sound = r.soundId == null ? null : byId[r.soundId];
    return RecipePlan(
      totalSec: total, clips: clips, bellsAt: bells.toList()..sort(), soundId: sound?.id, soundVolume: (r.soundLevel / 100).clamp(0.0, 1.0),
      soundLoopSec: sound?.durationSec);
  }
}
