import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../../core/services/access_service.dart';
import '../../core/widgets/app_scaffold.dart';
import '../../core/widgets/states.dart';
import '../../features/account/views/account_pages.dart';
import '../../features/byo/byo_pages.dart';
import '../../features/complete/complete_pages.dart';
import '../../features/library/views/detail_pages.dart';
import '../../features/library/views/library_pages.dart';
import '../../features/library/views/session_pages.dart';
import '../../features/membership/views/membership_pages.dart';
import '../../features/messages/views/messages_pages.dart';
import '../../features/player/views/player_pages.dart';
import '../../features/silence/silence_pages.dart';
import '../../features/soon/soon_pages.dart';
import '../../features/sos/sos_page.dart';
import '../../features/system/views/system_pages.dart';
import '../../features/you/views/you_pages.dart';
import '../../features/onboarding/views/intro_pages.dart';
import '../../features/today/views/today_pages.dart';
import '../../features/together/views/together_pages.dart';
import '../../features/onboarding/views/setup_pages.dart';
import '../../features/onboarding/views/splash_page.dart';
import '../../features/onboarding/views/start_page.dart';
import 'app_routes.dart';

/// Every route has a page from P0; each phase swaps its placeholders for the real screen (spec §14).
abstract final class AppPages {
  static final pages = <GetPage<dynamic>>[
    GetPage(name: AppRoutes.splash, page: () => const SplashPage()),
    GetPage(name: AppRoutes.intro1Welcome, page: () => const IntroPage(1)),
    GetPage(name: AppRoutes.intro2NeverAlone, page: () => const IntroPage(2)),
    GetPage(name: AppRoutes.intro3EveryDay, page: () => const IntroPage(3)),
    GetPage(name: AppRoutes.intro4TrainingNotTherapy, page: () => const IntroPage(4)),
    GetPage(name: AppRoutes.setup1YourName, page: () => const NamePage()),
    GetPage(name: AppRoutes.setup2MeditationReminder, page: () => const TimePage()),
    GetPage(name: AppRoutes.setup3Reminder, page: () => const ReminderPermissionPage()),
    GetPage(name: AppRoutes.howDoYouWantToStart, page: () => const StartPage()),
    GetPage(name: AppRoutes.purchaseStates, page: () => const PurchaseStatusPage()),
    GetPage(name: AppRoutes.trialStarted, page: () => const WelcomePage()),
    GetPage(name: AppRoutes.saveYourProgressOptional, page: () => const SaveProgressPage(free: false)),
    GetPage(name: AppRoutes.membershipPaywall, page: () => const PaywallPage()),
    GetPage(name: AppRoutes.restorePurchase, page: () => const RestorePage()),
    GetPage(name: AppRoutes.saveYourProgressFreeUser, page: () => const SaveProgressPage(free: true)),
    GetPage(name: AppRoutes.signUpWithEmail, page: () => const EmailSignUpPage()),
    GetPage(name: AppRoutes.logIn, page: () => const LoginPage()),
    GetPage(name: AppRoutes.forgotPassword, page: () => const ForgotPasswordPage()),
    GetPage(name: AppRoutes.checkYourEmail, page: () => const CheckEmailPage()),
    GetPage(name: AppRoutes.todayMember, page: () => const TodayPage()),
    GetPage(name: AppRoutes.motdRoom, page: () => const MotdRoomPage()),
    GetPage(name: AppRoutes.todayFree, page: () => const TodayFreePage()),
    GetPage(name: AppRoutes.worldMapWorldVibration, page: () => const WorldPage()),
    GetPage(name: AppRoutes.exploreArchive, page: () => const MembersOnly(title: 'Explore archive', child: ArchivePage())),
    GetPage(name: AppRoutes.dailyMessage, page: () => const DailyMessagePage()),
    GetPage(name: AppRoutes.notifications, page: () => const NotificationsPage()),
    GetPage(name: AppRoutes.sosHowCanIHelp, page: () => const SosPage()),
    GetPage(name: AppRoutes.library, page: () => const LibraryPage()),
    GetPage(name: AppRoutes.themePage, page: () => const ThemePage()),
    GetPage(name: AppRoutes.search, page: () => const SearchPage()),
    GetPage(name: AppRoutes.allPrograms, page: () => const ProgramsPage()),
    GetPage(name: AppRoutes.programDetail, page: () => const ProgramDetailPage()),
    GetPage(name: AppRoutes.teacherBio, page: () => const TeacherPage()),
    GetPage(name: AppRoutes.myMeditations, page: () => const MembersOnly(title: 'My Meditations', child: MyMeditationsPage())),
    GetPage(name: AppRoutes.buildYourOwn, page: () => const MembersOnly(title: 'Build your own', child: ByoPage())),
    GetPage(name: AppRoutes.buildYourOwnAdvanced, page: () => const MembersOnly(title: 'Build your own', child: ByoAdvancedPage())),
    GetPage(name: AppRoutes.sessionDetail, page: () => const SessionDetailPage()),
    GetPage(name: AppRoutes.playerPresenceRing, page: () => const PlayerPage()),
    GetPage(name: AppRoutes.videoPlayer, page: () => const VideoPlayerPage()),
    GetPage(name: AppRoutes.freePlayer, page: () => const FreePlayerPage()),
    GetPage(name: AppRoutes.meditationCompletePayoff, page: () => const CompletePage()),
    GetPage(name: AppRoutes.shareYourMeditation, page: () => const SharePage()),
    GetPage(name: AppRoutes.sessionDedications, page: () => const DedicationsPage()),
    GetPage(name: AppRoutes.silenceRoomSetup, page: () => const MembersOnly(title: 'Silence Room', child: SilenceSetupPage())),
    GetPage(name: AppRoutes.silenceRoomMeditating, page: () => const MembersOnly(title: 'Silence Room', child: SilenceRunPage())),
    GetPage(name: AppRoutes.together, page: () => const TogetherPage()),
    GetPage(name: AppRoutes.groupMeditationLobby, page: () => const LobbyPage()),
    GetPage(name: AppRoutes.you, page: () => const YouPage()),
    GetPage(name: AppRoutes.yourProgress, page: () => const ProgressPage()),
    GetPage(name: AppRoutes.editProfile, page: () => const EditProfilePage()),
    GetPage(name: AppRoutes.reminders, page: () => const RemindersPage()),
    GetPage(name: AppRoutes.downloads, page: () => const DownloadsPage()),
    GetPage(name: AppRoutes.privacyData, page: () => const PrivacyPage()),
    GetPage(name: AppRoutes.helpAbout, page: () => const HelpPage()),
    GetPage(name: AppRoutes.manageMembership, page: () => const ManageMembershipPage()),
    GetPage(name: AppRoutes.trialEnding, page: () => const TrialEndingPage()),
    GetPage(name: AppRoutes.billingIssue, page: () => const BillingIssuePage()),
    GetPage(name: AppRoutes.membershipEnded, page: () => const MembershipEndedPage()),
    GetPage(name: AppRoutes.offline, page: () => const OfflinePage()),
    GetPage(name: AppRoutes.updateRequired, page: () => const UpdateRequiredPage()),
    GetPage(name: AppRoutes.challenges, page: () => const ChallengesPage()),
    GetPage(name: AppRoutes.gratitude, page: () => const GratitudePage()),
    GetPage(name: AppRoutes.breathwork, page: () => const BreathworkPage()),
    GetPage(name: AppRoutes.breathPattern, page: () => const BreathPatternPage()),
    GetPage(name: AppRoutes.milestones, page: () => const MilestonesPage()),
    GetPage(name: AppRoutes.intent, page: () => const IntentPage()),
    GetPage(name: AppRoutes.maintenance, page: () => const MaintenancePage()),
    GetPage(name: AppRoutes.notFound, page: () => const NotFoundPage()),
    GetPage(name: AppRoutes.breathRun, page: () => const BreathRunPage()),
    GetPage(name: AppRoutes.pushPreview, page: () => const PushPreviewPage()),
    GetPage(name: AppRoutes.resetPassword, page: () => const ResetPasswordPage()),
    GetPage(name: AppRoutes.authLink, page: () => const AuthLinkPage()),
  ];
}

/// Premium screens opened directly (deep link, push, a stale route) by someone who is not a member: the lock, not the screen.
class MembersOnly extends StatelessWidget {
  const MembersOnly({super.key, required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Obx(() => Get.find<AccessService>().isMember ? child : AppScaffold(title: title, body: const MembersOnlyState()));
}
