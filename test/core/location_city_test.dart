import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:meditation/core/data/models/activity.dart';
import 'package:meditation/core/realtime/socket_events.dart';
import 'package:meditation/core/services/location_service.dart';

void main() {
  test('positions are rounded to 0.1° (~10 km) on the phone before anything is sent', () {
    expect(LocationService.round1(31.5204), 31.5);
    expect(LocationService.round1(74.3587), 74.4);
    expect(LocationService.round1(-33.8688), -33.9);
  });

  test('the city comes from the town, else the district, else the region; never empty or longer than 80', () {
    expect(LocationService.cityOf(const Placemark(locality: 'Lahore', subAdministrativeArea: 'Lahore District')), 'Lahore');
    expect(LocationService.cityOf(const Placemark(locality: ' ', subAdministrativeArea: 'Kasur District', administrativeArea: 'Punjab')), 'Kasur District');
    expect(LocationService.cityOf(const Placemark(administrativeArea: 'Punjab')), 'Punjab');
    expect(LocationService.cityOf(const Placemark()), isNull);
    expect(LocationService.cityOf(Placemark(locality: 'x' * 81)), isNull);
    expect(LocationService.cityOf(const Placemark(locality: 'A|B')), 'AB'); // the server key uses |
  });

  test('the profile reads the city', () {
    expect(MeProfile.fromJson({'id': 'u', 'city': 'Lahore', 'country': 'PK'}).city, 'Lahore');
    expect(MeProfile.fromJson({'id': 'u'}).city, isNull);
  });

  test('the live feed carries cities for the maps; an older server without them still parses', () {
    final a = LiveAgg.fromJson({'total': 9, 'countries': 2, 'quiet': false, 'meditatedToday': 9, 'vibration': 3, 'at': 1, 'top': [{'c': 'PK', 'n': 9}],
      'cities': [{'c': 'PK', 'name': 'Lahore', 'lat': 31.5, 'lng': 74.4, 'n': 4}]});
    expect(a.cities.single.name, 'Lahore');
    expect(a.cities.single.lat, 31.5);
    expect(a.cities.single.n, 4);
    expect(LiveAgg.fromJson({'total': 0, 'countries': 0, 'quiet': true, 'meditatedToday': 0, 'vibration': 0, 'at': 1}).cities, isEmpty);
  });
}
