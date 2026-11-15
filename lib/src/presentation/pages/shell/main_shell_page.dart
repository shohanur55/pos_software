import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/constants/app_strings.dart';
import '../../blocs/transfer/transfer_bloc.dart';
import '../../widgets/typography/app_text.dart';
import 'widgets/shell_bottom_bar.dart';
import 'widgets/shell_listeners.dart';

/// Tab shell with the persistent transfer summary (G1). Uses a bottom
/// navigation bar on compact widths and a rail on wide ones.
class MainShellPage extends StatefulWidget {
  const MainShellPage({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const int transfersIndex = 2;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  bool get _onTransfers =>
      widget.navigationShell.currentIndex == MainShellPage.transfersIndex;

  @override
  void initState() {
    super.initState();
    if (_onTransfers) _acknowledgeFailures();
  }

  @override
  void didUpdateWidget(covariant MainShellPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_onTransfers &&
        oldWidget.navigationShell.currentIndex !=
            MainShellPage.transfersIndex) {
      _acknowledgeFailures();
    }
  }

  void _acknowledgeFailures() =>
      context.read<TransferBloc>().add(const TransferFailuresAcknowledged());

  void _onDestinationSelected(int index) {
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final destinations = [
      (Icons.upload_outlined, Icons.upload_rounded, AppStrings.tabUpload),
      (Icons.folder_outlined, Icons.folder_rounded, AppStrings.tabFiles),
      (
        Icons.swap_vert_outlined,
        Icons.swap_vert_rounded,
        AppStrings.tabTransfers,
      ),
    ];
    // The bottom bar takes the bottom inset, the rail the left one, so
    // nothing is padded twice in any orientation.
    Widget body({required bool hasRail}) => SafeArea(
      top: false,
      bottom: false,
      left: !hasRail,
      child: widget.navigationShell,
    );

    ShellBottomBar bottomBar({Widget? navigationBar}) => ShellBottomBar(
      showMiniBanner: !_onTransfers,
      onOpenTransfers: () =>
          _onDestinationSelected(MainShellPage.transfersIndex),
      navigationBar: navigationBar,
    );

    return ShellListeners(
      child: BlocListener<TransferBloc, TransferState>(
        listenWhen: (previous, current) =>
            _onTransfers && previous.failedCount != current.failedCount,
        listener: (context, state) => _acknowledgeFailures(),
        child: LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth >= AppConstants.compactBreakpoint) {
              return Scaffold(
                body: Row(
                  children: [
                    SafeArea(
                      right: false,
                      child: NavigationRail(
                        selectedIndex: widget.navigationShell.currentIndex,
                        onDestinationSelected: _onDestinationSelected,
                        labelType: NavigationRailLabelType.all,
                        destinations: [
                          for (final (icon, selected, label) in destinations)
                            NavigationRailDestination(
                              icon: Icon(icon),
                              selectedIcon: Icon(selected),
                              label: LabelText(label),
                            ),
                        ],
                      ),
                    ),
                    const VerticalDivider(width: 1),
                    Expanded(child: body(hasRail: true)),
                  ],
                ),
                bottomNavigationBar: bottomBar(),
              );
            }
            return Scaffold(
              body: body(hasRail: false),
              bottomNavigationBar: bottomBar(
                navigationBar: NavigationBar(
                  selectedIndex: widget.navigationShell.currentIndex,
                  onDestinationSelected: _onDestinationSelected,
                  destinations: [
                    for (final (icon, selected, label) in destinations)
                      NavigationDestination(
                        icon: Icon(icon),
                        selectedIcon: Icon(selected),
                        label: label,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
