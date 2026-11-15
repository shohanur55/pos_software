import 'package:logger/logger.dart';

/// Shared logger. Never pass tokens or authorization headers to it.
final Logger logger = Logger(
  printer: PrettyPrinter(methodCount: 0, errorMethodCount: 5, lineLength: 100),
);
