import 'package:get/get.dart';

/// Server-synced clock (spec §6.3): group start and late-join seek use it, never the phone clock alone.
class TimeService extends GetxService {
  Duration offset = Duration.zero;

  /// Call with `bootstrap.serverTime` and later `time:sync` answers. [sentAt]/[receivedAt] halve the round trip.
  void sync(DateTime serverTime, {DateTime? sentAt, DateTime? receivedAt}) {
    final half = (sentAt != null && receivedAt != null) ? receivedAt.difference(sentAt) ~/ 2 : Duration.zero;
    offset = serverTime.add(half).difference(DateTime.now().toUtc());
  }

  DateTime now() => DateTime.now().toUtc().add(offset);
}
