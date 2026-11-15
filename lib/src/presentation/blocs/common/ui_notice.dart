import 'package:equatable/equatable.dart';

import '../../../core/base/failure.dart';

/// One-shot message for a `BlocListener`. [id] makes two equal messages in a
/// row distinct, so `listenWhen` fires for both.
final class UiNotice<K extends Enum> extends Equatable {
  const UiNotice(this.kind, this.id, {this.failure, this.subject, this.detail});

  final K kind;
  final int id;
  final FailureKind? failure;

  /// Optional value for the message, e.g. a file name.
  final String? subject;

  /// Second value where one is not enough, e.g. the byte position a transfer
  /// picks up from.
  final String? detail;

  @override
  List<Object?> get props => [kind, id, failure, subject, detail];
}
