import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../../core/services/access_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/surfaces.dart';
import '../../complete/complete_pages.dart' show showWriteDedication;
import '../../together/views/together_pages.dart' show DedicationLine;
import '../controllers/dedications_controllers.dart';

/// Dedications of one meditation, always there: on the details and in the player, before, during and after the sit.
/// Everyone reads the newest ones (live over `session:{id}`); members can write one at any time.
class DedicationsPanel extends StatelessWidget {
  const DedicationsPanel({super.key, required this.sessionId, this.max = 3});
  final String sessionId;
  final int max;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tag = 'panel-$sessionId';
    final ctrl = Get.isRegistered<DedicationsController>(tag: tag) ? Get.find<DedicationsController>(tag: tag) : Get.put(DedicationsController(sessionId), tag: tag);
    final member = Get.find<AccessService>().isMember;
    return AppCard(
      key: const Key('dedications-panel'),
      child: Obx(() {
        final kind = ctrl.state.value.kind;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('Dedications', style: AppText.title.copyWith(color: c.textPrimary))),
            if (ctrl.items.isNotEmpty) TextLink('See all', key: const Key('dedications-all'), onPressed: () => Get.toNamed('/dedications/$sessionId', arguments: {'sessionId': sessionId})),
          ]),
          if (kind == ViewKind.loading)
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))))
          else if (ctrl.items.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(kind == ViewKind.content || kind == ViewKind.empty ? 'No dedications yet. Be the first to dedicate this meditation.' : 'Dedications will load when you’re back.',
                  key: const Key('dedications-empty'), style: AppText.bodySmall.copyWith(color: c.textSecondary)),
            )
          else
            for (final d in ctrl.items.take(max)) DedicationLine(d),
          const SizedBox(height: 8),
          OutlineButton('Write a dedication', key: const Key('dedication-write'), icon: Icons.favorite_border_rounded, onPressed: () => showWriteDedication(context, sessionId, onPosted: ctrl.load)),
          if (!member) Padding(padding: const EdgeInsets.only(top: 6), child: Center(child: Text('Members can write dedications. Anyone can read them.', style: AppText.caption.copyWith(color: c.textTertiary)))),
        ]);
      }),
    );
  }
}
