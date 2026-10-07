import 'package:get/get.dart';

/// Product analytics (spec §11.2): events are queued here and flushed in batches to `POST /v1/analytics/events` (P11).
class AnalyticsService extends GetxService {
  final _queue = <Map<String, Object?>>[];
  int get pending => _queue.length;

  void track(String name, [Map<String, Object?> params = const {}]) {
    _queue.add({'name': name, 'params': params, 'at': DateTime.now().toUtc().toIso8601String()});
    if (_queue.length > 500) _queue.removeAt(0);
  }

  List<Map<String, Object?>> drain() {
    final out = List<Map<String, Object?>>.of(_queue);
    _queue.clear();
    return out;
  }
}
