import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import '../../app/routes/app_routes.dart';
import '../../core/data/contracts/repositories.dart';
import '../../core/data/models/stitch.dart';
import '../../core/errors/error_code.dart';
import '../../core/services/access_service.dart';
import '../../core/services/analytics_service.dart';
import '../../core/services/catalog_service.dart';
import '../../core/services/play_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/buttons.dart';
import '../../core/widgets/painters.dart' show Overline;
import '../../core/widgets/states.dart';
import '../../core/widgets/stitch.dart';
import '../../core/widgets/surfaces.dart';
import '../today/views/today_widgets.dart';

/// Cohort sprint detail (Stitch challenge detail): trajectory, grace day, the schedule with unlock times.
class ChallengeDetailController extends GetxController {
  ChallengeDetailController(this.id);
  final String id;
  late final ComingSoonRepository _repo = Get.find();
  final state = ViewState.loading.obs;
  final data = Rxn<ChallengeDetail>();
  final busy = false.obs;
  final message = RxnString();

  @override
  void onInit() {
    super.onInit();
    Get.find<AnalyticsService>().track('challenge_view', {'challenge_id': id});
    load();
  }

  Future<void> load() async {
    try {
      data.value = await _repo.challengeDetail(id);
      state.value = ViewState.content;
    } catch (e) {
      state.value = ViewState.fromError(e);
    }
  }

  Future<void> join() async {
    final d = data.value;
    if (d == null || busy.value) return;
    if (d.membersOnly && !Get.find<AccessService>().isMember) {
      openPaywall('lock');
      return;
    }
    busy.value = true;
    message.value = null;
    try {
      await _repo.joinChallenge(id);
      Get.find<AnalyticsService>().track('challenge_join', {'challenge_id': id});
      await load();
    } catch (e) {
      final f = ViewState.fromError(e);
      message.value = f.error?.code == ErrorCode.premiumRequired ? 'Challenges are for members.' : 'Could not join. Please try again.';
    } finally {
      busy.value = false;
    }
  }

  /// "Begin day N": plays the day's meditation when the CMS linked one, otherwise goes to Today.
  void begin(ScheduleDay day) {
    Get.find<AnalyticsService>().track('challenge_day_begin', {'challenge_id': id, 'day': day.day});
    final sid = day.sessionId;
    final s = sid == null ? null : Get.find<CatalogService>().catalog.value?.session(sid);
    if (s != null) {
      launchSession(s, kind: 'solo');
    } else {
      Get.offAllNamed(AppRoutes.todayMember);
    }
  }
}

