import '../../app/routes/app_routes.dart';

/// Where a link or push payload leads. `args` go to `Get.toNamed(arguments:)`.
class LinkTarget {
  const LinkTarget(this.route, [this.args = const {}]);
  final String route;
  final Map<String, String> args;
  @override
  bool operator ==(Object other) => other is LinkTarget && other.route == route && '${other.args}' == '$args';
  @override
  int get hashCode => Object.hash(route, '$args');
  @override
  String toString() => 'LinkTarget($route, $args)';
}

/// `wehum://today|group|membership|session/{id}|program/{id}`, `https://wehum.app/r/{slug}` (recipe) and
/// push `deepLink` values (spec §6.1, §12). Unknown links go to the "not found" screen, never crash.
abstract final class DeepLinks {
  static LinkTarget parse(String? link) {
    if (link == null || link.trim().isEmpty) return const LinkTarget(AppRoutes.todayMember);
    final uri = Uri.tryParse(link.trim());
    if (uri == null) return const LinkTarget(AppRoutes.notFound);
    final isApp = uri.scheme == 'wehum';
    final isWeb = (uri.scheme == 'https' || uri.scheme == 'http') && (uri.host == 'wehum.app' || uri.host == 'www.wehum.app');
    if (!isApp && !isWeb) return const LinkTarget(AppRoutes.notFound);
    // wehum://session/123 → host "session", path "/123"; https://wehum.app/r/abc → segments [r, abc]
    final segs = isApp ? [if (uri.host.isNotEmpty) uri.host, ...uri.pathSegments] : uri.pathSegments;
    if (segs.isEmpty) return const LinkTarget(AppRoutes.todayMember);
    final id = segs.length > 1 ? segs[1] : null;
    switch (segs.first) {
      case 'today':
        return const LinkTarget(AppRoutes.todayMember);
      case 'group':
        return const LinkTarget(AppRoutes.groupMeditationLobby);
      case 'membership':
        return const LinkTarget(AppRoutes.membershipPaywall);
      case 'session':
        return id == null ? const LinkTarget(AppRoutes.notFound) : LinkTarget(AppRoutes.sessionDetail, {'id': id});
      case 'program':
        return id == null ? const LinkTarget(AppRoutes.notFound) : LinkTarget(AppRoutes.programDetail, {'id': id});
      case 'r':
        return id == null ? const LinkTarget(AppRoutes.notFound) : LinkTarget(AppRoutes.buildYourOwn, {'slug': id});
      case 'auth':
        // https://wehum.app/auth/{sign-in|reset-password|verify-email}?token=…  (the API's email templates)
        final token = uri.queryParameters['token'];
        if (token == null || token.isEmpty || id == null) return const LinkTarget(AppRoutes.notFound);
        return switch (id) {
          'sign-in' => LinkTarget(AppRoutes.authLink, {'kind': 'sign-in', 'token': token}),
          'verify-email' => LinkTarget(AppRoutes.authLink, {'kind': 'verify-email', 'token': token}),
          'reset-password' => LinkTarget(AppRoutes.resetPassword, {'token': token}),
          _ => const LinkTarget(AppRoutes.notFound),
        };
      case 'message':
        return LinkTarget(AppRoutes.dailyMessage, {'date': id ?? ''});
      default:
        return const LinkTarget(AppRoutes.notFound);
    }
  }
}
