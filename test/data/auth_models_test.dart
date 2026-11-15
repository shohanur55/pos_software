import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pos_software/src/data/models/auth_session_model.dart';
import 'package:pos_software/src/data/models/login_response_model.dart';

void main() {
  final now = DateTime.utc(2026, 11, 13, 14, 43);

  group('LoginResponseModel', () {
    // The exact body documented by the API.
    const documented = '''
    {
      "success": true,
      "user": { "id": 5, "username": "cashier", "created_at": "2026-11-13T14:43:00+00:00" },
      "token": "abc.def.ghi",
      "token_type": "Bearer",
      "expires_in": 86400
    }''';

    test('parses the documented login response into a 24 h session', () {
      final response = LoginResponseModel.fromMap(
        jsonDecode(documented) as Map<String, dynamic>,
      );
      final session = response.toSession(now);

      expect(session, isNotNull);
      expect(session!.token, 'abc.def.ghi');
      expect(session.tokenType, 'Bearer');
      expect(session.userId, 5);
      expect(session.username, 'cashier');
      expect(session.expiresAt, now.add(const Duration(hours: 24)));
      expect(session.authorizationHeader, 'Bearer abc.def.ghi');
      expect(session.isExpiredAt(now), isFalse);
      expect(session.isExpiredAt(now.add(const Duration(hours: 24))), isTrue);
    });

    test('defaults the token type and lifetime when they are missing', () {
      final session = LoginResponseModel.fromMap({
        'success': true,
        'user': {'id': 1, 'username': 'a'},
        'token': 't',
      }).toSession(now);
      expect(session?.tokenType, 'Bearer');
      expect(session?.expiresAt, now.add(const Duration(seconds: 86400)));
    });

    test('is not a session when unsuccessful or incomplete', () {
      expect(
        LoginResponseModel.fromMap({'success': false, 'error': 'bad'})
            .toSession(now),
        isNull,
      );
      expect(
        LoginResponseModel.fromMap({'success': true, 'token': 't'})
            .toSession(now),
        isNull,
      );
      expect(
        LoginResponseModel.fromMap({
          'success': true,
          'token': '',
          'user': {'id': 1, 'username': 'a'},
        }).toSession(now),
        isNull,
      );
    });
  });

  test('a session survives being stored as JSON text', () {
    final session = AuthSessionModel(
      token: 't',
      tokenType: 'Bearer',
      expiresAt: now.add(const Duration(hours: 24)),
      userId: 5,
      username: 'cashier',
    );
    final restored = AuthSessionModel.fromMap(
      jsonDecode(jsonEncode(session.toMap())) as Map<String, dynamic>,
    );
    expect(restored.token, session.token);
    expect(restored.tokenType, session.tokenType);
    expect(restored.userId, session.userId);
    expect(restored.username, session.username);
    expect(restored.expiresAt.isAtSameMomentAs(session.expiresAt), isTrue);
  });
}
