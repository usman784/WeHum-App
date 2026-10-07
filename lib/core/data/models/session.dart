/// Result of /v1/auth/guest, /refresh and social sign-in.
class AuthSession {
  const AuthSession({required this.accessToken, required this.refreshToken, required this.me});
  final String accessToken;
  final String refreshToken;
  final Me me;

  factory AuthSession.fromJson(Map<String, dynamic> j) => AuthSession(
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
        me: Me.fromJson((j['me'] as Map).cast<String, dynamic>()),
      );
}

class Me {
  const Me({required this.id, required this.isGuest, this.firstName, this.theme = 'system', this.timezone});
  final String id;
  final bool isGuest;
  final String? firstName;
  final String theme;
  final String? timezone;

  factory Me.fromJson(Map<String, dynamic> j) => Me(
        id: j['id'] as String,
        isGuest: j['isGuest'] as bool? ?? true,
        firstName: j['firstName'] as String?,
        theme: j['theme'] as String? ?? 'system',
        timezone: j['timezone'] as String?,
      );
}
