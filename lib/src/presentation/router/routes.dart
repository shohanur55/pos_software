abstract final class Routes {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String home = '/home';
  static const String upload = '/home/upload';
  static const String files = '/home/files';
  static const String transfers = '/home/transfers';

  static const String splashName = 'splash';
  static const String loginName = 'login';
  static const String uploadName = 'upload';
  static const String filesName = 'files';
  static const String transfersName = 'transfers';

  /// Query parameter that asks the Transfers page to focus one item.
  static const String highlightParam = 'highlight';

  /// Changes on every request, so asking for the same item twice in a row
  /// still scrolls to it.
  static const String highlightTokenParam = 'request';

  static String transfersFor(String transferId, {int token = 0}) => Uri(
    path: transfers,
    queryParameters: {
      highlightParam: transferId,
      highlightTokenParam: '$token',
    },
  ).toString();
}
