/// Why a transfer is sitting in `TransferStatus.paused`.
///
/// The distinction matters twice: the operator is told which of the two
/// happened, and only [noNetwork] transfers start again by themselves once
/// the connection is back. A transfer the operator paused on purpose stays
/// paused until they say otherwise.
enum TransferPauseReason {
  /// The operator tapped Pause.
  user,

  /// The route to the server went away, so the app parked the transfer to
  /// keep the bytes it had already moved instead of letting the retries burn
  /// out and lose them.
  noNetwork,
}
