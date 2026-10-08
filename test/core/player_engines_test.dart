import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:meditation/core/audio/audio_engine.dart';

import '../player/fake_audio_engine.dart';

void main() {
  test('the four engine makers stay four after registration (aliases of one function type would collapse into the first)', () {
    Get.reset();
    final a = FakeAudioEngine(), r = FakeAudioEngine(), v = FakeAudioEngine(), y = FakeAudioEngine();
    Get.put<PlayerEngines>(PlayerEngines(audio: () => a, recipe: () => r, video: () => v, youtube: () => y));
    final e = Get.find<PlayerEngines>();
    expect(e.audio(), same(a));
    expect(e.recipe(), same(r));
    expect(e.video(), same(v));
    expect(e.youtube(), same(y));
    expect({e.audio(), e.recipe(), e.video(), e.youtube()}.length, 4);
    Get.reset();
  });
}
