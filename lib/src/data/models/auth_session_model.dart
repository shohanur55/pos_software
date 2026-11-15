import 'package:dart_mappable/dart_mappable.dart';

import '../../domain/entities/auth_session_entity.dart';

part 'auth_session_model.mapper.dart';

@MappableClass()
class AuthSessionModel extends AuthSessionEntity with AuthSessionModelMappable {
  const AuthSessionModel({
    required super.token,
    required super.tokenType,
    required super.expiresAt,
    required super.userId,
    required super.username,
  });

  factory AuthSessionModel.fromEntity(AuthSessionEntity entity) =>
      AuthSessionModel(
        token: entity.token,
        tokenType: entity.tokenType,
        expiresAt: entity.expiresAt,
        userId: entity.userId,
        username: entity.username,
      );

  static AuthSessionModel fromMap(Map<String, dynamic> map) =>
      AuthSessionModelMapper.fromMap(map);
}
