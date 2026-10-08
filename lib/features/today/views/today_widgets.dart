import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/data/models/content.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
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
        button: true, label: 'Meditate now, $minutes minutes, on your own',
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
                    Expanded(child: Text('Meditate now', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.button.copyWith(color: c.onEmber))),
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
          button: true, label: 'Wait for the group, ${g.time}, ${g.live ? 'started' : 'starts in ${g.countdown}'}',
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
                      const SizedBox(width: 10),
                      Expanded(child: Text('Wait for the group', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.bodySmall.copyWith(color: Colors.white, fontWeight: FontWeight.w600))),
                      const SizedBox(width: 8),
                      Text(g.live ? '${g.time} · started' : '${g.time} · in ${g.countdown}', style: AppText.caption.copyWith(color: Colors.white70, fontFeatures: AppText.tabular)),
                      const SizedBox(width: 2),
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
