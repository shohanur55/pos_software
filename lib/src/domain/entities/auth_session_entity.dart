import 'package:equatable/equatable.dart';

class AuthSessionEntity extends Equatable {
  const AuthSessionEntity({
    required this.token,
    required this.tokenType,
    required this.expiresAt,
    required this.userId,
    required this.username,
  });

  final String token;
  final String tokenType;
  final DateTime expiresAt;
  final int userId;
  final String username;

  bool isExpiredAt(DateTime now) => !now.isBefore(expiresAt);

  bool get isExpired => isExpiredAt(DateTime.now());

  String get authorizationHeader => '$tokenType $token';

  @override
  List<Object?> get props => [token, tokenType, expiresAt, userId, username];
}
