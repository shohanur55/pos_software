enum TransferStatus {
  queued,
  running,
  paused,
  waitingToRetry,
  completed,
  failed,
  canceled;

  bool get isActive =>
      this == queued || this == running || this == waitingToRetry;

  bool get isFinished =>
      this == completed || this == failed || this == canceled;

  /// Active or paused: the transfer still occupies its remote file.
  bool get isInProgress => isActive || this == paused;

  bool get canPause =>
      this == running || this == queued || this == waitingToRetry;

  bool get canResume => this == paused;

  bool get canRetry => this == failed || this == canceled;

  bool get canCancel => isActive || this == paused;
}
