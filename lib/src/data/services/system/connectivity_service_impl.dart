import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../../../domain/services/connectivity_service.dart';
import 'server_reachability.dart';

/// Reports whether the server can actually be reached, not merely whether a
/// network interface is up. See [ServerReachability] for why that matters.
class ConnectivityServiceImpl implements ConnectivityService {
  ConnectivityServiceImpl({
    Connectivity? connectivity,
    ServerReachability? reachability,
    Duration recheckInterval = const Duration(seconds: 15),
  }) : _connectivity = connectivity ?? Connectivity(),
       _reachability = reachability ?? ServerReachability(),
       // ignore: prefer_initializing_formals
       _recheckInterval = recheckInterval;

  final Connectivity _connectivity;
  final ServerReachability _reachability;
  final Duration _recheckInterval;

  @override
  Future<bool> isOnline() async {
    if (!await _hasLink()) return false;
    return _reachability.canReachServer();
  }

  @override
  Stream<bool> watchOnline() {
    late final StreamController<bool> controller;
    StreamSubscription<List<ConnectivityResult>>? link;
    Timer? recheck;
    bool? last;
    var evaluating = false;

    Future<void> evaluate() async {
      // Platform events can arrive while a probe is in flight; one probe at a
      // time is enough and the trailing recheck covers whatever changed.
      if (evaluating || controller.isClosed) return;
      evaluating = true;
      try {
        final online = await isOnline();
        if (controller.isClosed) return;
        if (online != last) {
          last = online;
          controller.add(online);
        }
        recheck?.cancel();
        // A live interface with no route produces no further platform events,
        // so the only way back is to keep asking.
        if (!online && await _hasLink() && !controller.isClosed) {
          recheck = Timer(_recheckInterval, evaluate);
        }
      } finally {
        evaluating = false;
      }
    }

    controller = StreamController<bool>(
      onListen: () {
        link = _connectivity.onConnectivityChanged.listen((_) => evaluate());
        evaluate();
      },
      onCancel: () async {
        recheck?.cancel();
        await link?.cancel();
      },
    );
    return controller.stream;
  }

  Future<bool> _hasLink() async {
    final results = await _connectivity.checkConnectivity();
    return results.any((result) => result != ConnectivityResult.none);
  }
}