class ChallengeDetailPage extends StatelessWidget {
  const ChallengeDetailPage({super.key});
  @override
  Widget build(BuildContext context) {
    final id = ((Get.arguments as Map?)?['id'] ?? Get.parameters['id'] ?? '') as String;
    final ctrl = Get.put(ChallengeDetailController(id), tag: id);
    final c = context.colors;
    return AppScaffold(
      title: 'Challenge',
      body: Obx(() => StateSwitcher(
            state: ctrl.state.value, onRetry: ctrl.load,
            content: () => Obx(() {
              final d = ctrl.data.value!;
              final today = d.today;
              return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 0, Gap.gutter, 24), children: [
                const Overline('Cohort sprint'),
                const SizedBox(height: 6),
                Text(d.name, key: const Key('challenge-title'), style: AppText.heroTitle.copyWith(color: c.textPrimary)),
                if ((d.blurb ?? '').isNotEmpty) ...[const SizedBox(height: 8), Text(d.blurb!, style: AppText.bodyLarge.copyWith(color: c.textSecondary))],
                const SizedBox(height: 16),
                if (d.cohort > 0)
                  AppCard(
                    key: const Key('cohort-card'),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('${groupedInt(d.cohort)} in this cohort', style: AppText.navTitle.copyWith(color: c.textPrimary, fontFeatures: AppText.tabular)),
                      if (!d.belts.isEmpty) ...[const SizedBox(height: 12), BeltCounts(belts: d.belts)],
                    ]),
                  ),
                const SizedBox(height: 12),
                AppCard(
                  key: const Key('trajectory-card'),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const SectionLabel('Cumulative trajectory'),
                    const SizedBox(height: 8),
                    Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text('Day ${d.completedDays} of ${d.days}', style: AppText.title.copyWith(color: c.textPrimary, fontFeatures: AppText.tabular)),
                      const Spacer(),
                      Text('${d.pct}%', style: AppText.title.copyWith(color: c.emberText, fontFeatures: AppText.tabular)),
                    ]),
                    const SizedBox(height: 10),
                    AppProgressBar(d.days == 0 ? 0 : d.completedDays / d.days),
                    const SizedBox(height: 12),
                    Row(children: [
                      Icon(Icons.verified_user_outlined, size: 18, color: c.tealText),
                      const SizedBox(width: 8),
                      Expanded(child: Text(d.graceLeft > 0 ? '${d.graceLeft} grace day${d.graceLeft == 1 ? '' : 's'} protected. Miss a day without losing your pace.' : 'Grace used. Keep your pace from here.', style: AppText.caption.copyWith(color: c.textSecondary))),
                    ]),
                  ]),
                ),
                const SizedBox(height: 22),
                const SectionLabel('Schedule'),
                const SizedBox(height: 8),
                for (final day in d.schedule) _DayRow(day: day, unlockTime: d.unlockTime, onBegin: () => ctrl.begin(day)),
                if (d.badge != null) ...[
                  const SizedBox(height: 14),
                  AppCard(
                    key: const Key('badge-card'), outlined: true,
                    child: Row(children: [
                      Icon(Icons.workspace_premium_rounded, color: c.emberText),
                      const SizedBox(width: 12),
                      Expanded(child: Text('Earn the ${d.badge} badge on day ${d.days}.', style: AppText.bodySmall.copyWith(color: c.textPrimary))),
                    ]),
                  ),
                ],
                if (d.leadName != null) ...[
                  const SizedBox(height: 14),
                  Text('Led by ${d.leadName}${d.leadRole == null ? '' : ' · ${d.leadRole}'}', style: AppText.caption.copyWith(color: c.textSecondary)),
                ],
                if (ctrl.message.value != null) ...[const SizedBox(height: 10), Text(ctrl.message.value!, style: AppText.bodySmall.copyWith(color: c.dangerText))],
                const SizedBox(height: 18),
                if (!d.joined)
                  PrimaryButton('Join the cohort', key: const Key('join-challenge'), loading: ctrl.busy.value, onPressed: ctrl.join)
                else if (today != null)
                  PrimaryButton('Begin day ${today.day}${today.minutes == null ? '' : ' (${today.minutes} min)'}', key: const Key('begin-day'), onPressed: () => ctrl.begin(today)),
              ]);
            }),
          )),
    );
  }
}

class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.unlockTime, required this.onBegin});
  final ScheduleDay day;
  final String unlockTime;
  final VoidCallback onBegin;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final done = day.state == 'done', active = day.state == 'today';
    final sub = done
        ? '${day.minutes == null ? '' : '${day.minutes} min · '}Completed'
        : active
            ? (day.summary.isEmpty ? 'Today' : day.summary)
            : (day.unlocksAt == null ? 'Locked' : 'Unlocks ${DateFormat('EEE, MMM d').format(day.unlocksAt!.toLocal())} at $unlockTime');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        key: Key('day-${day.day}'), color: active ? c.emberTint : null, onTap: active ? onBegin : null, semanticLabel: 'Day ${day.day}, ${day.title}, $sub',
        child: Row(children: [
          Container(
            width: 36, height: 36, alignment: Alignment.center,
            decoration: BoxDecoration(shape: BoxShape.circle, color: done ? c.ember : c.track, border: active ? Border.all(color: c.ember, width: 2) : null),
            child: done ? Icon(Icons.check_rounded, size: 18, color: c.onEmber) : (active ? Text('${day.day}', style: AppText.badge.copyWith(color: c.emberText)) : Icon(Icons.lock_outline_rounded, size: 16, color: c.textSecondary)),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Day ${day.day} · ${day.title}', maxLines: 2, overflow: TextOverflow.ellipsis, style: AppText.navTitle.copyWith(color: day.state == 'locked' ? c.textSecondary : c.textPrimary, fontSize: 15)),
            Text(sub, style: AppText.caption.copyWith(color: c.textSecondary)),
          ])),
          if (day.minutes != null && !done) Text('${day.minutes} min', style: AppText.caption.copyWith(color: c.textTertiary, fontFeatures: AppText.tabular)),
        ]),
      ),
    );
  }
}
