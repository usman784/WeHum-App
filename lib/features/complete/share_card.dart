import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/theme/app_text.dart';
import '../../core/widgets/painters.dart';
import '../../core/widgets/stitch.dart';

/// The looks a person can pick for the image. [world] needs a real shared moment (people + countries), so it is only
/// offered then (see [ShareStyle.available]); it stays last so the other positions never move.
enum ShareStyle {
  night('Night'), dawn('Dawn'), stats('Stats'), world('World');
  const ShareStyle(this.label);
  final String label;
  static List<ShareStyle> available({required bool together}) => [night, dawn, stats, if (together) world];
}

/// The image people post after a meditation (46): 9:16 story (360×640 → 1080×1920) or 1:1 post (360×360 → 1080×1080).
/// Night sky with ember and teal aurora glows, the minutes as the hero number inside a glowing ring, honest "together"
/// numbers only when it was a shared moment, glass stat chips and the dedication as a quote. Brand colours are fixed
/// (the image looks the same in light and dark mode).
class ShareCard extends StatelessWidget {
  const ShareCard({
    super.key, this.style = ShareStyle.night, required this.story, required this.minutes, required this.title, required this.date,
    this.togetherPeople = 0, this.togetherCountries = 0, this.hot = const {}, this.daysThisWeek = 0, this.streakDay, this.hrDelta, this.dedication,
  });
  final ShareStyle style;
  final bool story;
  final int minutes;
  final String title;
  final DateTime date;
  /// Shown only when more than one person meditated (never invented).
  final int togetherPeople, togetherCountries;
  final Map<String, int> hot;
  final int daysThisWeek;
  /// "Day N" chip when the streak is longer than one day.
  final int? streakDay;
  final int? hrDelta;
  final String? dedication;

  static const ember = Color(0xFFFF7A45), amber = Color(0xFFFFB27A), mint = Color(0xFF4ADE80), teal = Color(0xFF2DD4BF);

  bool get _together => togetherPeople > 1;

  bool get _light => style == ShareStyle.dawn;
  Color get _ink => _light ? const Color(0xFF2A1A12) : Colors.white;
  Color get _inkSoft => _light ? const Color(0xFF6B5547) : Colors.white70;

