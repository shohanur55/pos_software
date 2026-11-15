import 'package:url_launcher/url_launcher.dart';

import '../../../domain/services/external_link_service.dart';

class ExternalLinkServiceImpl implements ExternalLinkService {
  @override
  Future<bool> open(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return false;
    // The portal is a full web app, so it belongs in the browser rather than
    // an in-app view that has no address bar and no saved passwords.
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
