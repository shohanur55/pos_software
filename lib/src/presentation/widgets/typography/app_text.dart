import 'package:flutter/material.dart';

import '../../theme/theme_extensions.dart';

/// Base for the typography widgets. Feature UI never uses a raw [Text].
abstract class AppText extends StatelessWidget {
  const AppText(
    this.text, {
    super.key,
    this.color,
    this.maxLines,
    this.overflow,
    this.textAlign,
    this.fontWeight,
    this.decoration,
    this.semanticsLabel,
  });

  final String text;
  final Color? color;
  final int? maxLines;
  final TextOverflow? overflow;
  final TextAlign? textAlign;
  final FontWeight? fontWeight;
  final TextDecoration? decoration;
  final String? semanticsLabel;

  TextStyle? baseStyle(BuildContext context);

  Color defaultColor(BuildContext context) => context.color.textPrimary;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: baseStyle(context)?.copyWith(
        color: color ?? defaultColor(context),
        fontWeight: fontWeight,
        decoration: decoration,
        decorationColor: color ?? defaultColor(context),
      ),
      maxLines: maxLines,
      overflow: overflow ?? (maxLines == null ? null : TextOverflow.ellipsis),
      textAlign: textAlign,
      semanticsLabel: semanticsLabel,
    );
  }
}

class DisplayText extends AppText {
  const DisplayText(
    super.text, {
    super.key,
    super.color,
    super.maxLines,
    super.textAlign,
    super.fontWeight,
    super.semanticsLabel,
  });

  @override
  TextStyle? baseStyle(BuildContext context) => context.textTheme.displaySmall;
}

class HeadingLargeText extends AppText {
  const HeadingLargeText(
    super.text, {
    super.key,
    super.color,
    super.maxLines,
    super.textAlign,
    super.fontWeight,
  });

  @override
  TextStyle? baseStyle(BuildContext context) => context.textTheme.headlineSmall;
}

class HeadingMediumText extends AppText {
  const HeadingMediumText(
    super.text, {
    super.key,
    super.color,
    super.maxLines,
    super.textAlign,
    super.fontWeight,
  });

  @override
  TextStyle? baseStyle(BuildContext context) => context.textTheme.titleLarge;
}

class TitleText extends AppText {
  const TitleText(
    super.text, {
    super.key,
    super.color,
    super.maxLines,
    super.overflow,
    super.textAlign,
    super.fontWeight,
  });

  @override
  TextStyle? baseStyle(BuildContext context) => context.textTheme.titleMedium;
}

class BodyLargeText extends AppText {
  const BodyLargeText(
    super.text, {
    super.key,
    super.color,
    super.maxLines,
    super.textAlign,
    super.fontWeight,
  });

  @override
  TextStyle? baseStyle(BuildContext context) => context.textTheme.bodyLarge;
}

class BodyMediumText extends AppText {
  const BodyMediumText(
    super.text, {
    super.key,
    super.color,
    super.maxLines,
    super.overflow,
    super.textAlign,
    super.fontWeight,
  });

  @override
  TextStyle? baseStyle(BuildContext context) => context.textTheme.bodyMedium;
}

class BodySmallText extends AppText {
  const BodySmallText(
    super.text, {
    super.key,
    super.color,
    super.maxLines,
    super.overflow,
    super.textAlign,
    super.fontWeight,
    super.decoration,
  });

  @override
  TextStyle? baseStyle(BuildContext context) => context.textTheme.bodySmall;

  @override
  Color defaultColor(BuildContext context) => context.color.textSecondary;
}

class LabelText extends AppText {
  const LabelText(
    super.text, {
    super.key,
    super.color,
    super.maxLines,
    super.textAlign,
    super.fontWeight,
  });

  @override
  TextStyle? baseStyle(BuildContext context) => context.textTheme.labelLarge;
}

class LabelSmallText extends AppText {
  const LabelSmallText(
    super.text, {
    super.key,
    super.color,
    super.maxLines,
    super.textAlign,
    super.fontWeight,
  });

  @override
  TextStyle? baseStyle(BuildContext context) => context.textTheme.labelSmall;
}
