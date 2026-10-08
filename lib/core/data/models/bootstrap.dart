import 'session.dart';

/// `GET /v1/bootstrap` (backend spec §5.4). Unknown keys are kept in [raw] so new server fields never break the app.
class Bootstrap {
  const Bootstrap({
    required this.serverTime,
    required this.updateRequired,
    this.update = const AppUpdate(),
    required this.maintenance,
    required this.features,
    required this.catalogVersion,
    required this.me,
    required this.founding,
    required this.raw,
  });

  final DateTime serverTime;
  final bool updateRequired;
  final AppUpdate update;
  final bool maintenance;
  final Map<String, bool> features;
  final int catalogVersion;
  final Me? me;
  final Founding founding;
  final Map<String, dynamic> raw;

  bool feature(String key) => features[key] ?? false;

  factory Bootstrap.fromJson(Map<String, dynamic> j) => Bootstrap(
        serverTime: DateTime.fromMillisecondsSinceEpoch((j['serverTime'] as num).toInt(), isUtc: true),
        updateRequired: j['updateRequired'] as bool? ?? false,
        update: j['update'] is Map ? AppUpdate.fromJson((j['update'] as Map).cast<String, dynamic>()) : const AppUpdate(),
        maintenance: j['maintenance'] as bool? ?? false,
        features: {for (final e in ((j['features'] as Map?) ?? const {}).entries) e.key as String: e.value == true},
        catalogVersion: (j['catalogVersion'] as num?)?.toInt() ?? 0,
        me: j['me'] is Map ? Me.fromJson((j['me'] as Map).cast<String, dynamic>()) : null,
        founding: Founding.fromJson(j['founding'] is Map ? (j['founding'] as Map).cast<String, dynamic>() : const {}),
        raw: j,
      );
}

/// Founding 1,000 offer (`bootstrap.founding`); updates live through `config:changed`.
class Founding {
  const Founding({this.open = false, this.left = 0, this.cap = 0});
  final bool open;
  final int left, cap;
  factory Founding.fromJson(Map<String, dynamic> j) => Founding(open: j['open'] == true, left: (j['left'] as num?)?.toInt() ?? 0, cap: (j['cap'] as num?)?.toInt() ?? 0);
}

/// `bootstrap.update`: a newer build exists (`available`, can be dismissed) or this one is too old (`required`).
class AppUpdate {
  const AppUpdate({this.required = false, this.available = false, this.latest, this.storeUrl});
  final bool required, available;
  final String? latest, storeUrl;
  factory AppUpdate.fromJson(Map<String, dynamic> j) => AppUpdate(required: j['required'] == true, available: j['available'] == true, latest: j['latest'] as String?, storeUrl: j['storeUrl'] as String?);
}