  @override
  Widget build(BuildContext context) {
    final h = story ? 640.0 : 360.0;
    final body = switch (style) {
      ShareStyle.night => story ? _storyBody() : _postBody(),
      ShareStyle.dawn => _dawnBody(),
      ShareStyle.stats => _statsBody(),
      ShareStyle.world => _worldBody(),
    };
    return SizedBox(
      width: 360, height: h,
      child: ClipRect(
        child: Stack(children: [
          Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: _light ? const [Color(0xFFFFF6EE), Color(0xFFFFE3D0), Color(0xFFFFC9A8)] : const [Color(0xFF0E2B2C), Color(0xFF0A0C0D), Color(0xFF1C100B)],
              stops: _light ? const [0, .5, 1] : const [0, .55, 1])))),
          if (!_light) Positioned.fill(child: CustomPaint(painter: _SkyPainter(story: story))),
          Positioned(top: story ? -90 : -110, right: -110, child: _Glow(color: ember, size: 300, alpha: _light ? .30 : .42)),
          Positioned(bottom: story ? 40 : -150, left: -130, child: _Glow(color: _light ? amber : teal, size: 320, alpha: _light ? .35 : .30)),
          if (story && !_light) const Positioned(top: 250, left: 80, child: _Glow(color: mint, size: 200, alpha: .10)),
          Positioned.fill(child: Padding(padding: EdgeInsets.fromLTRB(24, story ? 26 : 18, 24, story ? 24 : 16), child: body)),
        ]),
      ),
    );
  }

  Widget _header() => Row(children: [
        const BrandLogo(size: 24),
        const SizedBox(width: 8),
        Text('WeHum', style: AppText.navTitle.copyWith(color: _ink, fontSize: 16, letterSpacing: .2)),
        const Spacer(),
        _headerPill(),
      ]);

  /// "MEDITATION COMPLETE": frosted glass on the dark looks, a soft white pill with dark text on the light one (white text would vanish).
  Widget _headerPill() {
    final row = Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: const BoxDecoration(color: mint, shape: BoxShape.circle, boxShadow: [BoxShadow(color: mint, blurRadius: 6)])),
      const SizedBox(width: 6),
      Text('MEDITATION COMPLETE', style: AppText.overline.copyWith(color: _ink, fontSize: 9, letterSpacing: 1.1)),
    ]);
    if (!_light) return _Glass(radius: 99, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), child: row);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: .7), borderRadius: BorderRadius.circular(99), border: Border.all(color: _ink.withValues(alpha: .12), width: .8)),
      child: row,
    );
  }

  Widget _ring(double size) => SizedBox(
        width: size, height: size,
        child: CustomPaint(
          painter: _RingPainter(light: _light),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            ShaderMask(
              shaderCallback: (r) => LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: _light ? const [Color(0xFF2A1A12), Color(0xFF8A4A2B)] : const [Colors.white, Color(0xFFFFD9C7)]).createShader(r),
              child: Text('$minutes', key: const Key('share-minutes'), style: AppText.display.copyWith(color: Colors.white, fontSize: size * .36, height: 1, fontWeight: FontWeight.w700, fontFeatures: AppText.tabular)),
            ),
            const SizedBox(height: 2),
            Text(minutes == 1 ? 'MINUTE' : 'MINUTES', style: AppText.overline.copyWith(color: _light ? const Color(0xFFC2511F) : amber, fontSize: size * .058, letterSpacing: 2.4)),
          ])),
        ),
      );

  List<Widget> _chips() => [
        if (daysThisWeek > 0) _Chip(label: 'THIS WEEK', value: '$daysThisWeek ${daysThisWeek == 1 ? 'day' : 'days'}'),
        if (streakDay != null && streakDay! > 1) _Chip(key: const Key('share-streak'), label: 'STREAK', value: 'Day $streakDay', accent: true, icon: Icons.local_fire_department_rounded),
        if (hrDelta != null) _Chip(key: const Key('share-hr'), label: 'CALM SHIFT', value: '${hrDelta! > 0 ? '+' : ''}$hrDelta bpm', icon: Icons.favorite_rounded),
      ];

  Widget _chipRow(List<Widget> chips) => Row(children: [
        for (var i = 0; i < chips.length; i++) ...[if (i > 0) const SizedBox(width: 8), Expanded(child: chips[i])],
      ]);

  Widget _togetherPill() => _Glass(
        key: const Key('share-together'), radius: 99, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.public_rounded, size: 14, color: mint),
          const SizedBox(width: 6),
          Flexible(child: Text('Together with ${groupedInt(togetherPeople)} people · $togetherCountries ${togetherCountries == 1 ? 'country' : 'countries'}',
              maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 11.5))),
        ]),
      );

  Widget _quote({int lines = 3}) => _Glass(
        key: const Key('share-dedication'), radius: 16, padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('“', style: AppText.display.copyWith(color: ember, fontSize: 34, height: 1)),
          const SizedBox(width: 6),
          Expanded(child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DEDICATED TO', style: AppText.overline.copyWith(color: Colors.white54, fontSize: 8.5, letterSpacing: 1.4)),
              const SizedBox(height: 3),
              Text(dedication!, maxLines: lines, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(color: Colors.white, fontStyle: FontStyle.italic, fontSize: 14, height: 1.35)),
            ]),
          )),
        ]),
      );

  Widget _footer() => Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text('Meditate with me', style: AppText.bodySmall.copyWith(color: _ink, fontWeight: FontWeight.w600)),
          Text('wehum.app', style: AppText.caption.copyWith(color: _light ? const Color(0xFFC2511F) : amber, letterSpacing: .4)),
        ])),
        Text(_date(date), style: AppText.caption.copyWith(color: _light ? _inkSoft : Colors.white54, fontFeatures: AppText.tabular)),
      ]);

  Widget _storyBody() {
    final chips = _chips();
    return Column(children: [
      _header(),
      const Spacer(flex: 3),
      _ring(196),
      const SizedBox(height: 20),
      Text('I meditated today.', textAlign: TextAlign.center, style: AppText.heroTitle.copyWith(color: Colors.white, fontSize: 30, height: 1.1)),
      const SizedBox(height: 6),
      Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bodyLarge.copyWith(color: Colors.white70)),
      if (_together) ...[
        const SizedBox(height: 14),
        _togetherPill(),
        if (hot.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Opacity(opacity: .9, child: WorldDotMap(hot: hot, height: 70))),
      ],
      const Spacer(flex: 2),
      if (chips.isNotEmpty) _chipRow(chips),
      if (dedication != null) ...[const SizedBox(height: 10), _quote()],
      const SizedBox(height: 18),
      _footer(),
    ]);
  }

  Widget _postBody() {
    final chips = _chips().take(2).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header(),
      const Spacer(),
      Row(children: [
        _ring(122),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('I meditated today.', style: AppText.heroTitle.copyWith(color: Colors.white, fontSize: 24, height: 1.1)),
          const SizedBox(height: 4),
          Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bodySmall.copyWith(color: Colors.white70)),
        ])),
      ]),
      if (_together) ...[const SizedBox(height: 10), _togetherPill()],
      const Spacer(),
      if (dedication != null) _quote(lines: 2) else if (chips.isNotEmpty) _chipRow(chips),
      const SizedBox(height: 10),
      _footer(),
    ]);
  }

  String get _countriesText => '$togetherCountries ${togetherCountries == 1 ? 'country' : 'countries'}';

  /// Light, warm card: dark ink on a dawn gradient. Plain lines instead of glass chips.
  Widget _dawnBody() {
    final line = <String>[
      if (_together) 'Together with ${groupedInt(togetherPeople)} people · $_countriesText',
      if (streakDay != null && streakDay! > 1) 'Day $streakDay of my streak',
      if (hrDelta != null) 'Calm shift ${hrDelta! > 0 ? '+' : ''}$hrDelta bpm',
    ];
    return Column(crossAxisAlignment: story ? CrossAxisAlignment.center : CrossAxisAlignment.start, children: [
      _header(),
      const Spacer(flex: 2),
      Center(child: _ring(story ? 200 : 128)),
      SizedBox(height: story ? 22 : 12),
      Text('I meditated today.', textAlign: TextAlign.center, style: AppText.heroTitle.copyWith(color: _ink, fontSize: story ? 30 : 22, height: 1.1)),
      const SizedBox(height: 6),
      Text(title, textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bodyLarge.copyWith(color: _inkSoft, fontSize: story ? null : 14)),
      const SizedBox(height: 10),
      for (final l in line.take(story ? 3 : 1))
        Padding(padding: const EdgeInsets.only(top: 4), child: Text(l, key: l.startsWith('Together') ? const Key('share-together') : null, textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodySmall.copyWith(color: _ink, fontWeight: FontWeight.w600))),
      if (dedication != null && story) Padding(padding: const EdgeInsets.only(top: 16), child: Text('“$dedication”', key: const Key('share-dedication'), textAlign: TextAlign.center, maxLines: 3, overflow: TextOverflow.ellipsis, style: AppText.body.copyWith(color: _inkSoft, fontStyle: FontStyle.italic))),
      const Spacer(flex: 2),
      _footer(),
    ]);
  }

  /// Strava-like: the numbers are the card. Big left-aligned values with small labels, two per row.
  Widget _statsBody() {
    final cells = <(String, String)>[
      ('MINUTES', '$minutes'),
      if (_together) ('MEDITATED WITH', groupedInt(togetherPeople)),
      if (_together) ('COUNTRIES', '$togetherCountries'),
      if (streakDay != null && streakDay! > 1) ('STREAK', '$streakDay days'),
      if (daysThisWeek > 0) ('THIS WEEK', '$daysThisWeek ${daysThisWeek == 1 ? 'day' : 'days'}'),
      if (hrDelta != null) ('CALM SHIFT', '${hrDelta! > 0 ? '+' : ''}$hrDelta bpm'),
    ].take(story ? 6 : 4).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _header(),
      SizedBox(height: story ? 36 : 14),
      Text('I meditated today.', style: AppText.heroTitle.copyWith(color: Colors.white, fontSize: story ? 28 : 22, height: 1.1)),
      const SizedBox(height: 4),
      Text(title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bodyLarge.copyWith(color: Colors.white70, fontSize: story ? null : 14)),
      const Spacer(),
      Wrap(spacing: 12, runSpacing: story ? 22 : 12, children: [
        for (var i = 0; i < cells.length; i++)
          SizedBox(width: 150, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(cells[i].$1, style: AppText.overline.copyWith(color: i == 0 ? amber : Colors.white54, fontSize: 9, letterSpacing: 1.4)),
            const SizedBox(height: 2),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(cells[i].$2, key: i == 0 ? const Key('share-minutes') : null, style: AppText.display.copyWith(color: Colors.white, fontSize: i == 0 ? (story ? 54 : 40) : (story ? 34 : 26), height: 1.05, fontWeight: FontWeight.w700, fontFeatures: AppText.tabular))),
          ])),
      ]),
      const Spacer(),
      if (dedication != null && story) ...[_quote(), const SizedBox(height: 14)],
      _footer(),
    ]);
  }

  /// The map is the hero. Only offered when people really meditated together.
  Widget _worldBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(),
        const Spacer(),
        Text('I meditated today.', style: AppText.heroTitle.copyWith(color: Colors.white, fontSize: story ? 28 : 22, height: 1.1)),
        const SizedBox(height: 4),
        Text('$minutes ${minutes == 1 ? 'minute' : 'minutes'} · $title', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bodyLarge.copyWith(color: Colors.white70, fontSize: story ? null : 14)),
        const SizedBox(height: 14),
        Opacity(opacity: .95, child: WorldDotMap(hot: hot, height: story ? 230 : 120)),
        const SizedBox(height: 12),
        Center(child: _togetherPill()),
        const Spacer(),
        if (dedication != null && story) ...[_quote(), const SizedBox(height: 14)],
        _footer(),
      ]);

  static String _date(DateTime d) {
    const m = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${m[d.month - 1]} ${d.day}, ${d.year}';
  }
}

