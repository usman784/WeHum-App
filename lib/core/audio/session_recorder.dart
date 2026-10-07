import 'package:clock/clock.dart';
import '../data/models/activity.dart';
import '../utils/uuid7.dart';

/// Tracks how long someone really listened and decides — locally, for instant UI — whether it counts (spec §13):
/// ≥ 3 minutes, or ≥ 50 % of a session shorter than 6 minutes. The server makes the final call.
class SessionRecorder {
  SessionRecorder({required this.kind, this.sessionId, this.recipeId, this.lengthVariant, this.plannedSec, DateTime Function()? now}) : _now = now ?? (() => clock.now());
  final String kind;
  final String? sessionId, recipeId;
  final int? lengthVariant, plannedSec;
  final DateTime Function() _now;

  final String id = uuid7();
  DateTime? startedAt;
  DateTime? _playingSince;
  Duration _listened = Duration.zero;
  bool offline = false;

  bool get started => startedAt != null;

  void start() => startedAt ??= _now().toUtc();

  /// Playing started or resumed.
  void playing() {
    start();
    _playingSince ??= _now();
  }

  /// Paused, stalled or ended.
  void paused() {
    if (_playingSince != null) {
      _listened += _now().difference(_playingSince!);
      _playingSince = null;
    }
  }

  Duration get listened => _listened + (_playingSince == null ? Duration.zero : _now().difference(_playingSince!));

  bool get counts {
    final s = listened.inSeconds;
    final planned = plannedSec;
    return s >= 180 || (planned != null && planned <= 360 && planned > 0 && s >= planned * 0.5);
  }

  /// Percent of the planned length listened (for `meditation_abandon`).
  int get pct => plannedSec == null || plannedSec == 0 ? 0 : (listened.inSeconds * 100 / plannedSec!).clamp(0, 100).round();

  MeditationRecord? build({required bool completed}) {
    if (!started) return null;
    paused();
    final secs = _listened.inSeconds;
    if (secs < 1) return null;
    final end = _now().toUtc();
    return MeditationRecord(
      id: id, sessionId: sessionId, recipeId: recipeId, kind: kind, lengthVariant: lengthVariant, startedAt: startedAt!,
      endedAt: end.isAfter(startedAt!) ? end : startedAt!.add(Duration(seconds: secs)), durationSec: secs.clamp(1, 4 * 3600), completed: completed, offline: offline);
  }
}
