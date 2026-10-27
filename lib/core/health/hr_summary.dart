import 'dart:math' as math;

/// Where a sit's heart-rate numbers came from.
enum HrSource { sensor, health }

class HrSample {
  const HrSample(this.at, this.bpm);
  final DateTime at;
  final int bpm;
}

/// The numbers of one sit. Only [avgBpm] and [deltaBpm] ever leave the phone (spec: summary numbers, not raw data);
/// the rest is for the payoff screen.
class HrSummary {
  const HrSummary({required this.avgBpm, this.deltaBpm, required this.minBpm, required this.maxBpm, this.hrvMs, this.trend = const [], required this.source, this.sourceName, this.sampleCount = 0});
  final int avgBpm, minBpm, maxBpm;
  /// Calm shift: the end of the sit minus the start (negative = the heart slowed down).
  final int? deltaBpm;
  /// Heart-rate variability in milliseconds (RMSSD from a chest strap, SDNN/RMSSD from Health), when known.
  final double? hrvMs;
  /// At most [HrSummary.maxPoints] values, evenly spread over the sit, for the sparkline.
  final List<double> trend;
  final HrSource source;
  final String? sourceName;
  final int sampleCount;

  static const maxPoints = 48;

  HrSummary withHrv(double? v) => HrSummary(avgBpm: avgBpm, deltaBpm: deltaBpm, minBpm: minBpm, maxBpm: maxBpm, hrvMs: v ?? hrvMs, trend: trend, source: source, sourceName: sourceName, sampleCount: sampleCount);
}

const _minBpm = 30, _maxBpm = 220;

/// Reduces the raw readings of a sit to [HrSummary]. Null when nothing usable. Pure: no clock, no I/O.
///
/// The shift compares the mean of the first third of the sit with the mean of the last third (by time), so one noisy
/// reading cannot decide it; it needs at least two readings spread over 90 seconds, otherwise only the average is kept.
HrSummary? summarizeSit(Iterable<HrSample> raw, {required HrSource source, String? sourceName, double? hrvMs}) {
  final s = raw.where((e) => e.bpm >= _minBpm && e.bpm <= _maxBpm).toList()..sort((a, b) => a.at.compareTo(b.at));
  if (s.isEmpty) return null;
  final avg = s.fold<int>(0, (a, e) => a + e.bpm) / s.length;
  var lo = s.first.bpm, hi = s.first.bpm;
  for (final e in s) {
    lo = math.min(lo, e.bpm);
    hi = math.max(hi, e.bpm);
  }
  final span = s.last.at.difference(s.first.at);
  int? delta;
  if (s.length >= 2 && span >= const Duration(seconds: 90)) {
    final third = Duration(microseconds: span.inMicroseconds ~/ 3);
    final head = s.where((e) => e.at.difference(s.first.at) <= third).toList();
    final tail = s.where((e) => s.last.at.difference(e.at) <= third).toList();
    if (head.isNotEmpty && tail.isNotEmpty) {
      double m(List<HrSample> l) => l.fold<int>(0, (a, e) => a + e.bpm) / l.length;
      delta = (m(tail) - m(head)).round().clamp(-60, 60);
    }
  }
  return HrSummary(avgBpm: avg.round(), deltaBpm: delta, minBpm: lo, maxBpm: hi, hrvMs: hrvMs, trend: _bucket(s, HrSummary.maxPoints), source: source, sourceName: sourceName, sampleCount: s.length);
}

/// Evenly spaced means over time (not over index, so a burst of readings does not dominate).
List<double> _bucket(List<HrSample> s, int n) {
  if (s.length <= 1) return [for (final e in s) e.bpm.toDouble()];
  final t0 = s.first.at.microsecondsSinceEpoch, total = s.last.at.microsecondsSinceEpoch - t0;
  if (total <= 0) return [s.fold<int>(0, (a, e) => a + e.bpm) / s.length];
  final k = math.min(n, s.length);
  final sums = List<double>.filled(k, 0), counts = List<int>.filled(k, 0);
  for (final e in s) {
    final i = math.min(k - 1, ((e.at.microsecondsSinceEpoch - t0) * k ~/ (total + 1)));
    sums[i] += e.bpm;
    counts[i]++;
  }
  final out = <double>[];
  double? last;
  for (var i = 0; i < k; i++) {
    if (counts[i] > 0) last = sums[i] / counts[i];
    if (last != null) out.add(last); // a gap carries the previous value; leading gaps are dropped
  }
  return out;
}

/// One notification of the standard Heart Rate Measurement characteristic (0x2A37).
class HrReading {
  const HrReading(this.bpm, [this.rrMs = const []]);
  final int bpm;
  /// Beat-to-beat intervals carried by the packet, in milliseconds.
  final List<double> rrMs;
}

/// Bluetooth SIG Heart Rate Measurement. Null for a packet with no usable value (too short, or the strap says it has no skin contact).
HrReading? parseHeartRateMeasurement(List<int> d) {
  if (d.length < 2) return null;
  final flags = d[0];
  final wide = flags & 0x01 != 0; // 16-bit value
  final contactSupported = flags & 0x04 != 0, contact = flags & 0x02 != 0;
  if (contactSupported && !contact) return null;
  var i = 1;
  if (wide) {
    if (d.length < 3) return null;
    i = 3;
  } else {
    i = 2;
  }
  final bpm = wide ? d[1] | (d[2] << 8) : d[1];
  if (flags & 0x08 != 0) i += 2; // energy expended
  final rr = <double>[];
  if (flags & 0x10 != 0) {
    for (; i + 1 < d.length; i += 2) {
      rr.add((d[i] | (d[i + 1] << 8)) * 1000 / 1024); // units of 1/1024 s
    }
  }
  if (bpm < _minBpm || bpm > _maxBpm) return null;
  return HrReading(bpm, rr);
}

/// RMSSD of beat-to-beat intervals in ms. Intervals outside 300–2000 ms and jumps over 200 ms between neighbours are
/// treated as artefacts. Null with fewer than 20 clean differences (not enough for a meaningful number).
double? rmssd(List<double> rrMs) {
  final rr = rrMs.where((e) => e >= 300 && e <= 2000).toList();
  var sum = 0.0, n = 0;
  for (var i = 1; i < rr.length; i++) {
    final d = rr[i] - rr[i - 1];
    if (d.abs() > 200) continue;
    sum += d * d;
    n++;
  }
  return n < 20 ? null : math.sqrt(sum / n);
}
