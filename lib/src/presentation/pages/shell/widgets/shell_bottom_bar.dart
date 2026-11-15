import 'package:flutter/material.dart';

import 'shell_status_banners.dart';
import 'transfer_mini_banner.dart';

/// Everything that sits under the page: the status banner, the transfer
/// summary and, on compact widths, the navigation bar.
///
/// It lives in `Scaffold.bottomNavigationBar` rather than in the body so a
/// floating snack bar is laid out above it instead of covering the banners.
class ShellBottomBar extends StatelessWidget {
  const ShellBottomBar({
    super.key,
    required this.showMiniBanner,
    required this.onOpenTransfers,
    this.navigationBar,
  });

  final bool showMiniBanner;
  final VoidCallback onOpenTransfers;

  /// `null` on wide layouts, where a navigation rail replaces it.
  final Widget? navigationBar;

  @override
  Widget build(BuildContext context) {
    final banners = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const ShellStatusBanner(),
        if (showMiniBanner)
          TransferMiniBanner(onOpenTransfers: onOpenTransfers),
      ],
    );
    final bar = navigationBar;
    if (bar == null) {
      // Nothing below the banners, so they take the bottom inset themselves.
      return SafeArea(top: false, child: banners);
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [banners, bar]);
  }
}
