import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditation/core/audio/audio_engine.dart';
import 'package:meditation/core/audio/recipe_engine.dart';
import 'package:meditation/core/audio/recipe_plan.dart';
import 'package:meditation/core/data/models/activity.dart';
import 'package:meditation/core/data/models/content.dart';

const blocks = [
  SoundBlock(id: 'open', kind: 'opening', name: 'Gentle opening', durationSec: 60),
  SoundBlock(id: 'rain', kind: 'sound', name: 'Soft rain', durationSec: 600, loopable: true),
  SoundBlock(id: 'om', kind: 'mantra', name: 'OM', durationSec: 12, loopable: true),
  SoundBlock(id: 'voice', kind: 'voice', name: 'Body scan', durationSec: 90),
];
const catalog = Catalog(version: 1, soundBlocks: blocks);

Recipe recipe({int len = 15, String? opening, String? sound, int level = 50, RecipeBells bells = const RecipeBells(start: true, end: true), List<Map<String, dynamic>> bl = const []}) =>
    Recipe(id: 'r', name: 'n', lengthMin: len, openingId: opening, soundId: sound, soundLevel: level, bells: bells, blocks: bl);

class FakeClips implements ClipPlayer {
  FakeClips(this.log, this.name);
  final List<String> log;
  final String name;
  @override
  Future<void> play(String url, {double volume = 1, bool loop = false}) async => log.add('${clock.now().difference(t0).inMilliseconds}:$name:$url${loop ? ':loop' : ''}:v$volume');
  @override
  Future<void> stop() async => log.add('${clock.now().difference(t0).inMilliseconds}:$name:stop');
  @override
  Future<void> pause() async => log.add('${clock.now().difference(t0).inMilliseconds}:$name:pause');
  @override
  Future<void> resume() async {}
  @override
  Future<void> dispose() async {}
}

late DateTime t0;

void main() {
  group('RecipePlan', () {
    test('simple recipe: opening, silence for the rest, background sound level, bells start/end/interval', () {
      final p = RecipePlan.build(recipe(len: 15, opening: 'open', sound: 'rain', level: 70, bells: const RecipeBells(start: true, end: true, intervalMin: 5)), catalog);
      expect(p.totalSec, 900);
      expect(p.clips.single.blockId, 'open');
      expect(p.clips.single.startSec, 0);
      expect(p.voiceSec, 60);
      expect(p.silenceSec, 840);
      expect(p.soundId, 'rain');
      expect(p.soundVolume, .7);
      expect(p.bellsAt, [0, 300, 600, 900]);
      expect(p.blockIds, {'open', 'rain'});
    });

    test('advanced: blocks are looped by their counts, silence entries share the leftover time', () {
      final p = RecipePlan.build(
          recipe(len: 10, opening: 'open', bl: const [
            {'type': 'block', 'blockId': 'om', 'count': 7},
            {'type': 'silence'},
            {'type': 'block', 'blockId': 'voice', 'count': 1},
            {'type': 'silence'},
          ]),
          catalog);
      expect(p.totalSec, 600);
      // opening 60 s, then OM ×7 = 84 s
      expect(p.clips.take(8).map((c) => c.blockId), ['open', ...List.filled(7, 'om')]);
      expect(p.clips[1].startSec, 60);
      expect(p.clips[7].endSec, 60 + 84);
      // leftover = 600 − 60 − 84 − 90 = 366 → 183 s of silence before the voice block
      final voice = p.clips.last;
      expect(voice.blockId, 'voice');
      expect(voice.startSec, 144 + 183);
      expect(p.voiceSec, 60 + 84 + 90);
    });

    test('a clip that would run past the end is cut; a missing block is skipped; nothing is ever longer than the meditation', () {
      final p = RecipePlan.build(recipe(len: 5, bl: const [{'type': 'block', 'blockId': 'rain', 'count': 1}, {'type': 'block', 'blockId': 'gone', 'count': 3}]), catalog);
      expect(p.clips.single.durationSec, 300);
      expect(p.clips.single.endSec, 300);
      expect(p.silenceSec, 0);
    });

    test('summary line', () {
      expect(RecipePlan.summary(recipe(len: 15, opening: 'open', sound: 'rain'), catalog), '15 min · Gentle opening · Soft rain · bells');
      expect(RecipePlan.summary(recipe(len: 8, bells: const RecipeBells(start: false, end: false)), catalog), '8 min');
    });
  });

  group('RecipeEngine timeline', () {
    RecipeEngine make(List<String> log) => RecipeEngine(clipFactory: () => FakeClips(log, 'p'));

    test('exact length (±1 s): voice clips and bells fire on time, background sound loops, completion at the end', () {
      fakeAsync((fa) {
        t0 = clock.now();
        final log = <String>[];
        final e = make(log);
        final plan = RecipePlan.build(recipe(len: 2, opening: 'open', sound: 'rain', level: 40, bells: const RecipeBells(start: true, end: true)), catalog);
        final statuses = <EngineStatus>[];
        e.status.listen(statuses.add);
        e.open(RecipeSource(plan, {'open': 'u/open', 'rain': 'u/rain'}, bellUrl: 'u/bell'));
        fa.flushMicrotasks();
        e.play();
        fa.elapse(const Duration(milliseconds: 500));
        fa.flushMicrotasks();
        expect(log.any((l) => l.contains('u/rain:loop:v0.4')), true);
        expect(log.any((l) => l.contains('p:u/open')), true);
        expect(log.where((l) => l.contains('u/bell')).length, 1); // the start bell
        fa.elapse(const Duration(seconds: 118));
        expect(statuses.contains(EngineStatus.completed), false);
        fa.elapse(const Duration(seconds: 2));
        fa.flushMicrotasks();
        expect(statuses.last, EngineStatus.completed);
        expect(log.where((l) => l.contains('u/bell')).length, 2); // + the end bell
        expect(e.currentDuration, const Duration(seconds: 120));
      });
    });

    test('pause stops the clock, resume continues: total listening time stays exactly the meditation length', () {
      fakeAsync((fa) {
        t0 = clock.now();
        final e = make(<String>[]);
        final plan = RecipePlan.build(recipe(len: 2, bells: const RecipeBells(start: false, end: false)), catalog);
        var completedAt = -1;
        e.status.listen((s) {
          if (s == EngineStatus.completed) completedAt = clock.now().difference(t0).inSeconds;
        });
        e.open(RecipeSource(plan, const {}));
        fa.flushMicrotasks();
        e.play();
        fa.elapse(const Duration(seconds: 50));
        e.pause();
        fa.flushMicrotasks();
        expect(e.currentPosition.inSeconds, 50);
        fa.elapse(const Duration(seconds: 30)); // paused 30 s
        expect(e.currentPosition.inSeconds, 50);
        e.play();
        fa.elapse(const Duration(seconds: 71));
        fa.flushMicrotasks();
        expect(completedAt, inInclusiveRange(150, 151)); // 120 s of meditation + 30 s paused
      });
    });
  });
}
