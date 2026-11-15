import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_strings.dart';
import '../../../domain/entities/remote_file_entity.dart';
import '../../blocs/files/files_bloc.dart';
import '../../router/routes.dart';
import '../../theme/theme_extensions.dart';
import '../../utils/ui_messages.dart';
import '../../widgets/common/constrained_content.dart';
import '../../widgets/common/message_state_view.dart';
import '../../widgets/common/skeletons.dart';
import '../../widgets/typography/app_text.dart';
import '../shell/widgets/shell_app_bar_actions.dart';
import 'widgets/files_sync_bar.dart';
import 'widgets/remote_file_tile.dart';

class FilesPage extends StatelessWidget {
  const FilesPage({super.key});

  Future<void> _refresh(BuildContext context) {
    final completer = Completer<void>();
    context.read<FilesBloc>().add(FilesRefreshed(completer));
    return completer.future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const HeadingMediumText(AppStrings.filesTitle, maxLines: 1),
        actions: const [ShellAppBarActions()],
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            const FilesSyncBar(),
            Expanded(
              child: BlocBuilder<FilesBloc, FilesState>(
                buildWhen: (previous, current) =>
                    previous.status != current.status ||
                    previous.files != current.files ||
                    previous.failure != current.failure,
                builder: (context, state) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _FilesBody(
                    key: ValueKey(_bodyKey(state)),
                    state: state,
                    onRefresh: () => _refresh(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Switching between these three shapes is what animates; row changes
  /// inside the list are not a reason to cross-fade the whole page.
  static String _bodyKey(FilesState state) => switch (state.status) {
    FilesStatus.initial || FilesStatus.loading => 'loading',
    FilesStatus.failure => 'failure',
    FilesStatus.success => state.isEmpty ? 'empty' : 'list',
  };
}

class _FilesBody extends StatelessWidget {
  const _FilesBody({super.key, required this.state, required this.onRefresh});

  final FilesState state;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case FilesStatus.initial || FilesStatus.loading:
        return const ConstrainedContent(child: FileListSkeleton());
      case FilesStatus.failure:
        return MessageStateView(
          icon: Icons.cloud_off_rounded,
          isError: true,
          message: UiMessages.failureMessage(state.failure),
          actionLabel: AppStrings.retry,
          onAction: () => context.read<FilesBloc>().add(const FilesLoaded()),
        );
      case FilesStatus.success:
        return RefreshIndicator(
          onRefresh: onRefresh,
          child: state.isEmpty
              ? const _EmptyFiles()
              : _FileList(files: state.files),
        );
    }
  }
}

class _FileList extends StatelessWidget {
  const _FileList({required this.files});

  final List<RemoteFileEntity> files;

  @override
  Widget build(BuildContext context) {
    return ConstrainedContent(
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: context.padding.list,
        itemCount: files.length,
        separatorBuilder: (context, index) =>
            SizedBox(height: context.spacing.sm),
        itemBuilder: (context, index) => RemoteFileTile(file: files[index]),
      ),
    );
  }
}

class _EmptyFiles extends StatelessWidget {
  const _EmptyFiles();

  @override
  Widget build(BuildContext context) {
    // Scrollable so pull-to-refresh still works with nothing in the list.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: constraints.maxHeight,
          child: MessageStateView(
            icon: Icons.folder_open_rounded,
            message: AppStrings.filesEmpty,
            actionLabel: AppStrings.filesEmptyAction,
            onAction: () => context.goNamed(Routes.uploadName),
          ),
        ),
      ),
    );
  }
}
