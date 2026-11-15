import 'package:flutter/material.dart';

import '../../theme/theme_extensions.dart';
import 'shimmer.dart';

/// Placeholder rows shaped like the file list, shown while it loads.
class FileListSkeleton extends StatelessWidget {
  const FileListSkeleton({super.key, this.itemCount = 6});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: context.padding.list,
        itemCount: itemCount,
        separatorBuilder: (context, index) =>
            SizedBox(height: context.spacing.sm),
        itemBuilder: (context, index) => const _FileRowSkeleton(),
      ),
    );
  }
}

class _FileRowSkeleton extends StatelessWidget {
  const _FileRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: context.padding.tile,
      decoration: BoxDecoration(
        borderRadius: context.radius.lg,
        border: Border.all(
          color: context.color.outline,
          width: context.sizes.borderWidth,
        ),
      ),
      child: Row(
        children: [
          ShimmerBox(
            height: context.sizes.avatar,
            width: context.sizes.avatar,
            radius: context.radius.md,
          ),
          SizedBox(width: context.spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ShimmerBox(height: 14, width: 180),
                SizedBox(height: context.spacing.sm),
                const ShimmerBox(height: 11, width: 120),
              ],
            ),
          ),
          SizedBox(width: context.spacing.md),
          ShimmerBox.circle(size: context.sizes.touchTarget - 8),
        ],
      ),
    );
  }
}

/// Placeholder cards shaped like transfer tiles.
class TransferListSkeleton extends StatelessWidget {
  const TransferListSkeleton({super.key, this.itemCount = 3});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: context.padding.list,
        itemCount: itemCount,
        separatorBuilder: (context, index) =>
            SizedBox(height: context.spacing.md),
        itemBuilder: (context, index) => const _TransferCardSkeleton(),
      ),
    );
  }
}

class _TransferCardSkeleton extends StatelessWidget {
  const _TransferCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: context.padding.card,
      decoration: BoxDecoration(
        borderRadius: context.radius.lg,
        border: Border.all(
          color: context.color.outline,
          width: context.sizes.borderWidth,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              ShimmerBox(
                height: context.sizes.avatar,
                width: context.sizes.avatar,
                radius: context.radius.md,
              ),
              SizedBox(width: context.spacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const ShimmerBox(height: 14, width: 200),
                    SizedBox(height: context.spacing.sm),
                    ShimmerBox(
                      height: 18,
                      width: 86,
                      radius: context.radius.pill,
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: context.spacing.lg),
          ShimmerBox(
            height: context.sizes.progressBar,
            radius: context.radius.pill,
          ),
          SizedBox(height: context.spacing.md),
          const ShimmerBox(height: 11, width: 220),
        ],
      ),
    );
  }
}
