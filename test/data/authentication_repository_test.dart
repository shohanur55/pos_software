import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_software/src/core/base/failure.dart';
import 'package:pos_software/src/core/base/result.dart';
import 'package:pos_software/src/data/repositories/authentication_repository_impl.dart';
import 'package:pos_software/src/data/services/cache/session_storage.dart';
import 'package:pos_software/src/data/services/network/endpoints.dart';
import 'package:pos_software/src/data/services/network/rest_client.dart';
import 'package:pos_software/src/data/services/network/session_events.dart';
import 'package:pos_software/src/domain/services/external_link_service.dart';

class _MockRestClient extends Mock implements RestClient {}

class _MockSessionStorage extends Mock implements SessionStorage {}

class _MockExternalLinkService extends Mock implements ExternalLinkService {}

void main() {
  late _MockExternalLinkService links;
  late AuthenticationRepositoryImpl repository;

  setUp(() {
    links = _MockExternalLinkService();
    repository = AuthenticationRepositoryImpl(
      _MockRestClient(),
      _MockSessionStorage(),
      SessionEvents(),
      links,
    );
  });

  group('openRegistrationPortal', () {
    test('opens the one configured server address', () async {
      when(() => links.open(any())).thenAnswer((_) async => true);

      final result = await repository.openRegistrationPortal();

      expect(result, isA<Success<void, Failure>>());
      verify(() => links.open(Endpoints.baseUrl)).called(1);
    });

    test('fails when no browser accepts the URL', () async {
      when(() => links.open(any())).thenAnswer((_) async => false);

      final result = await repository.openRegistrationPortal();

      expect(
        result,
        isA<Error<void, Failure>>().having(
          (error) => error.error.kind,
          'kind',
          FailureKind.cannotOpen,
        ),
      );
    });
  });
}
