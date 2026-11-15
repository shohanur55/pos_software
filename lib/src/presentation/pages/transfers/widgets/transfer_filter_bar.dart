import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_strings.dart';
import '../../../blocs/transfer/transfer_bloc.dart';
import '../../../theme/theme_extensions.dart';
import '../../../widgets/typography/app_text.dart';
import '../transfer_filter.dart';

class TransferFilterBar extends StatelessWidget {
  const TransferFilterBar({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final TransferFilter selected;
  final ValueChanged<TransferFilter> onSelected;

  @override
  Widget build(BuildContext context) {
    // A record compares by value, so chips rebuild only when a count changes.
    final counts = context.select((TransferBloc bloc) {
      int count(TransferFilter filter) =>
          bloc.state.transfers.where(filter.matches).length;
      return (
        all: count(TransferFilter.all),
        active: count(TransferFilter.active),
        completed: count(TransferFilter.completed),
        failed: count(TransferFilter.failed),
      );
    });
    String label(TransferFilter filter) => switch (filter) {
      TransferFilter.all => AppStrings.filterAll(counts.all),
      TransferFilter.active => AppStrings.filterActive(counts.active),
      TransferFilter.completed => AppStrings.filterCompleted(counts.completed),
      TransferFilter.failed => AppStrings.filterFailed(counts.failed),
    };

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: context.padding.tile,
      child: Row(
        children: [
          for (final filter in TransferFilter.values) ...[
            ChoiceChip(
              label: LabelText(label(filter)),
              selected: filter == selected,
              onSelected: (_) => onSelected(filter),
            ),
            SizedBox(width: context.spacing.sm),
          ],
        ],
      ),
    );
  }
}
