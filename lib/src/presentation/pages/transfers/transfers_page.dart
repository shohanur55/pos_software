import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/constants/app_strings.dart';
import '../../blocs/transfer/transfer_bloc.dart';
import '../../theme/theme_extensions.dart';
import '../../widgets/common/constrained_content.dart';
import '../../widgets/common/message_state_view.dart';
import '../../widgets/common/skeletons.dart';
import '../../widgets/typography/app_text.dart';
import '../shell/widgets/shell_app_bar_actions.dart';
import 'transfer_filter.dart';
import 'widgets/transfer_filter_bar.dart';
import 'widgets/transfer_list_item.dart';

class TransfersPage extends StatefulWidget {
  const TransfersPage({super.key, this.highlightId, this.highlightToken});

  /// Transfer to scroll to and highlight, e.g. after a notification tap.
  final String? highlightId;

  /// Distinguishes two requests for the same [highlightId].
  final String? highlightToken;

  @override
  State<TransfersPage> createState() => _TransfersPageState();
}

class _TransfersPageState extends State<TransfersPage> {
  static const Duration _highlightDuration = Duration(seconds: 4);
  static const double _estimatedItemExtent = 200;

  final ScrollController _scrollController = ScrollController();
  final GlobalKey _highlightKey = GlobalKey();
  TransferFilter _filter = TransferFilter.all;
  String? _highlightedId;
  Timer? _highlightTimer;

  @override
  void initState() {
    super.initState();
    if (widget.highlightId != null) _focus(widget.highlightId!);
  }

  @override
  void didUpdateWidget(covariant TransfersPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final id = widget.highlightId;
    final isNewRequest =
        id != oldWidget.highlightId ||
        widget.highlightToken != oldWidget.highlightToken;
    if (id != null && isNewRequest) _focus(id);
  }

  @override
  void dispose() {
    _highlightTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _focus(String id) {
    _highlightTimer?.cancel();
    setState(() {
      _filter = TransferFilter.all;
      _highlightedId = id;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToHighlight(id));
    _highlightTimer = Timer(_highlightDuration, () {
      if (mounted) setState(() => _highlightedId = null);
    });
  }

  /// Items are built lazily, so jump near the item first if it isn't built yet.
  void _scrollToHighlight(String id, {bool retried = false}) {
    if (!mounted) return;
    final targetContext = _highlightKey.currentContext;
    if (targetContext != null) {
      Scrollable.ensureVisible(
        targetContext,
        duration: const Duration(milliseconds: 300),
        alignment: 0.1,
      );
      return;
    }
    final index = context.read<TransferBloc>().state.transfers.indexWhere(
      (transfer) => transfer.id == id,
    );
    if (index < 0 || retried || !_scrollController.hasClients) return;
    final offset = (index * _estimatedItemExtent).clamp(
      0.0,
      _scrollController.position.maxScrollExtent,
    );
    _scrollController.jumpTo(offset);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _scrollToHighlight(id, retried: true),
    );
  }

  List<String> _visibleIds(TransferState state) => [
    for (final transfer in state.transfers)
      if (_filter.matches(transfer)) transfer.id,
  ];

  @override
  Widget build(BuildContext context) {
    final finished = context.select(
      (TransferBloc bloc) => bloc.state.finishedCount,
    );
    return Scaffold(
      appBar: AppBar(
        title: const HeadingMediumText(AppStrings.transfersTitle, maxLines: 1),
        actions: [
          IconButton(
            tooltip: AppStrings.clearFinished,
            onPressed: finished == 0
                ? null
                : () => context.read<TransferBloc>().add(
                    const FinishedTransfersCleared(),
                  ),
            icon: const Icon(Icons.clear_all_rounded),
          ),
          const ShellAppBarActions(),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ConstrainedContent(
          child: Column(
            children: [
              TransferFilterBar(
                selected: _filter,
                onSelected: (filter) => setState(() => _filter = filter),
              ),
              Expanded(
                child: BlocBuilder<TransferBloc, TransferState>(
                  buildWhen: (previous, current) =>
                      previous.status != current.status ||
                      !listEquals(_visibleIds(previous), _visibleIds(current)),
                  builder: (context, state) {
                    if (state.status == TransferListStatus.loading ||
                        state.status == TransferListStatus.initial) {
                      return const TransferListSkeleton();
                    }
                    final ids = _visibleIds(state);
                    if (ids.isEmpty) {
                      return MessageStateView(
                        icon: Icons.swap_vert_rounded,
                        message: state.transfers.isEmpty
                            ? AppStrings.transfersEmpty
                            : AppStrings.transfersEmptyFiltered,
                      );
                    }
                    return ListView.separated(
                      controller: _scrollController,
                      padding: context.padding.list,
                      itemCount: ids.length,
                      separatorBuilder: (context, index) =>
                          SizedBox(height: context.spacing.md),
                      itemBuilder: (context, index) {
                        final id = ids[index];
                        final highlighted = id == _highlightedId;
                        return TransferListItem(
                          key: highlighted ? _highlightKey : ValueKey(id),
                          transferId: id,
                          highlighted: highlighted,
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
