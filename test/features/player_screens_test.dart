import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/app/routes/app_routes.dart';
import 'package:meditation/core/audio/audio_engine.dart';
import 'package:meditation/core/data/models/activity.dart';
import 'package:meditation/core/services/sync_service.dart';
import 'package:meditation/features/dedications/controllers/dedications_controllers.dart';
import 'package:meditation/features/player/controllers/player_controller.dart';
import 'package:meditation/features/player/player_args.dart';

import '../support/test_env.dart';

Future<void> settle(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 600));
  await t.pump(const Duration(milliseconds: 600));
}

Future<void> afterPush(WidgetTester t) async {
  await t.pump();
  await t.pump(const Duration(milliseconds: 20));
}

const sid = '11111111-1111-4111-8111-111111111111';
PlayerArgs motd({String kind = 'motd', String mode = 'solo', Duration startAt = Duration.zero, bool live = false}) => PlayerArgs(
    kind: kind, mode: mode, title: 'Steady Under Pressure', subtitle: 'with Raphael', sessionId: sid, date: '2026-10-07', lengthMin: 10, target: const PlayMotd('2026-10-07', 10), durationSec: 600, startAt: startAt, live: live);

Future<TestEnv> openPlayer(WidgetTester t, PlayerArgs args, {bool member = true, String route = AppRoutes.playerPresenceRing}) async {
  phone(t);
  t.view.physicalSize = const Size(1170, 5600); // the whole player is built (with the dedications panel)
  final e = await TestEnv.create(member: member, onboardingDone: true);
  await e.socket.connect();
  e.socketServer.serverConnects();
  e.socketServer.acks['presence:start'] = (_) => {'ok': true, 'data': {'together': {'people': 412, 'countries': 37}}};
  e.me.profile = MeProfile(id: 'mock-user', firstName: 'Marcus', isGuest: false, entitlement: Entitlement(active: member)); // a member with an account
  await t.pumpWidget(e.app());
  await settle(t);
  Get.toNamed(route, arguments: args);
  await settle(t);
  return e;
}