/// Frosted glass: a translucent white fill with a hairline edge.
class _Glass extends StatelessWidget {
  const _Glass({super.key, required this.child, this.radius = 14, this.padding = const EdgeInsets.all(12)});
  final Widget child;
  final double radius;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Colors.white.withValues(alpha: .13), Colors.white.withValues(alpha: .04)]),
          border: Border.all(color: Colors.white.withValues(alpha: .16), width: .8),
        ),
        child: child,
      );
}

class _Chip extends StatelessWidget {
  const _Chip({super.key, required this.label, required this.value, this.accent = false, this.icon});
  final String label, value;
  final bool accent;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => _Glass(
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, maxLines: 1, style: AppText.overline.copyWith(color: Colors.white54, fontSize: 8.5, letterSpacing: 1.2)),
          const SizedBox(height: 4),
          Row(children: [
            if (icon != null) ...[Icon(icon, size: 14, color: accent ? ShareCard.ember : ShareCard.mint), const SizedBox(width: 4)],
            Flexible(child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                child: Text(value, style: AppText.navTitle.copyWith(color: accent ? ShareCard.amber : Colors.white, fontSize: 15, fontFeatures: AppText.tabular)))),
          ]),
        ]),
      );
}

class _Glow extends StatelessWidget {
  const _Glow({required this.color, required this.size, required this.alpha});
  final Color color;
  final double size, alpha;
  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)]))),
      );
}

