/// Never log tokens, email or dedication text (spec §6.1). Used by the logger and the Sentry beforeSend.
final _jwt = RegExp(r'eyJ[\w-]{5,}\.[\w-]{5,}\.[\w-]{5,}');
final _bearer = RegExp(r'Bearer\s+[\w.\-]+', caseSensitive: false);
final _email = RegExp(r'[\w.+\-]+@[\w\-]+\.[\w.\-]+');

String redact(String s) => s.replaceAll(_jwt, '[token]').replaceAll(_bearer, 'Bearer [token]').replaceAll(_email, '[email]');
