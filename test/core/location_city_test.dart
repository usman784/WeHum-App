import 'package:flutter_test/flutter_test.dart';
import 'package:geocoding/geocoding.dart';
import 'package:meditation/core/data/models/activity.dart';
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
}
