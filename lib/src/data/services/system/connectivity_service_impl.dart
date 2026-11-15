import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../domain/services/connectivity_service.dart';

class ConnectivityServiceImpl implements ConnectivityService {
  ConnectivityServiceImpl([Connectivity? connectivity])
    : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  @override
  Future<bool> isOnline() async =>
      _isOnline(await _connectivity.checkConnectivity());

  @override
  Stream<bool> watchOnline() =>
      _connectivity.onConnectivityChanged.map(_isOnline).distinct();

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((result) => result != ConnectivityResult.none);
}
