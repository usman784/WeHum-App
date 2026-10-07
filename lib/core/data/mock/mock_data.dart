import '../models/activity.dart';
import '../models/content.dart';
import '../models/today.dart';

/// Demo content in the shape of backend spec §5.4 (spec §0 rule 6).
abstract final class MockData {
  static const _img = 'assets/images';
  static Cover cover(String name) => Cover(url: '$_img/$name.jpg');

  static final themes = <ThemeInfo>[
    const ThemeInfo(id: 't-anx', slug: 'anxiety', name: 'Anxiety & Stress', subtitle: 'Calm the noise', iconKey: 'wind', order: 1),
    const ThemeInfo(id: 't-slp', slug: 'sleep', name: 'Sleep', subtitle: 'Rest deeply', iconKey: 'moon', order: 2),
    const ThemeInfo(id: 't-foc', slug: 'focus', name: 'Focus', subtitle: 'Steady attention', iconKey: 'target', order: 3),
    const ThemeInfo(id: 't-deep', slug: 'deep', name: 'Deep Meditation', subtitle: 'Go further', iconKey: 'waves', order: 4),
  ];

  static final raphael = const Teacher(
    id: 'tc-raphael', name: 'Raphael Reiter', role: 'Meditation teacher', specialty: 'Breath, stillness, presence',
    bio: 'Raphael teaches meditation to millions on YouTube. WeHum is where you never meditate alone.', quote: 'Training, not therapy.',
    photoUrl: '$_img/seated.jpg', youtubeUrl: 'https://youtube.com', instagramUrl: 'https://instagram.com', websiteUrl: 'https://wehum.app');

  static final sessions = <SessionSummary>[
    SessionSummary(id: 's-motd', slug: 'steady-under-pressure', title: 'Steady Under Pressure', description: 'A grounding meditation for busy days.', type: 'audio', access: Access.premium, themeId: 't-anx', teacherId: 'tc-raphael', durationSec: 600, cover: cover('ocean'), downloadable: true, tags: const ['stress', 'grounding']),
    SessionSummary(id: 's-sleep', slug: 'sink-into-sleep', title: 'Sink Into Sleep', description: 'Let the day dissolve.', type: 'audio', access: Access.premium, themeId: 't-slp', teacherId: 'tc-raphael', durationSec: 1500, cover: cover('night'), downloadable: true, tags: const ['sleep']),
    SessionSummary(id: 's-focus', slug: 'one-point-focus', title: 'One-Point Focus', description: 'Train a steady mind.', type: 'video', access: Access.premium, themeId: 't-foc', teacherId: 'tc-raphael', durationSec: 900, cover: cover('forest'), tags: const ['focus']),
    SessionSummary(id: 's-deep', slug: 'the-long-sit', title: 'The Long Meditation', description: 'Forty minutes of depth.', type: 'audio', access: Access.premium, themeId: 't-deep', teacherId: 'tc-raphael', durationSec: 2400, cover: cover('dunes'), downloadable: true, tags: const ['deep']),
    SessionSummary(id: 's-free1', slug: 'breathing-reset', title: 'Breathing Reset', description: 'From Raphael\'s online library.', type: 'youtube', access: Access.free, themeId: 't-anx', teacherId: 'tc-raphael', durationSec: 480, cover: cover('lake'), youtubeId: 'dQw4w9WgXcQ'),
    SessionSummary(id: 's-free2', slug: 'morning-clarity', title: 'Morning Clarity', description: 'Start the day clear.', type: 'youtube', access: Access.free, themeId: 't-foc', teacherId: 'tc-raphael', durationSec: 600, cover: cover('dawn'), youtubeId: 'dQw4w9WgXcQ'),
    SessionSummary(id: 's-sos1', slug: 'sos-panic', title: 'When it feels like too much', type: 'audio', access: Access.premium, durationSec: 300, cover: cover('rain')),
  ];

