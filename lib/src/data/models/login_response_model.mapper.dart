// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format off
// ignore_for_file: type=lint
// ignore_for_file: invalid_use_of_protected_member
// ignore_for_file: unused_element, unnecessary_cast, override_on_non_overriding_member
// ignore_for_file: strict_raw_type, inference_failure_on_untyped_parameter

part of 'login_response_model.dart';

class LoginUserModelMapper extends ClassMapperBase<LoginUserModel> {
  LoginUserModelMapper._();

  static LoginUserModelMapper? _instance;
  static LoginUserModelMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LoginUserModelMapper._());
    }
    return _instance!;
  }

  @override
  final String id = 'LoginUserModel';

  static int _$id(LoginUserModel v) => v.id;
  static const Field<LoginUserModel, int> _f$id = Field('id', _$id);
  static String _$username(LoginUserModel v) => v.username;
  static const Field<LoginUserModel, String> _f$username = Field(
    'username',
    _$username,
  );

  @override
  final MappableFields<LoginUserModel> fields = const {
    #id: _f$id,
    #username: _f$username,
  };

  static LoginUserModel _instantiate(DecodingData data) {
    return LoginUserModel(id: data.dec(_f$id), username: data.dec(_f$username));
  }

  @override
  final Function instantiate = _instantiate;

  static LoginUserModel fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LoginUserModel>(map);
  }

  static LoginUserModel fromJson(String json) {
    return ensureInitialized().decodeJson<LoginUserModel>(json);
  }
}

mixin LoginUserModelMappable {
  String toJson() {
    return LoginUserModelMapper.ensureInitialized().encodeJson<LoginUserModel>(
      this as LoginUserModel,
    );
  }

  Map<String, dynamic> toMap() {
    return LoginUserModelMapper.ensureInitialized().encodeMap<LoginUserModel>(
      this as LoginUserModel,
    );
  }

  LoginUserModelCopyWith<LoginUserModel, LoginUserModel, LoginUserModel>
  get copyWith => _LoginUserModelCopyWithImpl<LoginUserModel, LoginUserModel>(
    this as LoginUserModel,
    $identity,
    $identity,
  );
  @override
  String toString() {
    return LoginUserModelMapper.ensureInitialized().stringifyValue(
      this as LoginUserModel,
    );
  }

  @override
  bool operator ==(Object other) {
    return LoginUserModelMapper.ensureInitialized().equalsValue(
      this as LoginUserModel,
      other,
    );
  }

  @override
  int get hashCode {
    return LoginUserModelMapper.ensureInitialized().hashValue(
      this as LoginUserModel,
    );
  }
}

extension LoginUserModelValueCopy<$R, $Out>
    on ObjectCopyWith<$R, LoginUserModel, $Out> {
  LoginUserModelCopyWith<$R, LoginUserModel, $Out> get $asLoginUserModel =>
      $base.as((v, t, t2) => _LoginUserModelCopyWithImpl<$R, $Out>(v, t, t2));
}

