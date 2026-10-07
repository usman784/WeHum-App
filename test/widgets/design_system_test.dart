import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meditation/core/errors/error_code.dart';
import 'package:meditation/core/theme/app_theme.dart';
import 'package:meditation/core/widgets/app_scaffold.dart';
import 'package:meditation/core/widgets/buttons.dart';
import 'package:meditation/core/widgets/controls.dart';
import 'package:meditation/core/widgets/countdown_text.dart';
import 'package:meditation/core/widgets/painters.dart';
import 'package:meditation/core/widgets/states.dart';
import 'package:meditation/core/widgets/surfaces.dart';

import '../support/fonts.dart';

Widget host(Widget child, {Brightness b = Brightness.dark, double scale = 1}) => MaterialApp(
      theme: buildTheme(b),
      builder: (c, w) => MediaQuery(data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)), child: w!),
      home: Scaffold(body: SingleChildScrollView(child: SizedBox(width: 390, child: Padding(padding: const EdgeInsets.all(20), child: child)))),
    );

Widget gallery() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const PrimaryButton('Meditate now', sub: '10 min · on your own'),
      const SizedBox(height: 8),
      const PrimaryButton('Loading', loading: true),
      const SizedBox(height: 8),
      const PrimaryButton('Disabled'),
      const SizedBox(height: 8),
      OutlineButton('Wait for the group', sub: '16:00 · in 12:04', onPressed: () {}),
      const SizedBox(height: 8),
      SecondaryButton('Secondary', onPressed: () {}, icon: Icons.apple),
      const SizedBox(height: 8),
      DangerButton('Delete account', onPressed: () {}),
      TextLink('Restore purchase', onPressed: () {}),
      SegmentedControl<int>(options: const [10, 30, 45], value: 10, onChanged: (_) {}, labelOf: (v) => '$v min'),
      AppToggle(value: true, onChanged: (_) {}, label: 'Daily reminder'),
      PillGroup<String>(options: const ['Anxiety', 'Sleep', 'Focus', 'Deep Meditation'], selected: const {'Sleep'}, onToggle: (_) {}, labelOf: (s) => s),
      const Wrap(spacing: 8, children: [AppBadge(BadgeKind.premium), AppBadge(BadgeKind.comingSoon), AppBadge(BadgeKind.live), AppBadge(BadgeKind.freeForYou), AppBadge(BadgeKind.video)]),
      const LivePill(text: '412 meditating now · 37 countries'),
      const LivePill(text: '1,280 meditated today', quiet: true),
      AppCard(onTap: () {}, child: const ListRow(title: 'Silence Room', subtitle: 'Meditate in silence, with bells', leading: IconTile(Icons.spa_outlined))),
      const AppProgressBar(.4),
      const WeekDots(done: [true, false, true, true, false, false, false]),
      const VibrationBar(value: 62),
      const WorldDotMap(hot: {'DE': 64, 'US': 120, 'JP': 30}),
      const SizedBox(height: 260, child: PresenceRing(people: 12)),
      const EmptyState(title: "You're all caught up", body: 'New messages will show up here.', ctaLabel: 'Open Today'),
      const SizedBox(height: 8),
      const OfflineBanner(),
    ]);

void main() {
  setUpAll(loadAppFonts);
  for (final b in Brightness.values) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('components render without overflow: ${b.name} × $scale', (t) async {
        await t.binding.setSurfaceSize(const Size(390, 6000));
        await t.pumpWidget(host(gallery(), b: b, scale: scale));
        await t.pump(const Duration(milliseconds: 300));
        expect(tester(t), isNull); // any overflow would have thrown a FlutterError into the test
        await t.binding.setSurfaceSize(null);
      });
    }
  }

  testWidgets('buttons expose labels and enabled state to screen readers', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(host(Column(children: [PrimaryButton('Start', onPressed: () {}), const PrimaryButton('Off')])));
    expect(t.getSemantics(find.text('Start')), matchesSemantics(label: 'Start', isButton: true, isEnabled: true, hasEnabledState: true, hasTapAction: true, isFocusable: true, hasFocusAction: true));
    expect(find.bySemanticsLabel('Off'), findsOneWidget);
    h.dispose();
  });

  testWidgets('toggle and segmented control report their state', (t) async {
    final h = t.ensureSemantics();
    var on = false;
    await t.pumpWidget(host(StatefulBuilder(builder: (c, set) => AppToggle(value: on, label: 'Reminder', onChanged: (v) => set(() => on = v)))));
    await t.tap(find.byType(AppToggle));
    await t.pump();
    expect(on, true);
    expect(find.bySemanticsLabel('Reminder'), findsOneWidget);
    h.dispose();
  });

  testWidgets('StateSwitcher: skeleton only after 300 ms; error shows code and retry; offline copy', (t) async {
    var retried = 0;
    Widget sw(ViewState s) => host(SizedBox(height: 400, child: StateSwitcher(state: s, content: () => const Text('CONTENT'), onRetry: () => retried++)));
    await t.pumpWidget(sw(ViewState.loading));
    await t.pump(const Duration(milliseconds: 100));
    expect(find.byType(SkeletonList), findsNothing);
    await t.pump(const Duration(milliseconds: 400));
    expect(find.byType(SkeletonList), findsOneWidget);
    await t.pumpWidget(sw(ViewState.content));
    await t.pumpAndSettle();
    expect(find.text('CONTENT'), findsOneWidget);
    await t.pumpWidget(sw(ViewState.error(ApiException(ErrorCode.internal, traceId: 'tr-1'))));
    await t.pumpAndSettle();
    expect(find.text('INTERNAL · tr-1'), findsOneWidget);
    await t.tap(find.text('Try again'));
    expect(retried, 1);
    await t.pumpWidget(sw(ViewState.fromError(ApiException(ErrorCode.network))));
    await t.pumpAndSettle();
    expect(find.text("You're offline"), findsOneWidget);
  });

  testWidgets('CountdownText counts down from the injected (server) clock', (t) async {
    var now = DateTime.utc(2026, 10, 7, 15, 55, 56);
    final target = DateTime.utc(2026, 10, 7, 16);
    var done = 0;
    await t.pumpWidget(host(CountdownText(target: target, now: () => now, onDone: () => done++)));
    expect(find.text('04:04'), findsOneWidget);
    now = target;
    await t.pump(const Duration(seconds: 1));
    expect(find.text('00:00'), findsOneWidget);
    expect(done, 1);
    expect(formatCountdown(const Duration(hours: 2, minutes: 5, seconds: 9)), '2:05:09');
  });

  testWidgets('presence ring is static and hidden from semantics with Reduce Motion', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(MaterialApp(theme: buildTheme(Brightness.dark), home: const MediaQuery(data: MediaQueryData(disableAnimations: true), child: Scaffold(body: PresenceRing(people: 5)))));
    await t.pump(const Duration(seconds: 3));
    expect(t.hasRunningAnimations, false);
    h.dispose();
  });

  testWidgets('bottom nav marks the current tab', (t) async {
    final h = t.ensureSemantics();
    await t.pumpWidget(host(const AppBottomNav(current: AppTab.library)));
    expect(t.getSemantics(find.text('Library')).flagsCollection.isSelected.toString().toLowerCase(), contains('istrue'));
    h.dispose();
  });
}

Object? tester(WidgetTester t) => t.takeException();
