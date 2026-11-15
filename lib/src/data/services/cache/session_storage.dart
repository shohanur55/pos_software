import '../../../core/constants/storage_keys.dart';
import '../../models/auth_session_model.dart';
import 'cache_service.dart';

class SessionStorage {
  SessionStorage(this._cache);

  final CacheService _cache;

  AuthSessionModel? read() {
    final json = _cache.readJson(StorageKeys.session);
    if (json == null) return null;
    try {
      return AuthSessionModel.fromMap(json);
    } on Object {
      return null;
    }
  }

  Future<void> write(AuthSessionModel session) =>
      _cache.writeJson(StorageKeys.session, session.toMap());

  Future<void> clear() => _cache.remove(StorageKeys.session);
}
