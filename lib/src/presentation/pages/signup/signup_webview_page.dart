import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../../core/constants/app_strings.dart';
import '../../theme/theme_extensions.dart';
import '../../widgets/typography/app_text.dart';

/// In-app sign-up portal. The server renders the registration form itself, so
/// the app frames that page in a WebView and lets the user come back to login
/// from the header's back button or the system back gesture — the WebView
/// handles its own in-page back stack first.
class SignupWebViewPage extends StatefulWidget {
  const SignupWebViewPage({
    super.key,
    required this.url,
    required this.onClose,
  });

  final String url;
  final VoidCallback onClose;

  @override
  State<SignupWebViewPage> createState() => _SignupWebViewPageState();
}

class _SignupWebViewPageState extends State<SignupWebViewPage> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _loading = true;
  bool _errored = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (value) => setState(() => _progress = value),
          onPageStarted: (_) => setState(() {
            _loading = true;
            _errored = false;
          }),
          onPageFinished: (_) => setState(() => _loading = false),
          onWebResourceError: (error) {
            // The main-frame failures are what we want to show the user. Sub-
            // resource errors (favicon, trackers) are noisy and harmless.
            if (error.isForMainFrame ?? true) {
              setState(() {
                _loading = false;
                _errored = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    return true;
  }

  Future<void> _retry() async {
    setState(() {
      _errored = false;
      _loading = true;
      _progress = 0;
    });
    await _controller.reload();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final shouldLeave = await _handleBack();
        if (shouldLeave && mounted) widget.onClose();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: AppStrings.backToLogin,
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              final shouldLeave = await _handleBack();
              if (shouldLeave && mounted) widget.onClose();
            },
          ),
          title: const TitleText(AppStrings.signupTitle),
          actions: [
            IconButton(
              tooltip: AppStrings.reload,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _retry,
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: _loading ? 1 : 0,
              child: LinearProgressIndicator(
                minHeight: 3,
                value: _progress == 0 ? null : _progress / 100,
                backgroundColor: colors.surfaceContainer,
                valueColor: AlwaysStoppedAnimation(colors.primary),
              ),
            ),
          ),
        ),
        body: _errored
            ? _ErrorView(onRetry: _retry)
            : WebViewWidget(controller: _controller),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colors = context.color;
    return Center(
      child: Padding(
        padding: context.padding.page,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: context.sizes.iconXl,
              color: colors.textSecondary,
            ),
            SizedBox(height: context.spacing.lg),
            const HeadingMediumText(
              AppStrings.signupLoadFailedTitle,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: context.spacing.sm),
            BodyMediumText(
              AppStrings.signupLoadFailedBody,
              textAlign: TextAlign.center,
              color: colors.textSecondary,
            ),
            SizedBox(height: context.spacing.xl),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const LabelText(AppStrings.retry),
            ),
          ],
        ),
      ),
    );
  }
}