void main() {
  testWidgets('42 player: title, ring numbers from presence ack, play/pause, ±15, presence over the socket', (t) async {
    final e = await openPlayer(t, motd());
    expect(find.text('Steady Under Pressure'), findsOneWidget);
    expect(find.text('with Raphael'), findsOneWidget);
    expect(find.text('412 synchronized worldwide'), findsOneWidget);
    expect(e.socketServer.sentData('presence:start').single, containsPair('mode', 'solo'));
    expect(e.engine.isPlaying, true);
    e.engine.tick(const Duration(minutes: 4, seconds: 12));
    await afterPush(t);
    expect(find.text('04:12'), findsWidgets); // the big clock and the scrubber
    expect(find.text('10:00'), findsOneWidget);
    await t.tap(find.byKey(const Key('play-pause')));
    await afterPush(t);
    expect(e.engine.isPlaying, false);
    await t.tap(find.byKey(const Key('fwd15')));
    await afterPush(t);
    expect(e.engine.seeks.last, const Duration(minutes: 4, seconds: 27));
    // session:live updates the ring line over the session room
    e.socketServer.serverPushes('session:live', {'sessionId': sid, 'people': 500, 'countries': 40});
    await afterPush(t);
    expect(find.text('500 synchronized worldwide'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    Get.delete<PlayerController>(tag: sid, force: true);
    await e.dispose();
  });

  testWidgets('42 player: no breathing labels (no inhale/exhale cue, no BPM); breath guidance belongs to Breathwork', (t) async {
    final e = await openPlayer(t, motd());
    e.engine.tick(const Duration(seconds: 3));
    await afterPush(t);
    expect(find.byKey(const Key('breath-cue')), findsNothing);
    expect(find.textContaining('INHALE'), findsNothing);
    expect(find.textContaining('EXHALE'), findsNothing);
    expect(find.textContaining('BPM'), findsNothing);
    await t.pumpWidget(const SizedBox());
    Get.delete<PlayerController>(tag: sid, force: true);
    await e.dispose();
  });

  testWidgets('43 video player: the progress bar can be touched and dragged too', (t) async {
    final e = await openPlayer(t, motd(), route: AppRoutes.videoPlayer);
    final bar = find.byKey(const Key('progress-scrub'));
    await t.scrollUntilVisible(bar, 300, scrollable: find.byType(Scrollable).first);
    expect(bar, findsOneWidget);
    final box = t.getRect(bar);
    await t.tapAt(Offset(box.left + box.width * .5, box.center.dy));
    await afterPush(t);
    expect(e.engine.seeks.last.inSeconds, inInclusiveRange(295, 305));
    await t.pumpWidget(const SizedBox());
    Get.delete<PlayerController>(tag: sid, force: true);
    await e.dispose();
  });

  testWidgets('42 player: touch and drag the progress bar to move through the meditation; not in a group (everyone stays together)', (t) async {
    final e = await openPlayer(t, motd());
    final bar = find.byKey(const Key('progress-scrub'));
    await t.scrollUntilVisible(bar, 300, scrollable: find.byType(Scrollable).first);
    expect(bar, findsOneWidget);
    final box = t.getRect(bar);
    // a tap at the middle of the bar jumps to the middle (10 min → 5:00)
    await t.tapAt(Offset(box.left + box.width * .5, box.center.dy));
    await afterPush(t);
    expect(e.engine.seeks.last.inSeconds, inInclusiveRange(295, 305));
    // dragging to 80 % seeks again, and the clock follows
    await t.dragFrom(Offset(box.left + box.width * .5, box.center.dy), Offset(box.width * .3, 0));
    await afterPush(t);
    expect(e.engine.seeks.last.inSeconds, inInclusiveRange(475, 485));
    expect(find.text('08:00'), findsWidgets);
    await t.pumpWidget(const SizedBox());
    Get.delete<PlayerController>(tag: sid, force: true);
    await e.dispose();

    final g = await openPlayer(t, motd(kind: 'group', mode: 'group', live: true));
    expect(find.byKey(const Key('progress-scrub')), findsNothing);
    await t.pumpWidget(const SizedBox());
    Get.delete<PlayerController>(tag: sid, force: true);
    await g.dispose();
  });

  testWidgets('42 player: one way back only (the Back arrow); no second down arrow that does the same', (t) async {
    final e = await openPlayer(t, motd());
    expect(find.byKey(const Key('minimize')), findsNothing);
    expect(find.bySemanticsLabel('Minimise'), findsNothing);
    expect(find.byIcon(Icons.keyboard_arrow_down_rounded), findsNothing);
    expect(find.byTooltip('Back'), findsOneWidget);
    await t.tap(find.byTooltip('Back'));
    await settle(t);
    expect(Get.currentRoute, isNot(AppRoutes.playerPresenceRing));
    await t.pumpWidget(const SizedBox());
    Get.delete<PlayerController>(tag: sid, force: true);
    await e.dispose();
  });

  testWidgets('42 player: the short description written in the CMS is shown in the meditation', (t) async {
    final e = await openPlayer(t, const PlayerArgs(kind: 'solo', title: 'Steady Under Pressure', sessionId: 's-motd', date: '2026-10-07', lengthMin: 10, target: PlayMotd('2026-10-07', 10), durationSec: 600));
    await t.scrollUntilVisible(find.byKey(const Key('session-about')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('A grounding meditation for busy days.'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    Get.delete<PlayerController>(tag: sid, force: true);
    await e.dispose();
  });

  testWidgets('42 player (solo too): the global presence heat map and where people are sitting; a quiet world shows the map without numbers', (t) async {
    final e = await openPlayer(t, motd(mode: 'solo'));
    await t.scrollUntilVisible(find.byKey(const Key('presence-card')), 300, scrollable: find.byType(Scrollable).first);
    expect(find.text('GLOBAL PRESENCE HEATMAP'), findsOneWidget);
    expect(find.text('EXPLORE MAP'), findsNothing); // leaving to a map would abandon the meditation
    // busy world: who is sitting where
    e.socketServer.serverPushes('live:agg', {'total': 412, 'countries': 37, 'top': [], 'quiet': false, 'meditatedToday': 900, 'vibration': 5, 'belts': {'americas': 120, 'emea': 200, 'apac': 92}, 'at': 1});
    await afterPush(t);
    expect(find.text('AMERICAS'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('EMEA'), findsOneWidget);
    expect(find.text('200'), findsOneWidget);
    expect(find.text('92'), findsOneWidget);
    // quiet world: the map stays, the small numbers do not
    e.socketServer.serverPushes('live:agg', {'total': 3, 'countries': 2, 'top': [], 'quiet': true, 'meditatedToday': 86, 'vibration': 5, 'belts': {'americas': 1, 'emea': 2, 'apac': 0}, 'at': 2});
    await afterPush(t);
    expect(find.byKey(const Key('presence-card')), findsOneWidget);
    expect(find.text('AMERICAS'), findsNothing);
    expect(find.textContaining('quiet'), findsWidgets);
    await t.pumpWidget(const SizedBox());
    Get.delete<PlayerController>(tag: sid, force: true);
    await e.dispose();
  });

  testWidgets('42 quiet rule: a quiet world is never presented as a crowd; paused socket shows no numbers', (t) async {
    final e = await openPlayer(t, motd());
    e.socketServer.serverPushes('live:agg', {'total': 3, 'countries': 2, 'top': [], 'quiet': true, 'meditatedToday': 86, 'vibration': 5, 'at': 1});
    await afterPush(t);
    expect(find.text('You’re meditating · 86 meditated today'), findsOneWidget);
    e.socketServer.serverDrops();
    await t.pump(const Duration(seconds: 11));
    expect(find.text('Live counts paused'), findsOneWidget);
    await t.pumpWidget(const SizedBox());
    Get.delete<PlayerController>(tag: sid, force: true);
    await e.dispose();
  });

  testWidgets('42 group mode: no skip buttons (everyone stays together), late join starts at the group position', (t) async {
    final e = await openPlayer(t, motd(kind: 'group', mode: 'group', startAt: const Duration(seconds: 97), live: true));
    expect(find.byKey(const Key('back15')), findsNothing);
    expect(find.byKey(const Key('fwd15')), findsNothing);
    expect(e.engine.opened.single.start, const Duration(seconds: 97));
    expect(e.socketServer.sentData('presence:start').single, containsPair('mode', 'group'));
    await t.pumpWidget(const SizedBox());
    Get.delete<PlayerController>(tag: sid, force: true);
    await e.dispose();
  });

  testWidgets('42 end before 3 minutes just goes back; nothing is recorded', (t) async {
    final e = await openPlayer(t, motd());
    await t.tap(find.byKey(const Key('end')));
    await settle(t);
    expect(Get.currentRoute, AppRoutes.todayMember); // back to where the meditation was started
    expect(e.meditations.recorded, isEmpty);
    expect(e.socketServer.count('presence:stop'), 1);
    await e.dispose();
  });

  testWidgets('42 → 45: finishing opens the payoff with minutes, together numbers and the dedicate card; outbox gets the meditation', (t) async {
    var now = DateTime.utc(2026, 10, 7, 8);
    await withClock(Clock(() => now), () async {
      final e = await openPlayer(t, motd());
      t.view.physicalSize = const Size(1170, 4800); // the whole payoff is built
      now = now.add(const Duration(minutes: 10));
      e.engine.setStatus(EngineStatus.completed);
      await settle(t);
      await settle(t);
      expect(Get.currentRoute, AppRoutes.meditationCompletePayoff);
      expect(find.text('You meditated 10 minutes.'), findsOneWidget);
      expect(find.text('Dedicate your meditation'), findsWidgets);
      expect(find.byKey(const Key('dedicate-btn')), findsOneWidget);
      await e.sync();
      expect(e.meditations.recorded.single.kind, 'motd');
      await settle(t);
      expect(find.text('You meditated with 412 people across 37 countries.'), findsOneWidget);
      expect(find.byKey(const Key('complete-streak')), findsOneWidget);
      expect(find.text('12-day streak · +1 today'), findsOneWidget);
      expect(find.textContaining('412 finished this meditation today'), findsOneWidget);
      await t.tap(find.byKey(const Key('send-kudos')));
      await settle(t);
      expect(find.text('Kudos sent'), findsOneWidget);
      expect(e.meditations.kudosSent, isNotEmpty);
      await t.scrollUntilVisible(find.byKey(const Key('complete-done')), 200, scrollable: find.byType(Scrollable).first);
      await t.tap(find.byKey(const Key('complete-done')));
      await settle(t);
      expect(Get.currentRoute, AppRoutes.todayMember);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });
  });

  testWidgets('45 payoff: a busy world shows the lit map with the Americas / EMEA / APAC counts, even when the numbers arrive after the player closed', (t) async {
    var now = DateTime.utc(2026, 10, 7, 8);
    await withClock(Clock(() => now), () async {
      final e = await openPlayer(t, motd());
      t.view.physicalSize = const Size(1170, 4800);
      now = now.add(const Duration(minutes: 10));
      e.engine.setStatus(EngineStatus.completed);
      await settle(t);
      await settle(t);
      expect(Get.currentRoute, AppRoutes.meditationCompletePayoff);
      // the server pushes the busy world while the payoff is on screen
      e.socketServer.serverPushes('live:agg', {
        'total': 82, 'countries': 18, 'quiet': false, 'meditatedToday': 300, 'vibration': 5, 'at': 9,
        'top': [{'c': 'US', 'n': 20}, {'c': 'DE', 'n': 12}, {'c': 'IN', 'n': 10}], 'todayTop': [{'c': 'BR', 'n': 8}],
        'belts': {'americas': 28, 'emea': 30, 'apac': 24},
      });
      await settle(t);
      expect(find.text('SYNCHRONOUS NETWORK'), findsOneWidget);
      expect(find.byKey(const Key('complete-belts')), findsOneWidget);
      expect(find.text('28'), findsOneWidget);
      expect(find.text('30'), findsOneWidget);
      expect(find.text('24'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await e.dispose();
    });
  });

  testWidgets('45 a guest sees this meditation only: no week, total or streak, and a note to create an account', (t) async {
    phone(t);
    t.view.physicalSize = const Size(1170, 4800); // the whole payoff is built
    final e = await TestEnv.create(onboardingDone: true); // the mock session is a guest
    final rec = MeditationRecord(id: 'm-g', kind: 'motd', sessionId: sid, startedAt: DateTime.utc(2026, 10, 7, 8), endedAt: DateTime.utc(2026, 10, 7, 8, 5), durationSec: 300, completed: true);
    await t.pumpWidget(e.app());
    await settle(t);
    Get.toNamed(AppRoutes.meditationCompletePayoff, arguments: CompleteArgs(player: motd(), record: rec, counted: true));
    await settle(t);
    await settle(t);
    expect(find.text('DURATION'), findsOneWidget);
    expect(find.byKey(const Key('complete-guest-note')), findsOneWidget);
    expect(find.text('THIS WEEK'), findsNothing);
    expect(find.text('TOTAL MIN'), findsNothing);
    expect(find.byKey(const Key('complete-streak')), findsNothing);
    await t.pumpWidget(const SizedBox());
    await e.dispose();
  });

  testWidgets('45 free listener sees the locked dedication card (Members can write dedications)', (t) async {
    phone(t);
    final e = await TestEnv.create(onboardingDone: true);
    final rec = MeditationRecord(id: 'm-1', kind: 'motd', sessionId: sid, startedAt: DateTime.utc(2026, 10, 7, 8), endedAt: DateTime.utc(2026, 10, 7, 8, 5), durationSec: 300, completed: true);
    await t.pumpWidget(e.app());
    await settle(t);
    Get.toNamed(AppRoutes.meditationCompletePayoff, arguments: CompleteArgs(player: motd(), record: rec, counted: true));
    await settle(t);
    await t.scrollUntilVisible(find.text('Members can write dedications. Anyone can read them.'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Members can write dedications. Anyone can read them.'), findsOneWidget);
    expect(find.byKey(const Key('dedicate-btn')), findsNothing);
    await e.dispose();
  });

  testWidgets('45 guest member sees "Add your name to post" (account gate)', (t) async {
    phone(t);
    final e = await TestEnv.create(member: true, onboardingDone: true);
    e.access.isGuest.value = true;
    final rec = MeditationRecord(id: 'm-2', kind: 'motd', sessionId: sid, startedAt: DateTime.utc(2026, 10, 7, 8), endedAt: DateTime.utc(2026, 10, 7, 8, 5), durationSec: 300, completed: true);
    await t.pumpWidget(e.app());
    await settle(t);
    Get.toNamed(AppRoutes.meditationCompletePayoff, arguments: CompleteArgs(player: motd(), record: rec, counted: true));
    await settle(t);
    await t.scrollUntilVisible(find.byKey(const Key('dedicate-gate')), 200, scrollable: find.byType(Scrollable).first);
    expect(find.byKey(const Key('dedicate-gate')), findsOneWidget);
    await e.dispose();
  });

  testWidgets('42 during the sit the dedications are there and a member can write one from the player', (t) async {
    final e = await openPlayer(t, motd());
    expect(find.byKey(const Key('dedications-panel')), findsOneWidget);
    expect(find.textContaining('For my mother, who is unwell.'), findsOneWidget);
    await t.ensureVisible(find.byKey(const Key('dedication-write')));
    await t.tap(find.byKey(const Key('dedication-write')));
    await settle(t);
    expect(find.byKey(const Key('dedication-field')), findsOneWidget);
    expect(Get.currentRoute, AppRoutes.playerPresenceRing); // the sheet opens over the player, the sit goes on
    await t.pumpWidget(const SizedBox());
    Get.delete<PlayerController>(tag: sid, force: true);
    await e.dispose();
  });

  group('47 composer', () {
    test('limits: 200 chars, no links, daily limit', () {
      Get.reset();
      final c = DedicationComposerController(meditationId: 'm', sessionId: sid, leftToday: 3);
      c.text.value = '   ';
      expect(c.valid, false);
      c.text.value = 'For my mother';
      expect(c.valid, true);
      c.text.value = 'a' * 201;
      expect(c.valid, false);
      expect(c.inlineError, 'At most 200 characters');
      for (final bad in ['see https://x.com', 'visit www.example.org', 'mail me @someone', 'my site foo.com', 'go to bit.ly now']) {
        c.text.value = bad;
        expect(c.valid, false, reason: bad);
        expect(c.inlineError, 'Text only, no links');
      }
      c.text.value = 'Peace for everyone.';
      c.left.value = 0;
      expect(c.valid, false);
      // at any time (details/player): no meditation and the limit not known yet: only the server checks it
      final any = DedicationComposerController(sessionId: sid)..text.value = 'For my sister';
      expect(any.valid, true);
      expect(any.inlineError, isNull);
    });
  });

  group('48 dedications (live)', () {
    Future<TestEnv> open(WidgetTester t) async {
      phone(t);
      final e = await TestEnv.create(member: true, onboardingDone: true);
      await e.socket.connect();
      e.socketServer.serverConnects();
      await t.pumpWidget(e.app());
      await settle(t);
      Get.toNamed('/dedications/$sid', arguments: {'sessionId': sid});
      await settle(t);
      return e;
    }

    testWidgets('lists dedications, joins session:{id}; a new dedication appears the moment the socket delivers it', (t) async {
      final e = await open(t);
      expect(find.text('3 dedications'), findsOneWidget);
      expect(find.textContaining('For my mother, who is unwell.'), findsOneWidget);
      expect(e.socket.rooms, contains('session:$sid'));
      e.socketServer.serverPushes('dedication:new', {'sessionId': sid, 'items': [{'id': 'd-new', 'firstName': 'Kofi', 'country': 'GH', 'text': 'For my village.', 'holdingCount': 0, 'holding': false, 'createdAt': DateTime.now().toUtc().toIso8601String()}]});
      await afterPush(t);
      expect(find.textContaining('For my village.'), findsOneWidget);
      expect(find.text('4 dedications'), findsOneWidget);
      // duplicates and other sessions are ignored
      e.socketServer.serverPushes('dedication:new', {'sessionId': sid, 'items': [{'id': 'd-new', 'firstName': 'Kofi', 'text': 'For my village.', 'createdAt': DateTime.now().toUtc().toIso8601String()}]});
      e.socketServer.serverPushes('dedication:new', {'sessionId': 'other', 'items': [{'id': 'zz', 'firstName': 'X', 'text': 'elsewhere', 'createdAt': DateTime.now().toUtc().toIso8601String()}]});
      await afterPush(t);
      expect(find.text('4 dedications'), findsOneWidget);
      expect(find.textContaining('elsewhere'), findsNothing);
      await t.pumpWidget(const SizedBox());
      Get.delete<DedicationsController>(tag: sid, force: true);
      expect(e.socketServer.count('room:leave'), greaterThan(0));
      await e.dispose();
    });

    testWidgets('holding counts update live; removal after moderation disappears; tapping hold is optimistic and debounced', (t) async {
      final e = await open(t);
      expect(find.text('Holding this · 14'), findsOneWidget);
      e.socketServer.serverPushes('dedication:holding', {'id': 'd1', 'holdingCount': 20});
      await afterPush(t);
      expect(find.text('Holding this · 20'), findsOneWidget);
      e.socketServer.serverPushes('dedication:removed', {'id': 'd2'});
      await afterPush(t);
      expect(find.textContaining('For everyone starting a hard week.'), findsNothing);
      await t.tap(find.byKey(const Key('hold-d3')));
      await t.tap(find.byKey(const Key('hold-d3')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 500));
      expect(e.community.held, isEmpty); // double tap = on, off → net off, one request
      await t.tap(find.byKey(const Key('hold-d3')));
      await t.pump(const Duration(milliseconds: 500));
      expect(e.community.held, contains('d3'));
      expect(find.text('Holding this · 32'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      Get.delete<DedicationsController>(tag: sid, force: true);
      await e.dispose();
    });

    testWidgets('report with reason and block removes the post and thanks you', (t) async {
      final e = await open(t);
      await t.tap(find.byTooltip('Report or block').first);
      await settle(t);
      expect(find.text('Report this dedication'), findsOneWidget);
      await t.tap(find.byKey(const Key('report-submit')));
      await settle(t);
      expect(find.text('Thanks, we’ll take a look'), findsOneWidget);
      expect(find.text('2 dedications'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      Get.delete<DedicationsController>(tag: sid, force: true);
      await e.dispose();
    });
  });
}

extension on TestEnv {
  Future<void> sync() => Get.find<SyncService>().flush();
}
