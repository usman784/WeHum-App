import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/data/models/content.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/motion.dart';
import '../../../core/widgets/surfaces.dart';

/// "Silence Room — Meditate in silence, with bells". Locked (PREMIUM + lock) for free users.
class SilenceRoomRow extends StatelessWidget {
  const SilenceRoomRow({super.key, required this.locked, required this.onTap});
  final bool locked;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppCard(
      key: const Key('silence-row'), onTap: onTap, padding: const EdgeInsets.all(12), radius: Radii.card, semanticLabel: locked ? 'Silence Room, premium, locked' : 'Silence Room',
      child: Row(children: [
        const ThumbImage('assets/images/stones.jpg', width: 64, height: 64, radius: 14),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [Flexible(child: Text('Silence Room', style: AppText.navTitle.copyWith(color: c.textPrimary))), if (locked) ...[const SizedBox(width: 8), const AppBadge(BadgeKind.premium)]]),
            Text('Meditate in silence, with bells', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
          ]),
        ),
        Icon(locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded, color: c.textSecondary),
      ]),
    );
  }
}

/// Free users: a free item row (list under "Free for you").
class FreeItemRow extends StatelessWidget {
  const FreeItemRow({super.key, required this.s, required this.onTap, this.showFreeLabel = true});
  final SessionSummary s;
  final VoidCallback onTap;
  final bool showFreeLabel;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(children: [
          ThumbImage(s.cover?.url, blurHash: s.cover?.blurhash, seed: s.id, width: 56, height: 56, radius: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 16)),
              Text('Raphael · ${s.minutes} min', style: AppText.bodySmall.copyWith(color: c.textSecondary)),
              PracticedMark(s.id),
            ]),
          ),
          Icon(Icons.play_circle_outline_rounded, color: c.textSecondary),
        ]),
      ),
    );
  }
}

/// Opens the paywall from a lock. [source] feeds the `paywall_view` event.
void openPaywall(String source) => Get.toNamed(AppRoutes.membershipPaywall, arguments: {'source': source});

/// The two ways into the Meditation of the Day, on the hero: one clear primary action, and the group as a slim glass
/// strip underneath (not a second big button). Primary: play icon, label, length chip. Strip: when it starts.
class HeroActions extends StatelessWidget {
  const HeroActions({super.key, required this.minutes, required this.onMeditate, this.group});
  final int minutes;
  final VoidCallback onMeditate;
  final ({String time, bool live, String countdown, VoidCallback onTap})? group;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final g = group;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Semantics(
        button: true, label: 'Join the meditation, $minutes minutes, on your own',
        child: Material(
          key: const Key('meditate-now'), color: c.ember, shape: const StadiumBorder(),
          child: InkWell(
            customBorder: const StadiumBorder(), onTap: onMeditate,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 14, 6),
                child: ExcludeSemantics(
                  child: Row(children: [
                    Container(width: 38, height: 38, decoration: BoxDecoration(color: c.onEmber.withValues(alpha: .14), shape: BoxShape.circle), child: Icon(Icons.play_arrow_rounded, color: c.onEmber, size: 26)),
                    const SizedBox(width: 10),
                    Expanded(child: Text('Join the meditation', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.button.copyWith(color: c.onEmber))),
                    const SizedBox(width: 8),
                    Text('on your own', style: AppText.caption.copyWith(color: c.onEmber.withValues(alpha: .75), fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
      if (g != null) ...[
        const SizedBox(height: 8),
        Semantics(
          button: true, label: 'Wait in the lobby, ${g.time}, ${g.live ? 'started' : 'starts in ${g.countdown}'}',
          child: Material(
            key: const Key('wait-group'), color: Colors.white.withValues(alpha: .10), shape: StadiumBorder(side: BorderSide(color: Colors.white.withValues(alpha: .20))),
            child: InkWell(
              customBorder: const StadiumBorder(), onTap: g.onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: ExcludeSemantics(
                    child: Row(children: [
                      const Icon(Icons.groups_2_rounded, color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      // maxLines 2: with a large system font the label wraps instead of being cut off
                      Expanded(child: Text('Wait in the lobby', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600))),
                      const SizedBox(width: 8),
                      Text(g.live ? '${g.time} · started' : '${g.time} · ${g.countdown}', style: AppText.caption.copyWith(color: Colors.white70, fontFeatures: AppText.tabular)),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white70, size: 18),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ]);
  }
}

/// Slim banner for someone who is not logged in: the one place that asks them to log in or create an account
/// (the Log in screen has the Create account link). A colour ring turns around the border, soft glows drift
/// inside, the badge pulses; all still when the phone asks for reduced motion.
class SignInPromo extends StatefulWidget {
  const SignInPromo({super.key, required this.onLogIn});
  final VoidCallback onLogIn;
  @override
  State<SignInPromo> createState() => _SignInPromoState();
}

class _SignInPromoState extends State<SignInPromo> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 5));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (reduceMotion(context)) {
      _a.stop();
    } else if (!_a.isAnimating) {
      _a.repeat();
    }
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedBuilder(
      animation: _a,
      builder: (context, _) {
        final t = _a.value * 2 * math.pi;
        final breathe = (math.sin(t) + 1) / 2;
        return Pressable(
          child: Semantics(
            button: true, label: 'You are not logged in. Save your progress. Log in or create an account',
            child: Container(
              key: const Key('signin-promo'),
              padding: const EdgeInsets.all(1.6),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: SweepGradient(transform: GradientRotation(t), colors: [c.ember, c.lilacText, c.teal, c.ember]),
                boxShadow: [BoxShadow(color: c.ember.withValues(alpha: .16 + .2 * breathe), blurRadius: 18 + 8 * breathe, spreadRadius: -2)],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18.4),
                child: Material(
                  color: c.surface,
                  child: InkWell(
                    onTap: widget.onLogIn,
                    child: Stack(children: [
                      Positioned(left: -30 + 150 * (0.5 + 0.5 * math.sin(t)), top: -40, child: _glow(c.ember.withValues(alpha: .30), 120)),
                      Positioned(right: -30 + 60 * (0.5 + 0.5 * math.cos(t)), bottom: -50, child: _glow(c.lilacText.withValues(alpha: .22), 120)),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                        child: Row(children: [
                          SizedBox(
                            width: 46, height: 46,
                            child: Stack(alignment: Alignment.center, children: [
                              Container(width: 34 + 12 * breathe, height: 34 + 12 * breathe, decoration: BoxDecoration(shape: BoxShape.circle, color: c.ember.withValues(alpha: .32 * (1 - breathe)))),
                              Container(width: 34, height: 34, decoration: BoxDecoration(shape: BoxShape.circle, color: c.ember), child: Icon(Icons.person_rounded, size: 19, color: c.onEmber)),
                            ]),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
                              Text('Save your progress', style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                              const SizedBox(height: 2),
                              Text('Log in or create an account', key: const Key('signin-promo-note'), style: AppText.caption.copyWith(color: c.textSecondary, fontSize: 12.5)),
                            ]),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            key: const Key('signin-promo-login'), width: 42, height: 42,
                            decoration: BoxDecoration(shape: BoxShape.circle, color: c.ember, boxShadow: [BoxShadow(color: c.ember.withValues(alpha: .25 + .35 * breathe), blurRadius: 8 + 10 * breathe)]),
                            child: Icon(Icons.arrow_forward_rounded, size: 22, color: c.onEmber),
                          ),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _glow(Color color, double size) => Container(width: size, height: size, decoration: BoxDecoration(shape: BoxShape.circle, gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)])));
}