  static final catalog = Catalog(
    version: 1, themes: themes, teachers: [raphael], sessions: sessions.where((s) => !s.id.startsWith('s-sos')).toList(),
    programs: [
      Program(id: 'p-7', slug: 'autonomic-reset', title: '7-Day Autonomic Reset', description: 'Seven days to settle your nervous system.', access: Access.premium, cover: cover('aurora'), days: [
        for (var i = 1; i <= 7; i++) ProgramDay(day: i, title: 'Day $i', sessionId: 's-motd', session: sessions.first),
      ]),
    ],
    soundBlocks: const [
      SoundBlock(id: 'b-open', kind: 'opening', name: 'Gentle opening', durationSec: 60, access: Access.premium),
      SoundBlock(id: 'b-rain', kind: 'sound', name: 'Soft rain', durationSec: 600, loopable: true, access: Access.premium),
      SoundBlock(id: 'b-om', kind: 'mantra', name: 'OM', durationSec: 12, loopable: true, access: Access.premium),
    ],
    sos: SosInfo(title: 'How can I help?', subtitle: 'Choose what is closest to how you feel.', help: const {
      'title': 'Need more help?', 'body': 'You can contact us and book a personal session with Raphael.', 'ctaLabel': 'Contact us', 'url': 'https://wehum.app/contact',
    }, tiles: [
      for (final f in ['Anxious', 'Overwhelmed', 'Sad', 'Angry', 'Restless', 'Lonely', 'Can\'t sleep', 'Numb'])
        SosTile(sessionId: 's-sos1', feeling: f, subtitle: '5 min', durationSec: 300, cover: cover('rain')),
    ]),
  );

  static MotdInfo motd(String date) => MotdInfo(date: date, sessionId: 's-motd', title: 'Steady Under Pressure', teacher: 'Raphael', theme: 'Anxiety & Stress', cover: cover('ocean'), lengths: const [10, 30, 45], practicedToday: 1280);

  static GroupInfo group(String date) {
    final starts = DateTime.now().toUtc().add(const Duration(minutes: 12));
    return GroupInfo(
        date: date, startsAt: starts, endsAt: starts.add(const Duration(minutes: 30)), lobbyOpensAt: starts.subtract(const Duration(minutes: 3)),
        lengthMin: 30, state: GroupPhase.scheduled, waiting: 120, sessionId: 's-motd', title: 'Steady Under Pressure');
  }

  static TodayData today(String date, {required bool member}) => TodayData(
        date: date, motd: motd(date), live: const LiveLine(total: 412, countries: 37, quiet: false, meditatedToday: 1280), group: group(date),
        freePick: member ? null : const FreePick(sessionId: 's-free1', title: 'Breathing Reset', youtubeId: 'dQw4w9WgXcQ', durationSec: 480),
        program: member ? const ProgramCard(id: 'p-7', title: '7-Day Autonomic Reset', day: 4, days: 7) : null,
        progress: const WeekProgress(minutes: 105, meditations: 7, daysThisWeek: [true, true, false, true, true, false, false]),
        dailyMessage: member ? DailyMessageRef(date: date, title: 'Releasing Cognitive Friction', type: 'audio') : null);

  static final dedications = <Dedication>[
    Dedication(id: 'd1', firstName: 'Lena', country: 'DE', text: 'For my mother, who is unwell.', holdingCount: 14, createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 3))),
    Dedication(id: 'd2', firstName: 'Marcus', country: 'US', text: 'For everyone starting a hard week.', holdingCount: 6, createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 9))),
    Dedication(id: 'd3', firstName: 'Aiko', country: 'JP', text: 'Peace for my town.', holdingCount: 31, createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 20))),
  ];

  static ProgressData progress(Period p) => ProgressData(
        period: p, minutes: 105, meditations: 7, together: 3, average: 15, daysMeditated: 4, daysThisWeek: const [true, true, false, true, true, false, false],
        bars: [for (final (i, l) in ['M', 'T', 'W', 'T', 'F', 'S', 'S'].indexed) ProgressBar(label: l, minutes: [20, 15, 0, 30, 40, 0, 0][i], current: i == 4)]);
}
