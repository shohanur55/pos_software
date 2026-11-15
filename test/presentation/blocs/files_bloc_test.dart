import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pos_software/src/core/base/failure.dart';
import 'package:pos_software/src/core/base/result.dart';
import 'package:pos_software/src/domain/entities/remote_file_entity.dart';
import 'package:pos_software/src/domain/entities/remote_files_snapshot.dart';
import 'package:pos_software/src/domain/usecases/files/delete_remote_file_use_case.dart';
import 'package:pos_software/src/domain/usecases/files/get_cached_files_use_case.dart';
import 'package:pos_software/src/domain/usecases/files/refresh_remote_files_use_case.dart';
import 'package:pos_software/src/presentation/blocs/common/ui_notice.dart';
import 'package:pos_software/src/presentation/blocs/files/files_bloc.dart';

import '../../helpers/mocks.dart';

void main() {
  late MockRemoteFilesRepository repository;
  final syncedAt = DateTime(2026, 11, 14, 9);
  final older = RemoteFileEntity(
    name: 'old.csv',
    url: 'u1',
    uploadedAt: DateTime(2026),
  );
  final newer = RemoteFileEntity(
    name: 'new.csv',
    url: 'u2',
    uploadedAt: DateTime(2026, 2),
  );

  RemoteFilesSnapshot fresh(List<RemoteFileEntity> files) =>
      RemoteFilesSnapshot(files: files, fromCache: false, syncedAt: syncedAt);
  RemoteFilesSnapshot cached(List<RemoteFileEntity> files) =>
      RemoteFilesSnapshot(files: files, fromCache: true, syncedAt: syncedAt);

  setUp(() {
    repository = MockRemoteFilesRepository();
    when(() => repository.getCachedFiles())
        .thenAnswer((_) async => const Success(RemoteFilesSnapshot.empty()));
  });

  FilesBloc build() => FilesBloc(
    GetCachedFilesUseCase(repository),
    RefreshRemoteFilesUseCase(repository),
    DeleteRemoteFileUseCase(repository),
  );

  group('loading', () {
    blocTest<FilesBloc, FilesState>(
      'loads from the server when the cache is empty',
      setUp: () =>
          when(() => repository.refreshFiles())
              .thenAnswer((_) async => Success(fresh([newer, older]))),
      build: build,
      act: (bloc) => bloc.add(const FilesLoaded()),
      expect: () => [
        const FilesState(status: FilesStatus.loading),
        FilesState(
          status: FilesStatus.success,
          files: [newer, older],
          syncedAt: syncedAt,
        ),
      ],
    );

    blocTest<FilesBloc, FilesState>(
      'shows the cached list first, then the fresh one',
      setUp: () {
        when(() => repository.getCachedFiles())
            .thenAnswer((_) async => Success(cached([older])));
        when(() => repository.refreshFiles())
            .thenAnswer((_) async => Success(fresh([newer, older])));
      },
      build: build,
      act: (bloc) => bloc.add(const FilesLoaded()),
      expect: () => [
        const FilesState(status: FilesStatus.loading),
        FilesState(
          status: FilesStatus.success,
          files: [older],
          syncedAt: syncedAt,
          isStale: true,
          isRefreshing: true,
        ),
        FilesState(
          status: FilesStatus.success,
          files: [newer, older],
          syncedAt: syncedAt,
        ),
      ],
    );

    blocTest<FilesBloc, FilesState>(
      'keeps the cached list when the server cannot be reached',
      setUp: () {
        when(() => repository.getCachedFiles())
            .thenAnswer((_) async => Success(cached([older])));
        when(() => repository.refreshFiles())
            .thenAnswer((_) async => const Error(Failure(FailureKind.network)));
      },
      build: build,
      act: (bloc) => bloc.add(const FilesLoaded()),
      verify: (bloc) {
        expect(bloc.state.status, FilesStatus.success);
        expect(bloc.state.files, [older]);
        expect(bloc.state.isStale, isTrue);
        expect(bloc.state.isRefreshing, isFalse);
        expect(bloc.state.notice?.kind, FilesNoticeKind.refreshFailed);
      },
    );

    blocTest<FilesBloc, FilesState>(
      'fails only when there is nothing cached to fall back on',
      setUp: () => when(() => repository.refreshFiles())
          .thenAnswer((_) async => const Error(Failure(FailureKind.network))),
      build: build,
      act: (bloc) => bloc.add(const FilesLoaded()),
      expect: () => [
        const FilesState(status: FilesStatus.loading),
        const FilesState(
          status: FilesStatus.failure,
          failure: FailureKind.network,
        ),
      ],
    );
  });

  group('refreshing', () {
    blocTest<FilesBloc, FilesState>(
      'marks the list stale when a refresh fails',
      setUp: () => when(() => repository.refreshFiles())
          .thenAnswer((_) async => const Error(Failure(FailureKind.server))),
      build: build,
      seed: () => FilesState(
        status: FilesStatus.success,
        files: [older],
        syncedAt: syncedAt,
      ),
      act: (bloc) => bloc.add(const FilesRefreshed()),
      expect: () => [
        FilesState(
          status: FilesStatus.success,
          files: [older],
          syncedAt: syncedAt,
          isRefreshing: true,
        ),
        FilesState(
          status: FilesStatus.success,
          files: [older],
          syncedAt: syncedAt,
          isStale: true,
          notice: const UiNotice(
            FilesNoticeKind.refreshFailed,
            1,
            failure: FailureKind.server,
          ),
        ),
      ],
    );

    test('completes its completer even when nothing changed', () async {
      when(() => repository.refreshFiles())
          .thenAnswer((_) async => Success(fresh([older])));
      final bloc = build()
        ..emit(
          FilesState(
            status: FilesStatus.success,
            files: [older],
            syncedAt: syncedAt,
          ),
        );
      final completer = Completer<void>();
      bloc.add(FilesRefreshed(completer));
      await expectLater(completer.future, completes);
      expect(bloc.state.files, [older]);
      await bloc.close();
    });
  });

  group('deleting', () {
    blocTest<FilesBloc, FilesState>(
      'removes the row immediately',
      setUp: () =>
          when(() => repository.deleteFile('old.csv'))
              .thenAnswer((_) async => const Success(null)),
      build: build,
      seed: () =>
          FilesState(status: FilesStatus.success, files: [newer, older]),
      act: (bloc) => bloc.add(const FileDeleteRequested('old.csv')),
      expect: () => [
        FilesState(
          status: FilesStatus.success,
          files: [newer],
          deletingNames: const {'old.csv'},
        ),
        FilesState(
          status: FilesStatus.success,
          files: [newer],
          notice: const UiNotice(
            FilesNoticeKind.deleted,
            1,
            subject: 'old.csv',
          ),
        ),
      ],
    );

    blocTest<FilesBloc, FilesState>(
      'puts the row back when the server refuses',
      setUp: () => when(() => repository.deleteFile('new.csv'))
          .thenAnswer((_) async => const Error(Failure(FailureKind.network))),
      build: build,
      seed: () =>
          FilesState(status: FilesStatus.success, files: [newer, older]),
      act: (bloc) => bloc.add(const FileDeleteRequested('new.csv')),
      expect: () => [
        FilesState(
          status: FilesStatus.success,
          files: [older],
          deletingNames: const {'new.csv'},
        ),
        FilesState(
          status: FilesStatus.success,
          files: [newer, older],
          notice: const UiNotice(
            FilesNoticeKind.deleteFailed,
            1,
            failure: FailureKind.network,
            subject: 'new.csv',
          ),
        ),
      ],
    );
  });
}
