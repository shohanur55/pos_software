part of 'files_bloc.dart';

sealed class FilesEvent extends Equatable {
  const FilesEvent();

  @override
  List<Object?> get props => [];
}

/// Shows the cached list, then asks the server for a fresh one.
final class FilesLoaded extends FilesEvent {
  const FilesLoaded();
}

/// Fetches from the server without clearing what is already on screen.
///
/// [completer] lets pull-to-refresh stop its indicator even when nothing
/// changed and no new state is emitted.
final class FilesRefreshed extends FilesEvent {
  const FilesRefreshed([this.completer]);

  final Completer<void>? completer;
}

final class FileDeleteRequested extends FilesEvent {
  const FileDeleteRequested(this.name);

  final String name;

  @override
  List<Object?> get props => [name];
}
