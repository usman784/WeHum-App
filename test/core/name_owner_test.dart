import 'package:flutter_test/flutter_test.dart';
import 'package:meditation/core/services/onboarding_store.dart';

void main() {
  OnboardingStore store() => OnboardingStore(MemoryBox());

  test('first launch: the name typed in onboarding stays for the new guest (the server has none yet)', () {
    final s = store()..name = 'Usman';
    s.adoptName(userId: 'guest-1', serverName: null);
    expect(s.name, 'Usman');
    expect(s.nameOwner, 'guest-1');
  });

  test('same person: the server\'s name wins when it has one (edited on another phone)', () {
    final s = store()..name = 'Usman';
    s.adoptName(userId: 'u-1', serverName: null);
    s.adoptName(userId: 'u-1', serverName: 'Usman L.');
    expect(s.name, 'Usman L.');
    s.adoptName(userId: 'u-1', serverName: '');
    expect(s.name, 'Usman L.');
  });

  test('logging in as someone else shows their name, never the previous person\'s', () {
    final s = store()..name = 'Usman';
    s.adoptName(userId: 'u-1', serverName: 'Usman');
    s.adoptName(userId: 'u-demo', serverName: 'Demo');
    expect(s.name, 'Demo');
  });

  test('signing out to a new guest drops the old account\'s name', () {
    final s = store()..name = 'Usman';
    s.adoptName(userId: 'u-1', serverName: 'Usman');
    s.adoptName(userId: 'guest-2', serverName: null);
    expect(s.name, '');
    expect(s.nameOwner, 'guest-2');
  });

  test('an unknown person (offline start without an id) changes nothing', () {
    final s = store()..name = 'Usman';
    s.adoptName(userId: '', serverName: 'X');
    expect(s.name, 'Usman');
  });
}
