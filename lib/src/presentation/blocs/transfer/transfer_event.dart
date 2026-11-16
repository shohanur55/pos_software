part of 'transfer_bloc.dart';

sealed class TransferEvent extends Equatable {
  const TransferEvent();

  @override
  List<Object?> get props => [];
}

/// Loads history and subscribes to live updates.
final class TransfersStarted extends TransferEvent {
  const TransfersStarted();
}

/// Re-reads native state, e.g. when the app returns to the foreground.
final class TransfersResynced extends TransferEvent {
  const TransfersResynced();
}

final class DownloadStarted extends TransferEvent {
  const DownloadStarted(this.file);

  final RemoteFileEntity file;

  @override
  List<Object?> get props => [file];
}

final class TransferPaused extends TransferEvent {
  const TransferPaused(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

final class TransferResumed extends TransferEvent {
  const TransferResumed(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

final class TransferCanceled extends TransferEvent {
  const TransferCanceled(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

final class TransferRetried extends TransferEvent {
  const TransferRetried(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

final class TransferRemoved extends TransferEvent {
  const TransferRemoved(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

final class TransferOpened extends TransferEvent {
  const TransferOpened(this.id);

  final String id;

  @override
  List<Object?> get props => [id];
}

final class FinishedTransfersCleared extends TransferEvent {
  const FinishedTransfersCleared();
}

/// The device is back online: transfers that died on the network are retried once.
final class ConnectionRestored extends TransferEvent {
  const ConnectionRestored();
}

/// The user has seen the current failures (opened Transfers or dismissed).
final class TransferFailuresAcknowledged extends TransferEvent {
  const TransferFailuresAcknowledged();
}
