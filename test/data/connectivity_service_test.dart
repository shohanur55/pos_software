import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_software/src/data/services/system/connectivity_service_impl.dart';
import 'package:pos_software/src/data/services/system/server_reachability.dart';

class MockConnectivity extends Mock implements Connectivity {}

class MockServerReachability extends Mock implements ServerReachability {}

void main() {
  late MockConnectivity connectivity;
  late MockServerReachability reachability;
  late StreamController<List<ConnectivityResult>> interface;
  late ConnectivityServiceImpl service;

  void interfaceReports(List<ConnectivityResult> results) {
    when(connectivity.checkConnectivity).thenAnswer((_) async => results);
  }

  void serverReachable({required bool yes}) {
    when(reachability.canReachServer).thenAnswer((_) async => yes);
  }

  /// Lets the asynchronous probe behind each event finish.
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 1));

  setUp(() {
    connectivity = MockConnectivity();
    reachability = MockServerReachability();
    interface = StreamController<List<ConnectivityResult>>.broadcast();
    when(() => connectivity.onConnectivityChanged)
        .thenAnswer((_) => interface.stream);
    service = ConnectivityServiceImpl(
      connectivity: connectivity,
      reachability: reachability,
      recheckInterval: const Duration(milliseconds: 20),
    );
  });

  tearDown(() => interface.close());

  test('no interface at all is offline without asking the server', () async {
    interfaceReports([ConnectivityResult.none]);
    serverReachable(yes: true);

    expect(await service.isOnline(), isFalse);
    verifyNever(reachability.canReachServer);
  });

  test(
    'an interface the server cannot be reached through is offline',
    () async {
      // The shape of a captive portal, or a router whose uplink is down: Wi-Fi
      // is associated and nothing can be reached through it.
      interfaceReports([ConnectivityResult.wifi]);
      serverReachable(yes: false);

      expect(await service.isOnline(), isFalse);
    },
  );

  test('a reachable server is online', () async {
    interfaceReports([ConnectivityResult.wifi]);
    serverReachable(yes: true);

    expect(await service.isOnline(), isTrue);
  });

  test(
    'the stream reports offline, then online once the route comes back',
    () async {
      interfaceReports([ConnectivityResult.wifi]);
      serverReachable(yes: false);

      final seen = <bool>[];
      final subscription = service.watchOnline().listen(seen.add);
      await settle();
      expect(seen, [false]);

      // No platform event fires when a captive portal is signed in, so the only
      // way back is the recheck.
      serverReachable(yes: true);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(seen, [false, true]);
      await subscription.cancel();
    },
  );

  test('an unchanged verdict is not emitted twice', () async {
    interfaceReports([ConnectivityResult.wifi]);
    serverReachable(yes: true);

    final seen = <bool>[];
    final subscription = service.watchOnline().listen(seen.add);
    await settle();
    interface.add([ConnectivityResult.mobile]);
    await settle();

    expect(seen, [true]);
    await subscription.cancel();
  });
}
