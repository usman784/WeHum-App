/// Small helpers so model parsing stays short and never throws on a missing optional field.
typedef Json = Map<String, dynamic>;

Json asJson(Object? v) => (v is Map) ? v.cast<String, dynamic>() : <String, dynamic>{};
List<Json> asJsonList(Object? v) => (v is List) ? [for (final e in v) asJson(e)] : const [];
int asInt(Object? v, [int d = 0]) => (v as num?)?.toInt() ?? d;
String? asStr(Object? v) => v is String ? v : null;
DateTime? asDate(Object? v) => v is String ? DateTime.tryParse(v)?.toUtc() : null;
