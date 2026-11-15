/// Runtime values the presentation layer may show but must not own.
class AppConfig {
  const AppConfig({required this.serverAddress});

  /// Address of the server and its web portal, for display only.
  final String serverAddress;
}
