import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/painters.dart';
import '../../../core/widgets/surfaces.dart';
import '../controllers/onboarding_controllers.dart';
import 'onboarding_widgets.dart';

/// Intro slides 02–05 (`/intro/1..4`). Copy is the final design copy; only live numbers come from the socket.
class IntroPage extends StatelessWidget {
  const IntroPage(this.step, {super.key});
  final int step;

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(IntroController(step), tag: 'intro$step');
    final c = context.colors;
    return OnboardingFrame(
      onSkip: ctrl.skip, dots: step - 1, cta: 'Next', onCta: ctrl.next,
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _hero(context, ctrl),
          const SizedBox(height: 28),
          ..._text(c),
        ]),
      ),
    );
  }

  Widget _hero(BuildContext context, IntroController ctrl) {
    final c = context.colors;
    switch (step) {
      case 1:
        return const HeroImageCard(image: 'assets/images/seated.jpg', height: 330, radius: 28, child: SizedBox());
      case 2:
        return Obx(() {
          final pill = ctrl.livePill;
          return Container(
            height: 330, width: double.infinity, decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(28), border: Border.all(color: c.border)),
            child: Stack(alignment: Alignment.center, children: [
              PresenceRing(people: ctrl.live.agg.value?.total ?? 0, size: 250),
              if (pill != null) Positioned(top: 18, left: 18, child: LivePill(text: pill, quiet: ctrl.live.agg.value?.quiet ?? false)),
            ]),
          );
        });
      case 3:
        return AppCard(
          radius: 28, padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [Expanded(child: Overline('Meditation of the day')), SizedBox(width: 8), AppBadge(BadgeKind.premium)]),
            const SizedBox(height: 12),
            Text('Steady Under Pressure', style: AppText.title.copyWith(color: c.textPrimary)),
            const SizedBox(height: 16),
            Container(height: 48, alignment: Alignment.center, decoration: BoxDecoration(color: c.ember, borderRadius: BorderRadius.circular(Radii.pill)), child: Text('Begin', style: AppText.button.copyWith(color: c.onEmber))),
            const SizedBox(height: 20),
            const Overline('Daily message'),
            const SizedBox(height: 6),
            Text('A short note from Raphael', style: AppText.bodyLarge.copyWith(color: c.textBody)),
          ]),
        );
      default:
        return Column(children: [
          for (final (icon, title, sub) in [(Icons.grid_view_rounded, 'Library', 'Free and premium meditations'), (Icons.tune_rounded, 'Build your own', 'Your length, your sounds'), (Icons.favorite_border_rounded, 'SoS', 'Short sessions for hard moments')])
            Padding(padding: const EdgeInsets.only(bottom: 10), child: AppCard(child: ListRow(title: title, subtitle: sub, leading: IconTile(icon), showChevron: false))),
        ]);
    }
  }

  List<Widget> _text(AppColors c) {
    final (title, body, small) = switch (step) {
      1 => ('WeHum by Raphael Reiter', 'Natural, secular spirituality. Meditation is spiritual, and it’s also a skill that makes us better at being human.', 'Learn to manage your emotions and meet life with courage, temperance and understanding.'),
      2 => ('You’re never meditating alone.', 'Transcendence is the deep understanding, and the feeling, that we are part of one interconnected system of nature.', 'Every meditation is shared with real people around the world, in real time.'),
      3 => ('One meditation a day. That’s the whole trick.', 'A new Meditation of the Day, group meditations, and a short daily message from Raphael.', ''),
      _ => ('Training, not therapy.', 'Free meditations from the channel, an exclusive premium library, meditations you build to your own length and sound, and SoS sessions for hard moments.', ''),
    };
    return [
      Text(title, style: AppText.heroTitle.copyWith(color: c.textPrimary)),
      const SizedBox(height: 14),
      Text(body, style: AppText.bodyLarge.copyWith(color: c.textBody)),
      if (small.isNotEmpty) ...[const SizedBox(height: 14), Text(small, style: AppText.body.copyWith(color: c.textSecondary))],
    ];
  }
}
