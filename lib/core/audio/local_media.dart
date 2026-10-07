import '../data/models/activity.dart';

/// Looks up downloaded media (P6). The player prefers a local file over the network.
abstract class LocalMedia {
  Future<String?> pathFor(PlayTarget target);
}

class NoLocalMedia implements LocalMedia {
  const NoLocalMedia();
  @override
  Future<String?> pathFor(PlayTarget target) async => null;
}
