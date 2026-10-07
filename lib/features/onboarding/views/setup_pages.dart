import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/buttons.dart';
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

/// 07 Setup 2 · Meditation reminder: 24-hour wheel in local time.
class TimePage extends StatelessWidget {
  const TimePage({super.key});
  @override
  Widget build(BuildContext context) {
    final ctrl = Get.put(TimeController());
    final c = context.colors;
    return OnboardingFrame(
      showBack: true, cta: 'Continue', onCta: ctrl.submit,
      topRight: Text('STEP 2 OF 3', style: AppText.overline.copyWith(color: c.textTertiary)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 12),
        Text('Meditation reminder', style: AppText.heroTitle.copyWith(color: c.textPrimary)),
        const SizedBox(height: 10),
        Text('We will remind you to meditate daily, as consistency is important.', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
        Expanded(
          child: Center(
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              TimeWheel(key: const Key('hour-wheel'), count: 24, value: ctrl.hour, label: 'Hour'),
              Padding(padding: const EdgeInsets.symmetric(horizontal: 8), child: Text(':', style: AppText.display.copyWith(color: c.textPrimary))),
              TimeWheel(key: const Key('minute-wheel'), count: 60, step: 5, value: ctrl.minute, label: 'Minute'),
            ]),
          ),
        ),
        Center(child: Text('24-hour clock, in your local time', style: AppText.caption.copyWith(color: c.textTertiary))),
        const SizedBox(height: 16),
      ]),
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
      cta: 'Allow notifications', onCta: ctrl.allow,
      footer: Padding(padding: const EdgeInsets.only(bottom: 12), child: TextLink('Not now', onPressed: ctrl.notNow, color: c.textSecondary)),
      child: Obx(() => ctrl.busy.value
          ? const Center(child: CircularProgressIndicator())
          : Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const SizedBox(height: 12),
              Text('We will invite you to meditate at ${ctrl.timeLabel}.', key: const Key('reminder-title'), style: AppText.heroTitle.copyWith(color: c.textPrimary)),
              const SizedBox(height: 10),
              Text('A gentle reminder at your chosen time, in your local time zone. You can change it any time in Reminders.', style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(Radii.cardLarge), border: Border.all(color: c.border)),
                child: Column(children: [
                  Text('“WeHum” Would Like to Send You Notifications', textAlign: TextAlign.center, style: AppText.navTitle.copyWith(color: c.textPrimary)),
                  const SizedBox(height: 8),
                  Text('Notifications may include alerts, sounds and icon badges.', textAlign: TextAlign.center, style: AppText.caption.copyWith(color: c.textSecondary)),
                ]),
              ),
            ])),
    );
  }
}

