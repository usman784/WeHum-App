import 'package:flutter_test/flutter_test.dart';
import 'package:meditation/core/realtime/socket_events.dart';

void main() {
  test('the map gets live countries plus the countries that meditated today; an old server without todayTop still works', () {
    final a = LiveAgg.fromJson({
      'total': 3, 'countries': 2, 'quiet': true, 'meditatedToday': 12, 'vibration': 40, 'at': 1,
      'top': [{'c': 'DE', 'n': 2}, {'c': 'US', 'n': 1}],
      'todayTop': [{'c': 'PK', 'n': 5}, {'c': 'DE', 'n': 4}],
    });
    expect(a.where, {'PK': 5, 'DE': 6, 'US': 1});
    final old = LiveAgg.fromJson({'total': 0, 'countries': 0, 'quiet': true, 'meditatedToday': 0, 'vibration': 0, 'at': 1, 'top': []});
    expect(old.where, isEmpty);
  });
}
