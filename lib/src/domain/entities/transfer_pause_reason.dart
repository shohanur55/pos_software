/// Why a transfer is paused. Only [noNetwork] transfers resume by themselves
/// once the connection is back; a user-paused one stays paused until resumed.
enum TransferPauseReason {
  /// The operator tapped Pause.
  user,

  /// The server became unreachable, so the app parked the transfer to keep the
  /// bytes already moved instead of letting the retries burn out.
  noNetwork,
}