/// The hero ring: a soft track, a glowing ember → amber → mint sweep, and a bright dot where it closes.
class _RingPainter extends CustomPainter {
  _RingPainter({this.light = false});
  final bool light;
  @override
  void paint(Canvas canvas, Size s) {
    final c = s.center(Offset.zero);
    final r = s.width / 2 - 10;
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(c, r - 14, Paint()..shader = RadialGradient(colors: [Colors.white.withValues(alpha: light ? .5 : .07), Colors.white.withValues(alpha: 0)]).createShader(rect));
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 7..color = (light ? const Color(0xFF2A1A12) : Colors.white).withValues(alpha: light ? .10 : .08));
    const sweep = SweepGradient(startAngle: -math.pi / 2, endAngle: math.pi * 1.5, colors: [ShareCard.ember, ShareCard.amber, ShareCard.mint, ShareCard.ember]);
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 14..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)..shader = sweep.createShader(rect));
    canvas.drawCircle(c, r, Paint()..style = PaintingStyle.stroke..strokeWidth = 7..strokeCap = StrokeCap.round..shader = sweep.createShader(rect));
    final dot = c + Offset(0, -r);
    canvas.drawCircle(dot, 9, Paint()..color = ShareCard.ember.withValues(alpha: .45)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6));
    canvas.drawCircle(dot, 5, Paint()..color = light ? const Color(0xFF2A1A12) : Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RingPainter o) => o.light != light;
}

/// Faint fixed stars (same pattern every time, so the image is stable).
class _SkyPainter extends CustomPainter {
  _SkyPainter({required this.story});
  final bool story;
  @override
  void paint(Canvas canvas, Size s) {
    final rnd = math.Random(7);
    final p = Paint();
    for (var i = 0; i < (story ? 70 : 40); i++) {
      final o = Offset(rnd.nextDouble() * s.width, rnd.nextDouble() * s.height);
      final big = rnd.nextDouble() > .9;
      canvas.drawCircle(o, big ? 1.3 : .7, p..color = Colors.white.withValues(alpha: big ? .55 : .22 + rnd.nextDouble() * .2));
    }
  }

  @override
  bool shouldRepaint(covariant _SkyPainter o) => o.story != story;
}