abstract class LoginUserModelCopyWith<$R, $In extends LoginUserModel, $Out>
    implements ClassCopyWith<$R, $In, $Out> {
  $R call({int? id, String? username});
  LoginUserModelCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _LoginUserModelCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LoginUserModel, $Out>
    implements LoginUserModelCopyWith<$R, LoginUserModel, $Out> {
  _LoginUserModelCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LoginUserModel> $mapper =
      LoginUserModelMapper.ensureInitialized();
  @override
  $R call({int? id, String? username}) => $apply(
    FieldCopyWithData({
      if (id != null) #id: id,
      if (username != null) #username: username,
    }),
  );
  @override
  LoginUserModel $make(CopyWithData data) => LoginUserModel(
    id: data.get(#id, or: $value.id),
    username: data.get(#username, or: $value.username),
  );

  @override
  LoginUserModelCopyWith<$R2, LoginUserModel, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _LoginUserModelCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

class LoginResponseModelMapper extends ClassMapperBase<LoginResponseModel> {
  LoginResponseModelMapper._();

  static LoginResponseModelMapper? _instance;
  static LoginResponseModelMapper ensureInitialized() {
    if (_instance == null) {
      MapperContainer.globals.use(_instance = LoginResponseModelMapper._());
      LoginUserModelMapper.ensureInitialized();
    }
    return _instance!;
  }

  @override
  final String id = 'LoginResponseModel';

  static bool _$success(LoginResponseModel v) => v.success;
  static const Field<LoginResponseModel, bool> _f$success = Field(
    'success',
    _$success,
    opt: true,
    def: false,
  );
  static LoginUserModel? _$user(LoginResponseModel v) => v.user;
  static const Field<LoginResponseModel, LoginUserModel> _f$user = Field(
    'user',
    _$user,
    opt: true,
  );
  static String? _$token(LoginResponseModel v) => v.token;
  static const Field<LoginResponseModel, String> _f$token = Field(
    'token',
    _$token,
    opt: true,
  );
  static String? _$tokenType(LoginResponseModel v) => v.tokenType;
  static const Field<LoginResponseModel, String> _f$tokenType = Field(
    'tokenType',
    _$tokenType,
    key: r'token_type',
    opt: true,
  );
  static int? _$expiresIn(LoginResponseModel v) => v.expiresIn;
  static const Field<LoginResponseModel, int> _f$expiresIn = Field(
    'expiresIn',
    _$expiresIn,
    key: r'expires_in',
    opt: true,
  );

  @override
  final MappableFields<LoginResponseModel> fields = const {
    #success: _f$success,
    #user: _f$user,
    #token: _f$token,
    #tokenType: _f$tokenType,
    #expiresIn: _f$expiresIn,
  };

  static LoginResponseModel _instantiate(DecodingData data) {
    return LoginResponseModel(
      success: data.dec(_f$success),
      user: data.dec(_f$user),
      token: data.dec(_f$token),
      tokenType: data.dec(_f$tokenType),
      expiresIn: data.dec(_f$expiresIn),
    );
  }

  @override
  final Function instantiate = _instantiate;

  static LoginResponseModel fromMap(Map<String, dynamic> map) {
    return ensureInitialized().decodeMap<LoginResponseModel>(map);
  }

  static LoginResponseModel fromJson(String json) {
    return ensureInitialized().decodeJson<LoginResponseModel>(json);
  }
}

mixin LoginResponseModelMappable {
  String toJson() {
    return LoginResponseModelMapper.ensureInitialized()
        .encodeJson<LoginResponseModel>(this as LoginResponseModel);
  }

  Map<String, dynamic> toMap() {
    return LoginResponseModelMapper.ensureInitialized()
        .encodeMap<LoginResponseModel>(this as LoginResponseModel);
  }

  LoginResponseModelCopyWith<
    LoginResponseModel,
    LoginResponseModel,
    LoginResponseModel
  >
  get copyWith =>
      _LoginResponseModelCopyWithImpl<LoginResponseModel, LoginResponseModel>(
        this as LoginResponseModel,
        $identity,
        $identity,
      );
  @override
  String toString() {
    return LoginResponseModelMapper.ensureInitialized().stringifyValue(
      this as LoginResponseModel,
    );
  }

  @override
  bool operator ==(Object other) {
    return LoginResponseModelMapper.ensureInitialized().equalsValue(
      this as LoginResponseModel,
      other,
    );
  }

  @override
  int get hashCode {
    return LoginResponseModelMapper.ensureInitialized().hashValue(
      this as LoginResponseModel,
    );
  }
}

extension LoginResponseModelValueCopy<$R, $Out>
    on ObjectCopyWith<$R, LoginResponseModel, $Out> {
  LoginResponseModelCopyWith<$R, LoginResponseModel, $Out>
  get $asLoginResponseModel => $base.as(
    (v, t, t2) => _LoginResponseModelCopyWithImpl<$R, $Out>(v, t, t2),
  );
}

abstract class LoginResponseModelCopyWith<
  $R,
  $In extends LoginResponseModel,
  $Out
>
    implements ClassCopyWith<$R, $In, $Out> {
  LoginUserModelCopyWith<$R, LoginUserModel, LoginUserModel>? get user;
  $R call({
    bool? success,
    LoginUserModel? user,
    String? token,
    String? tokenType,
    int? expiresIn,
  });
  LoginResponseModelCopyWith<$R2, $In, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  );
}

class _LoginResponseModelCopyWithImpl<$R, $Out>
    extends ClassCopyWithBase<$R, LoginResponseModel, $Out>
    implements LoginResponseModelCopyWith<$R, LoginResponseModel, $Out> {
  _LoginResponseModelCopyWithImpl(super.value, super.then, super.then2);

  @override
  late final ClassMapperBase<LoginResponseModel> $mapper =
      LoginResponseModelMapper.ensureInitialized();
  @override
  LoginUserModelCopyWith<$R, LoginUserModel, LoginUserModel>? get user =>
      $value.user?.copyWith.$chain((v) => call(user: v));
  @override
  $R call({
    bool? success,
    Object? user = $none,
    Object? token = $none,
    Object? tokenType = $none,
    Object? expiresIn = $none,
  }) => $apply(
    FieldCopyWithData({
      if (success != null) #success: success,
      if (user != $none) #user: user,
      if (token != $none) #token: token,
      if (tokenType != $none) #tokenType: tokenType,
      if (expiresIn != $none) #expiresIn: expiresIn,
    }),
  );
  @override
  LoginResponseModel $make(CopyWithData data) => LoginResponseModel(
    success: data.get(#success, or: $value.success),
    user: data.get(#user, or: $value.user),
    token: data.get(#token, or: $value.token),
    tokenType: data.get(#tokenType, or: $value.tokenType),
    expiresIn: data.get(#expiresIn, or: $value.expiresIn),
  );

  @override
  LoginResponseModelCopyWith<$R2, LoginResponseModel, $Out2> $chain<$R2, $Out2>(
    Then<$Out2, $R2> t,
  ) => _LoginResponseModelCopyWithImpl<$R2, $Out2>($value, $cast, t);
}

