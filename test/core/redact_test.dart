import 'package:flutter_test/flutter_test.dart';
import 'package:meditation/core/utils/redact.dart';

void main() {
  test('tokens and emails never reach logs', () {
    const jwt = 'eyJhbGciOiJSUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.c2lnbmF0dXJlLWJ5dGVz';
    expect(redact('token $jwt end'), 'token [token] end');
    expect(redact('Authorization: Bearer abc.def-123'), 'Authorization: Bearer [token]');
    expect(redact('mail lena.berg+x@example.co.uk now'), 'mail [email] now');
    expect(redact('nothing secret'), 'nothing secret');
  });
}
