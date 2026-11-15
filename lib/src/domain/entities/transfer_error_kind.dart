enum TransferErrorKind {
  network,
  unauthorized,
  fileTooLarge,
  invalidFile,
  notFound,
  server,
  storage,

  /// The transfer could not continue from its offset and started over.
  resumeFailed,

  /// The endpoint has no way to continue an interrupted upload, so the file
  /// is being sent again from the beginning.
  resumeNotSupported,
  unknown,
}
