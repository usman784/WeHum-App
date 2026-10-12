import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/controls.dart';
import '../../../core/widgets/stitch.dart';
import '../../../core/widgets/surfaces.dart';
import '../controllers/onboarding_controllers.dart';
import 'onboarding_widgets.dart';

/// 06 Setup 1 · Your name.
class NamePage extends StatelessWidget {
  const NamePage({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(NameController());
    final c = context.colors;
    return OnboardingFrame(
      showBack: true, onSkip: ctrl.skip, cta: 'Continue', onCta: ctrl.submit,
      topRight: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('STEP 1 OF 3', style: AppText.overline.copyWith(color: c.textTertiary)),
        const SizedBox(width: 16),
        TextLink('Skip', onPressed: ctrl.skip, color: c.textSecondary),
      ]),
      child: SingleChildScrollView(
        child: Obx(() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 12),
              Text('What should we call you?', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
              const SizedBox(height: 10),
              Text('Your first name, for your welcome message. No account needed.', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
              const SizedBox(height: 28),
              TextFormField(
                key: const Key('name-field'), initialValue: ctrl.name.value, autofocus: true, textCapitalization: TextCapitalization.words, textInputAction: TextInputAction.done, maxLength: 30,
                inputFormatters: [LengthLimitingTextInputFormatter(30)], onChanged: (v) => ctrl.name.value = v, onFieldSubmitted: (_) => ctrl.submit(),
                style: AppText.bodyLarge.copyWith(color: c.textPrimary),
                decoration: InputDecoration(
                  labelText: 'First name', counterText: '', errorText: ctrl.error, filled: true, fillColor: c.surfaceInput,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(Radii.input), borderSide: BorderSide(color: c.border)),
                ),
              ),
              const SizedBox(height: 24),
              Text('PREVIEW', style: AppText.overline.copyWith(color: c.textTertiary)),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.pill), border: Border.all(color: c.border)),
                child: Text(ctrl.greeting(), key: const Key('name-preview'), style: AppText.navTitle.copyWith(color: c.textPrimary)),
              ),
            ])),
      ),
    );
  }
}

