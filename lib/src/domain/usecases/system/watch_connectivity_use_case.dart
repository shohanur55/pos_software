import '../../services/connectivity_service.dart';

final class WatchConnectivityUseCase {
  WatchConnectivityUseCase(this.service);

  final ConnectivityService service;

  Future<bool> current() => service.isOnline();

  Stream<bool> call() => service.watchOnline();
}
