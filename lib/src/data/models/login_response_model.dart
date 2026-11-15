import 'package:dart_mappable/dart_mappable.dart';

import 'auth_session_model.dart';

part 'login_response_model.mapper.dart';

@MappableClass(caseStyle: CaseStyle.snakeCase)
class LoginUserModel with LoginUserModelMappable {
  const LoginUserModel({required this.id, required this.username});

  final int id;
  final String username;
}

@MappableClass(caseStyle: CaseStyle.snakeCase)
class LoginResponseModel with LoginResponseModelMappable {
  const LoginResponseModel({
    this.success = false,
    this.user,
    this.token,
    this.tokenType,
    this.expiresIn,
  });

  final bool success;
  final LoginUserModel? user;
  final String? token;
  final String? tokenType;
  final int? expiresIn;

  static LoginResponseModel fromMap(Map<String, dynamic> map) =>
      LoginResponseModelMapper.fromMap(map);

  /// Builds a session, or `null` when the response is not a usable login.
  AuthSessionModel? toSession(DateTime now) {
    final token = this.token;
    final user = this.user;
    if (!success || token == null || token.isEmpty || user == null) return null;
    return AuthSessionModel(
      token: token,
      tokenType: (tokenType == null || tokenType!.isEmpty)
          ? 'Bearer'
          : tokenType!,
      expiresAt: now.add(Duration(seconds: expiresIn ?? 86400)),
      userId: user.id,
      username: user.username,
    );
  }
}
