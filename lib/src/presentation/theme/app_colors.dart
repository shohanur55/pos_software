import 'package:flutter/material.dart';

/// Semantic colors. Feature UI reads these through `context.color`.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary,
    required this.onPrimary,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.background,
    required this.surface,
    required this.surfaceContainer,
    required this.textPrimary,
    required this.textSecondary,
    required this.outline,
    required this.error,
    required this.onError,
    required this.errorContainer,
    required this.onErrorContainer,
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.highlight,
    required this.shimmerBase,
    required this.shimmerHighlight,
    required this.accentDocument,
    required this.accentDocumentContainer,
    required this.accentImage,
    required this.accentImageContainer,
    required this.accentVideo,
    required this.accentVideoContainer,
  });

  factory AppColors.fromScheme(ColorScheme scheme) {
    final isDark = scheme.brightness == Brightness.dark;
    return AppColors(
      primary: scheme.primary,
      onPrimary: scheme.onPrimary,
      primaryContainer: scheme.primaryContainer,
      onPrimaryContainer: scheme.onPrimaryContainer,
      background: scheme.surface,
      surface: scheme.surfaceContainerLow,
      surfaceContainer: scheme.surfaceContainerHighest,
      textPrimary: scheme.onSurface,
      textSecondary: scheme.onSurfaceVariant,
      outline: scheme.outlineVariant,
      error: scheme.error,
      onError: scheme.onError,
      errorContainer: scheme.errorContainer,
      onErrorContainer: scheme.onErrorContainer,
      success: isDark ? const Color(0xFF7DDB9A) : const Color(0xFF1B7F3B),
      successContainer: isDark
          ? const Color(0xFF14522A)
          : const Color(0xFFD5F5DE),
      onSuccessContainer: isDark
          ? const Color(0xFFD5F5DE)
          : const Color(0xFF0B3B1B),
      warning: isDark ? const Color(0xFFF5C26B) : const Color(0xFF8A5A00),
      warningContainer: isDark
          ? const Color(0xFF5C3F00)
          : const Color(0xFFFFE8BF),
      onWarningContainer: isDark
          ? const Color(0xFFFFE8BF)
          : const Color(0xFF3A2600),
      highlight: scheme.primary.withValues(alpha: isDark ? 0.18 : 0.10),
      shimmerBase: isDark
          ? scheme.surfaceContainerHighest
          : scheme.surfaceContainerHigh,
      shimmerHighlight: isDark
          ? const Color(0x1FFFFFFF)
          : const Color(0x80FFFFFF),
      accentDocument: isDark
          ? const Color(0xFFFFCE6B)
          : const Color(0xFFB36A00),
      accentDocumentContainer: isDark
          ? const Color(0xFF523300)
          : const Color(0xFFFFEFD1),
      accentImage: isDark ? const Color(0xFF8FB8FF) : const Color(0xFF1F5FBF),
      accentImageContainer: isDark
          ? const Color(0xFF1B3155)
          : const Color(0xFFDCE8FC),
      accentVideo: isDark ? const Color(0xFFC9A6F5) : const Color(0xFF6A3BB5),
      accentVideoContainer: isDark
          ? const Color(0xFF32215A)
          : const Color(0xFFEBE0FA),
    );
  }

  final Color primary;
  final Color onPrimary;
  final Color primaryContainer;
  final Color onPrimaryContainer;
  final Color background;
  final Color surface;
  final Color surfaceContainer;
  final Color textPrimary;
  final Color textSecondary;
  final Color outline;
  final Color error;
  final Color onError;
  final Color errorContainer;
  final Color onErrorContainer;
  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;

  /// Background for an item the user navigated to.
  final Color highlight;

  /// Placeholder surface and the band that sweeps across it.
  final Color shimmerBase;
  final Color shimmerHighlight;

  /// Per file type, so a catalog, a photo and a video are told apart at a glance.
  final Color accentDocument;
  final Color accentDocumentContainer;
  final Color accentImage;
  final Color accentImageContainer;
  final Color accentVideo;
  final Color accentVideoContainer;

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppColors(
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      primaryContainer: mix(primaryContainer, other.primaryContainer),
      onPrimaryContainer: mix(onPrimaryContainer, other.onPrimaryContainer),
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      surfaceContainer: mix(surfaceContainer, other.surfaceContainer),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      outline: mix(outline, other.outline),
      error: mix(error, other.error),
      onError: mix(onError, other.onError),
      errorContainer: mix(errorContainer, other.errorContainer),
      onErrorContainer: mix(onErrorContainer, other.onErrorContainer),
      success: mix(success, other.success),
      successContainer: mix(successContainer, other.successContainer),
      onSuccessContainer: mix(onSuccessContainer, other.onSuccessContainer),
      warning: mix(warning, other.warning),
      warningContainer: mix(warningContainer, other.warningContainer),
      onWarningContainer: mix(onWarningContainer, other.onWarningContainer),
      highlight: mix(highlight, other.highlight),
      shimmerBase: mix(shimmerBase, other.shimmerBase),
      shimmerHighlight: mix(shimmerHighlight, other.shimmerHighlight),
      accentDocument: mix(accentDocument, other.accentDocument),
      accentDocumentContainer: mix(
        accentDocumentContainer,
        other.accentDocumentContainer,
      ),
      accentImage: mix(accentImage, other.accentImage),
      accentImageContainer: mix(
        accentImageContainer,
        other.accentImageContainer,
      ),
      accentVideo: mix(accentVideo, other.accentVideo),
      accentVideoContainer: mix(
        accentVideoContainer,
        other.accentVideoContainer,
      ),
    );
  }
}
