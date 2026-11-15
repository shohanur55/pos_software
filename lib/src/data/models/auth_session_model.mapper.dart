// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'auth_session_model.dart';

class AuthSessionModelMapper extends ClassMapperBase<AuthSessionModel> {
  AuthSessionModelMapper._();

  static AuthSessionModelMapper? _instance;
  static AuthSessionModelMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = AuthSessionModelMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'AuthSessionModel';

  static String _$token(AuthSessionModel v) => v.token;
  static const Field<AuthSessionModel, String> _f$token = Field(
    'token',
    _$token,
  );
  static String _$tokenType(AuthSessionModel v) => v.tokenType;
  static const Field<AuthSessionModel, String> _f$tokenType = Field(
    'tokenType',
    _$tokenType,
  );
  static DateTime _$expiresAt(AuthSessionModel v) => v.expiresAt;
  static const Field<AuthSessionModel, DateTime> _f$expiresAt = Field(
    'expiresAt',
    _$expiresAt,
  );
  static int _$userId(AuthSessionModel v) => v.userId;
  static const Field<AuthSessionModel, int> _f$userId = Field(
    'userId',
    _$userId,
  );
  static String _$username(AuthSessionModel v) => v.username;
  static const Field<AuthSessionModel, String> _f$username = Field(
    'username',
    _$username,
  );

  @override
  final MappableFields<AuthSessionModel> fields = const {
    #token: _f$token,
    #tokenType: _f$tokenType,
    #expiresAt: _f$expiresAt,
    #userId: _f$userId,
    #username: _f$username,
  };

  static AuthSessionModel _instantiate(DecodingData data) {
    return AuthSessionModel(
      token: data.dec(_f$token),
      tokenType: data.dec(_f$tokenType),
      expiresAt: data.dec(_f$expiresAt),
      userId: data.dec(_f$userId),
      username: data.dec(_f$username),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static AuthSessionModel fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<AuthSessionModel>(map);
  }

  static AuthSessionModel fromJson(String json) {
    return ensureInitialized().decodeJson<AuthSessionModel>(json);
  }
}

mixin AuthSessionModelMappable {
  String toJson() {
    return AuthSessionModelMapper.ensureInitialized()
        .encodeJson<AuthSessionModel>(this as AuthSessionModel);
  }

  Map<String, dynamic> toMap() {
    return AuthSessionModelMapper.ensureInitialized()
        .encodeMap<AuthSessionModel>(this as AuthSessionModel);
  }

  AuthSessionModelCopyWith<AuthSessionModel, AuthSessionModel, AuthSessionModel>
  get copyWith =>
      _AuthSessionModelCopyWithImpl<AuthSessionModel, AuthSessionModel>(
        this as AuthSessionModel,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return AuthSessionModelMapper.ensureInitialized().stringifyValue(
      this as AuthSessionModel,
    );
  }

  @override
  bool operator ==(Object other) {
    return AuthSessionModelMapper.ensureInitialized().equalsValue(
      this as AuthSessionModel,
      other,
    );
  }

  @override
  int get hashCode {
    return AuthSessionModelMapper.ensureInitialized().hashValue(
      this as AuthSessionModel,
    );
  }
}

extension AuthSessionModelValueCopy<$R, $Out>
    on ObjectCopyWith<$R, AuthSessionModel, $Out> {
  AuthSessionModelCopyWith<$R, AuthSessionModel, $Out>
  get $asAuthSessionModel =>
      $base.as((v, t, t2) => _AuthSessionModelCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class AuthSessionModelCopyWith<$R, $In extends AuthSessionModel, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({
    String? token,
    String? tokenType,
    DateTime? expiresAt,
    int? userId,
    String? username,
  });
  AuthSessionModelCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _AuthSessionModelCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, AuthSessionModel, $Out>
    implements AuthSessionModelCopyWith<$R, AuthSessionModel, $Out> {
  _AuthSessionModelCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<AuthSessionModel> $mapper =
      AuthSessionModelMapper.ensureInitialized();
  @override
  $R call({
    String? token,
    String? tokenType,
    DateTime? expiresAt,
    int? userId,
    String? username,
  }) => $apply(
    FieldCopyWithData({
      if (token != null) #token: token,
      if (tokenType != null) #tokenType: tokenType,
      if (expiresAt != null) #expiresAt: expiresAt,
      if (userId != null) #userId: userId,
      if (username != null) #username: username,
    }),
  );
  @override
  AuthSessionModel $make(CopyWithData data) => AuthSessionModel(
    token: data.get(#token, or: $value.token),
    tokenType: data.get(#tokenType, or: $value.tokenType),
    expiresAt: data.get(#expiresAt, or: $value.expiresAt),
    userId: data.get(#userId, or: $value.userId),
    username: data.get(#username, or: $value.username),
  );

  @override
  AuthSessionModelCopyWith<$R2, AuthSessionModel, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _AuthSessionModelCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

