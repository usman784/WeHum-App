import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../app/routes/app_routes.dart';
import '../../../core/config/app_links.dart';
import '../../../core/services/access_service.dart';
import '../../../core/services/analytics_service.dart';
import '../../../core/services/catalog_service.dart';
import '../../../core/services/download_service.dart';
import '../../../core/services/play_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/states.dart' show OfflineBanner;
import '../../../core/widgets/surfaces.dart';

/// 68 Update required: blocking, no back. Version gate comes from the server (`426` / `bootstrap.updateRequired`).
class UpdateRequiredPage extends StatelessWidget {
  const UpdateRequiredPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(Gap.gutterOnboarding),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Icon(Icons.system_update_alt_rounded, size: 64, color: c.ember),
              const SizedBox(height: 20),
              Text('Time for an update', textAlign: TextAlign.center, style: AppText.heroTitle.copyWith(color: c.textPrimary)),
              const SizedBox(height: 10),
              Text('This version of WeHum is no longer supported. Update to keep your progress, meditations and downloads in sync.', textAlign: TextAlign.center, style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
              const SizedBox(height: 28),
              PrimaryButton('Update WeHum', key: const Key('update-btn'), onPressed: () => launchUrl(Uri.parse(Platform.isIOS ? AppLinks.iosStore : AppLinks.androidStore), mode: LaunchMode.externalApplication)),
              const SizedBox(height: 16),
              FutureBuilder<PackageInfo>(future: PackageInfo.fromPlatform(), builder: (_, s) => Text('Version ${s.data?.version ?? ''}', textAlign: TextAlign.center, style: AppText.caption.copyWith(color: c.textTertiary))),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Maintenance: the API says 503. Downloads and the Silence Room keep working offline.
class MaintenancePage extends StatelessWidget {
  const MaintenancePage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Gap.gutterOnboarding),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Icon(Icons.build_circle_outlined, size: 64, color: c.textTertiary),
            const SizedBox(height: 20),
            Text('We’ll be right back', textAlign: TextAlign.center, style: AppText.heroTitle.copyWith(color: c.textPrimary)),
            const SizedBox(height: 10),
            Text('WeHum is being updated. Your downloads and the Silence Room still work.', textAlign: TextAlign.center, style: AppText.bodyLarge.copyWith(color: c.textSecondary)),
            const SizedBox(height: 28),
            PrimaryButton('Try again', key: const Key('maint-retry'), onPressed: () => Get.offAllNamed(AppRoutes.splash)),
            const SizedBox(height: 8),
            OutlineButton('Go to downloads', onPressed: () => Get.toNamed(AppRoutes.downloads)),
            OutlineButton('Silence Room', onPressed: () => Get.toNamed(AppRoutes.silenceRoomSetup)),
          ]),
        ),
      ),
    );
  }
}

/// Deep link not found / unknown route.
class NotFoundPage extends StatelessWidget {
  const NotFoundPage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppScaffold(
      title: '',
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.travel_explore_rounded, size: 56, color: c.textTertiary),
          const SizedBox(height: 16),
          Text('We couldn’t find that', style: AppText.title.copyWith(color: c.textPrimary)),
          const SizedBox(height: 8),
          Text('The link may be old or the meditation was removed.', textAlign: TextAlign.center, style: AppText.body.copyWith(color: c.textSecondary)),
          const SizedBox(height: 24),
          PrimaryButton('Go to Today', key: const Key('notfound-home'), fullWidth: false, onPressed: () => Get.offAllNamed(Get.find<AccessService>().isMember ? AppRoutes.todayMember : AppRoutes.todayFree)),
        ]),
      ),
    );
  }
}

/// 65 Offline: what works without internet and what needs it.
class OfflinePage extends StatelessWidget {
  const OfflinePage({super.key});
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dl = Get.find<DownloadService>();
    Get.find<AnalyticsService>().track('offline_banner_shown');
    return AppScaffold(
      title: 'Offline', banner: const OfflineBanner(),
      body: Obx(() {
        final done = dl.items.where((d) => d.status == 'done').toList();
        return ListView(padding: const EdgeInsets.fromLTRB(Gap.gutter, 8, Gap.gutter, 24), children: [
          Text('AVAILABLE OFFLINE · ${done.length}', key: const Key('offline-count'), style: AppText.overline.copyWith(color: c.textTertiary)),
          for (final d in done)
            ListRow(title: d.title.isEmpty ? d.sessionId : d.title, leading: const IconTile(Icons.download_done_rounded), onTap: () {
              final s = Get.find<CatalogService>().catalog.value?.session(d.sessionId);
              if (s != null) launchSession(s);
            }),
          if (done.isEmpty) Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text('Nothing downloaded yet. Download sessions while you’re online to meditate anywhere.', style: AppText.bodySmall.copyWith(color: c.textSecondary))),
          AppCard(onTap: () => Get.toNamed(AppRoutes.silenceRoomSetup), child: const ListRow(title: 'Silence Room timer', subtitle: 'Works offline, without live counts', leading: IconTile(Icons.nightlight_round), showChevron: false)),
          const SizedBox(height: 16),
          Text('NEEDS INTERNET', style: AppText.overline.copyWith(color: c.textTertiary)),
          const ListRow(title: 'Group meditations', subtitle: 'Back when you’re online', showChevron: false),
          const ListRow(title: 'Free meditations', subtitle: 'Back when you’re online', showChevron: false),
          const SizedBox(height: 12),
          const _Note(title: 'Live counts paused', body: 'We don’t show old numbers as if they were live. Presence comes back as soon as you reconnect.'),
          const _Note(title: 'Dedications will load when you’re back', body: 'Anything you write offline waits on your phone and posts once you’re online.'),
          const _Note(title: 'Your meditations are safe', body: 'Meditations you do offline are saved and synced when you reconnect, so your progress stays right.'),
        ]);
      }),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note({required this.title, required this.body});
  final String title, body;
  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(padding: const EdgeInsets.only(top: 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppText.navTitle.copyWith(color: c.textPrimary, fontSize: 16)), Text(body, style: AppText.bodySmall.copyWith(color: c.textSecondary))]));
  }
}
