/// Small helpers so model parsing stays short and never throws on a missing optional field.
typedef Json = Map<String, dynamic>;

Json asJson(Object? v) => (v is Map) ? v.cast<String, dynamic>() : <String, dynamic>{};
List<Json> asJsonList(Object? v) => (v is List) ? [for (final e in v) asJson(e)] : const [];
int asInt(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;
/// `[{c: 'PK', n: 2}, …]` → records; malformed rows are skipped.
List<({String country, int n})> countryCounts(Object? v) => [
      for (final t in (v is List ? v : const []))
        if (t is Map && t['c'] is String) (country: t['c'] as String, n: asInt(t['n'])),
    ];

String? asStr(Object? v) => v is String ? v : null;
DateTime? asDate(Object? v) => v is String ? DateTime.tryParse(v)?.toUtc() : null;
