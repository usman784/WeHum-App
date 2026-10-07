import 'session.dart';

/// `GET /v1/bootstrap` (backend spec §5.4). Unknown keys are kept in [raw] so new server fields never break the app.
class Bootstrap {
  const Bootstrap({
    required this.serverTime,
    required this.updateRequired,
    required this.maintenance,
    required this.features,
    required this.catalogVersion,
    required this.me,
    required this.raw,
  });

  final DateTime serverTime;
  final bool updateRequired;
  final bool maintenance;
  final Map<String, bool> features;
  final int catalogVersion;
  final Me? me;
  final Map<String, dynamic> raw;

  bool feature(String key) => features[key] ?? false;

  factory Bootstrap.fromJson(Map<String, dynamic> j) => Bootstrap(
        serverTime: DateTime.fromMillisecondsSinceEpoch((j['serverTime'] as num).toInt(), isUtc: true),
        updateRequired: j['updateRequired'] as bool? ?? false,
        maintenance: j['maintenance'] as bool? ?? false,
        features: {for (final e in ((j['features'] as Map?) ?? const {}).entries) e.key as String: e.value == true},
        catalogVersion: (j['catalogVersion'] as num?)?.toInt() ?? 0,
        me: j['me'] is Map ? Me.fromJson((j['me'] as Map).cast<String, dynamic>()) : null,
        raw: j,
      );
}
