import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../blocs/files/files_bloc.dart';
import '../../../theme/theme_extensions.dart';
import '../../../utils/ui_messages.dart';
import '../../../widgets/typography/app_text.dart';

/// Tells the user how fresh the list is: syncing, synced a moment ago, or
/// an offline copy. A POS user needs to know whether what they see is real.
class FilesSyncBar extends StatelessWidget {
  const FilesSyncBar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select((FilesBloc bloc) => _SyncView.of(bloc.state));
    if (!state.visible) return const SizedBox.shrink();

    final colors = context.color;
    final (icon, label, color) = switch (state) {
      _SyncView(refreshing: true) => (
        Icons.sync_rounded,
        AppStrings.syncing,
        colors.textSecondary,
      ),
      _SyncView(stale: true) => (
        Icons.cloud_off_rounded,
        AppStrings.showingOfflineCopy,
        colors.warning,
      ),
      _ => (
        Icons.cloud_done_outlined,
        _syncedLabel(state.syncedAt),
        colors.textSecondary,
      ),
    };

    return Padding(
      padding: context.padding.banner,
      child: Row(
        children: [
          Icon(icon, size: context.sizes.iconSm, color: color),
          SizedBox(width: context.spacing.sm),
          Expanded(child: BodySmallText(label, color: color, maxLines: 1)),
          if (state.stale && state.syncedAt != null)
            BodySmallText(_syncedLabel(state.syncedAt), maxLines: 1),
        ],
      ),
    );
  }

  static String _syncedLabel(DateTime? syncedAt) {
    if (syncedAt == null) return AppStrings.neverSynced;
    final elapsed = DateTime.now().difference(syncedAt);
    if (elapsed.inMinutes < 1) return AppStrings.syncedJustNow;
    return AppStrings.syncedAt(
      UiMessages.relativeTime(syncedAt, DateTime.now()),
    );
  }
}

class _SyncView {
  const _SyncView({
    required this.visible,
    required this.refreshing,
    required this.stale,
    required this.syncedAt,
  });

  factory _SyncView.of(FilesState state) => _SyncView(
    visible: state.status == FilesStatus.success && state.files.isNotEmpty,
    refreshing: state.isRefreshing,
    stale: state.isStale,
    syncedAt: state.syncedAt,
  );

  final bool visible;
  final bool refreshing;
  final bool stale;
  final DateTime? syncedAt;

  @override
  bool operator ==(Object other) =>
      other is _SyncView &&
      other.visible == visible &&
      other.refreshing == refreshing &&
      other.stale == stale &&
      other.syncedAt == syncedAt;

  @override
  int get hashCode => Object.hash(visible, refreshing, stale, syncedAt);
}