/// 07 Setup 2 · Sit time: wheel in local time, how many members sit in that hour, suggested blocks, the daily chime.
class TimePage extends StatelessWidget {
  const TimePage({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(TimeController());
    final c = context.colors;
    return OnboardingFrame(
      showBack: true, cta: 'Lock time', onCta: ctrl.submit,
      topRight: Text('STEP 2 OF 3', style: AppText.overline.copyWith(color: c.textTertiary)),
      footer: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Center(child: TextLink('Decide later', key: const Key('time-later'), onPressed: ctrl.later, color: c.textSecondary)),
      ),
      child: SingleChildScrollView(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const SizedBox(height: 12),
          Text('Anchor your sit into your daily rhythm.', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
          const SizedBox(height: 10),
          Text('Gentle consistency over rigid perfection. Choose the time of day when your mind is least crowded.', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
          const SizedBox(height: 8),
          Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              TimeWheel(key: const Key('hour-wheel'), count: 24, value: ctrl.hour, label: 'Hour'),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(':', style: AppText.display.copyWith(color: c.textPrimary))),
              TimeWheel(key: const Key('minute-wheel'), count: 60, step: 5, value: ctrl.minute, label: 'Minute'),
            ]),
          ),
          Center(child: Text('24-hour clock, in your local time', style: AppText.caption.copyWith(color: c.textTertiary))),
          const SizedBox(height: 10),
          Obx(() {
            final n = ctrl.members.value;
            if (n == null || n <= 0) return const SizedBox.shrink();
            return Center(
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Container(width: 8, height: 8, decoration: BoxDecoration(color: c.success, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Flexible(child: Text('${groupedInt(n)} ${n == 1 ? 'member sits' : 'members sit'} together in this block', key: const Key('members-line'), textAlign: TextAlign.center, style: AppText.bodySmall.copyWith(color: c.textSecondary))),
              ]),
            );
          }),
          const SizedBox(height: 22),
          Text('SUGGESTED PRIME BLOCKS', style: AppText.overline.copyWith(color: c.textTertiary)),
          const SizedBox(height: 10),
          Obx(() {
            ctrl.hour.value; // rebuild when the wheel moves
            ctrl.minute.value;
            return Wrap(spacing: 10, runSpacing: 10, children: [
              for (final b in ctrl.blocks)
                _BlockTile(key: Key('block-${b.time}'), label: b.label, time: TimeController.clock(b.time), selected: ctrl.isPicked(b), onTap: () => ctrl.pick(b)),
            ]);
          }),
          const SizedBox(height: 22),
          Obx(() => AppCard(
                child: Row(children: [
                  Icon(Icons.notifications_active_outlined, color: c.emberText),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Allow daily sit chime', style: AppText.navTitle.copyWith(color: c.textPrimary)),
                      Text('A single, quiet 10-minute heads-up before your room opens. No spam, no guilt, no promotional buzz.', style: AppText.caption.copyWith(color: c.textSecondary)),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  AppToggle(key: const Key('chime-toggle'), value: ctrl.chime.value, onChanged: (v) => ctrl.chime.value = v, label: 'Allow daily sit chime'),
                ]),
              )),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class _BlockTile extends StatelessWidget {
  const _BlockTile({super.key, required this.label, required this.time, required this.selected, required this.onTap});
  final String label, time;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true, selected: selected, label: '$label, $time',
      child: GestureDetector(
        onTap: onTap,
        child: ExcludeSemantics(
          child: Container(
            width: (MediaQuery.sizeOf(context).width - Gap.gutterOnboarding * 2 - 10) / 2, padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected ? c.emberTint : c.surface, borderRadius: BorderRadius.circular(Radii.tile),
              border: Border.all(color: selected ? c.ember : c.border, width: selected ? 1.5 : 1)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(time, style: AppText.navTitle.copyWith(color: selected ? c.emberText : c.textPrimary, fontFeatures: AppText.tabular)),
              const SizedBox(height: 2),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppText.caption.copyWith(color: c.textSecondary)),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Snapping wheel bound to an Rx int. Minutes step by 5.
class TimeWheel extends StatefulWidget {
  const TimeWheel({super.key, required this.count, required this.value, required this.label, this.step = 1});
  final int count, step;
  final RxInt value;
  final String label;
  @override
  State<TimeWheel> createState() => _TimeWheelState();
}

class _TimeWheelState extends State<TimeWheel> {
  late final FixedExtentScrollController _c = FixedExtentScrollController(initialItem: widget.value.value ~/ widget.step);
  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = widget.count ~/ widget.step;
    return Semantics(
      label: '${widget.label} ${widget.value.value}', hint: 'Swipe up or down to change',
      child: SizedBox(
        width: 96, height: 220,
        child: ListWheelScrollView.useDelegate(
          controller: _c, itemExtent: 64, diameterRatio: 1.6, perspective: .003, physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (i) {
            widget.value.value = (i % n) * widget.step;
            HapticFeedback.selectionClick();
          },
          childDelegate: ListWheelChildLoopingListDelegate(children: [
            for (var i = 0; i < n; i++)
              Obx(() {
                final sel = widget.value.value == i * widget.step;
                return Center(child: Text((i * widget.step).toString().padLeft(2, '0'), style: AppText.display.copyWith(fontSize: sel ? 44 : 30, color: sel ? c.textPrimary : c.textTertiary)));
              }),
          ]),
        ),
      ),
    );
  }
}

/// 08 Setup 3 · Reminder: the OS permission is requested on Allow; "Not now" still continues.
class ReminderPermissionPage extends StatelessWidget {
  const ReminderPermissionPage({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(ReminderPermissionController());
    final c = context.colors;
    return OnboardingFrame(
      showBack: true, topRight: Text('STEP 3 OF 3', style: AppText.overline.copyWith(color: c.textTertiary)),
      // One neutral button that opens the system prompt; the person answers there (Apple HIG, "Requesting permission":
      // no look-alike alert, no "Allow" wording, no button that skips the system prompt). Either answer continues.
      cta: 'Continue', onCta: ctrl.allow,
      child: Obx(() => ctrl.busy.value
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 12),
              Text('We will invite you to meditate at ${ctrl.timeLabel}.', key: const Key('reminder-title'), style: AppText.heroTitle.copyWith(color: c.textPrimary)),
              const SizedBox(height: 10),
              Text('Next, your phone will ask if WeHum may send notifications. This is what we use them for:', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
              const SizedBox(height: 20),
              const _Use(Icons.notifications_none_rounded, 'Your daily reminder', 'Once a day at the time you chose, in your local time zone.'),
              const _Use(Icons.groups_2_outlined, 'Group meditation', 'A heads-up before the group starts, only if you ask for it.'),
              const _Use(Icons.mail_outline_rounded, 'Messages from Raphael', 'The daily message and news about your membership.'),
              const SizedBox(height: 8),
              Text('No advertising. You can change this any time in Reminders or in your phone’s Settings, and WeHum works without notifications too.', key: const Key('permission-note'), style: AppText.bodySmall.copyWith(color: c.textTertiary)),
            ]))),
    );
  }
}


class _Use extends StatelessWidget {
  const _Use(this.icon, this.title, this.body);
  final IconData icon;
  final String title, body;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ExcludeSemantics(child: Icon(icon, color: c.emberText)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: AppText.bodyLarge.copyWith(color: c.textPrimary, fontWeight: FontWeight.w600)),
          Text(body, style: AppText.bodySmall.copyWith(color: c.textSecondary)),
        ])),
      ]),
    );
  }
}
