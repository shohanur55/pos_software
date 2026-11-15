import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/usecases/system/watch_connectivity_use_case.dart';

enum ConnectivityStatus { online, offline }

class ConnectivityCubit extends Cubit<ConnectivityStatus> {
  ConnectivityCubit(this._watchConnectivity) : super(ConnectivityStatus.online);

  final WatchConnectivityUseCase _watchConnectivity;
  StreamSubscription<bool>? _subscription;

  Future<void> start() async {
    if (_subscription != null) return;
    _subscription = _watchConnectivity().listen(_update);
    _update(await _watchConnectivity.current());
  }

  void _update(bool online) {
    if (isClosed) return;
    emit(online ? ConnectivityStatus.online : ConnectivityStatus.offline);
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    return super.close();
  }
}
