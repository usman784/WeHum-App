import 'dart:math';

final _rng = Random.secure();

/// UUID v7 (time-ordered): 48-bit unix ms + 74 random bits. Meditation ids sort by time and are idempotent keys.
String uuid7([DateTime? now]) {
  final ms = (now ?? DateTime.now()).millisecondsSinceEpoch;
  final b = List<int>.generate(16, (_) => _rng.nextInt(256));
  b[0] = (ms >> 40) & 0xff;
  b[1] = (ms >> 32) & 0xff;
  b[2] = (ms >> 24) & 0xff;
  b[3] = (ms >> 16) & 0xff;
  b[4] = (ms >> 8) & 0xff;
  b[5] = ms & 0xff;
  b[6] = (b[6] & 0x0f) | 0x70;
  b[8] = (b[8] & 0x3f) | 0x80;
  String h(int i) => b[i].toRadixString(16).padLeft(2, '0');
  return '${h(0)}${h(1)}${h(2)}${h(3)}-${h(4)}${h(5)}-${h(6)}${h(7)}-${h(8)}${h(9)}-${h(10)}${h(11)}${h(12)}${h(13)}${h(14)}${h(15)}';
}
