import 'package:get/get.dart';
import '../../app/routes/app_routes.dart';
import '../../features/player/player_args.dart';
import '../data/models/activity.dart';
import '../data/models/content.dart';
import 'access_service.dart';

/// One place that decides what "Play" does for a session (spec §7.3): premium + not a member → paywall;
/// free YouTube item → free player; video → video player; audio → player. Signed URLs are only issued by the server.
String routeFor(SessionSummary s, {required bool member}) {
  if (s.isPremium && !member) return AppRoutes.membershipPaywall;
  if (s.isYoutube) return AppRoutes.freePlayer;
  if (s.isVideo) return AppRoutes.videoPlayer;
  return AppRoutes.playerPresenceRing;
}

PlayerArgs argsFor(SessionSummary s, {String kind = 'solo', String? subtitle, String? programId, int? programDay}) => PlayerArgs(
      kind: s.isYoutube ? 'free' : kind, title: s.title, subtitle: subtitle ?? 'Raphael', sessionId: s.id, coverUrl: s.cover?.url, durationSec: s.durationSec, lengthMin: s.minutes,
      target: s.isYoutube ? null : PlaySession(s.id), youtubeId: s.youtubeId, isVideo: s.isVideo, programId: programId, programDay: programDay);

void launchSession(SessionSummary s, {String kind = 'solo', String? programId, int? programDay}) {
  final member = Get.find<AccessService>().isMember;
  final route = routeFor(s, member: member);
  if (route == AppRoutes.membershipPaywall) {
    Get.toNamed(route, arguments: {'source': 'lock'});
    return;
  }
  Get.toNamed(route, arguments: argsFor(s, kind: kind, programId: programId, programDay: programDay));
}

void openSession(String id) => Get.toNamed('/session/$id', arguments: {'id': id});
