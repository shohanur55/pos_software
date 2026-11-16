import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../blocs/files/files_bloc.dart';
import '../../../theme/theme_extensions.dart';
import '../../../utils/ui_messages.dart';
import '../../../widgets/typography/app_text.dart';

/// Shows how fresh the list is: syncing, synced a moment ago, or an offline
/// copy. Rendered as a pill with an icon and a tone-matched tint.
class FilesSyncBar extends StatelessWidget {
  const FilesSyncBar({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.select((FilesBloc bloc) => _SyncView.of(bloc.state));
    if (!state.visible) return const SizedBox.shrink();

    final colors = context.color;
    final (icon, label, fg, bg) = switch (state) {
      _SyncView(refreshing: true) => (
        Icons.sync_rounded,
        AppStrings.syncing,
        colors.primary,
        colors.primaryContainer,
      ),
      _SyncView(stale: true) => (
        Icons.cloud_off_rounded,
        AppStrings.showingOfflineCopy,
        colors.onWarningContainer,
        colors.warningContainer,
      ),
      _ => (
        Icons.cloud_done_outlined,
        _syncedLabel(state.syncedAt),
        colors.onSuccessContainer,
        colors.successContainer,
      ),
    };

    return Padding(
      padding: EdgeInsets.fromLTRB(
        context.spacing.lg,
        context.spacing.sm,
        context.spacing.lg,
        context.spacing.xs,
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: context.spacing.md,
          vertical: context.spacing.sm,
        ),
        decoration: BoxDecoration(color: bg, borderRadius: context.radius.pill),
        child: Row(
          children: [
            Icon(icon, size: context.sizes.iconSm, color: fg),
            SizedBox(width: context.spacing.sm),
            Expanded(
              child: LabelSmallText(
                label,
                color: fg,
                fontWeight: FontWeight.w700,
                maxLines: 1,
              ),
            ),
            if (state.stale && state.syncedAt != null) ...[
              SizedBox(width: context.spacing.sm),
              LabelSmallText(
                _syncedLabel(state.syncedAt),
                color: fg.withValues(alpha: 0.8),
                maxLines: 1,
              ),
            ],
          ],
        ),
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
