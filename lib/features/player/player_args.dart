import '../../core/data/models/activity.dart';

/// What the player is asked to play. Typed arguments for `Get.toNamed(AppRoutes.playerPresenceRing, arguments: …)`.
class PlayerArgs {
  const PlayerArgs({
    required this.kind, required this.title, this.subtitle, this.sessionId, this.coverUrl, this.date, this.lengthMin, this.target, this.durationSec,
    this.startAt = Duration.zero, this.mode = 'solo', this.recipe, this.programId, this.programDay, this.isVideo = false, this.youtubeId, this.live = false, this.record = true,
  });

  /// motd | group | solo | silence | custom | program | sos | free  (the backend meditation `kind`)
  final String kind;
  final String title;
  final String? subtitle, sessionId, coverUrl, date, programId, youtubeId;
  final int? lengthMin, durationSec, programDay;
  /// What to request from `play-url`. Null for silence and YouTube.
  final PlayTarget? target;
  /// Late joiners of a group meditation start here (`now − T0`).
  final Duration startAt;
  /// solo | group | silence — the presence mode.
  final String mode;
  final Recipe? recipe;
  final bool isVideo, live;
  /// Whether finishing counts as a meditation (daily messages and previews do not).
  final bool record;

  PlayerArgs copyWith({Duration? startAt}) => PlayerArgs(
        kind: kind, title: title, subtitle: subtitle, sessionId: sessionId, coverUrl: coverUrl, date: date, lengthMin: lengthMin, target: target, durationSec: durationSec,
        startAt: startAt ?? this.startAt, mode: mode, recipe: recipe, programId: programId, programDay: programDay, isVideo: isVideo, youtubeId: youtubeId, live: live, record: record);
}
