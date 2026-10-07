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
          ThumbImage(s.cover?.url, blurHash: s.cover?.blurhash, width: 56, height: 56, radius: 12),
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
