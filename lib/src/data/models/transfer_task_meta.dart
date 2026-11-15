import 'dart:convert';

import '../../domain/entities/transfer_type.dart';

/// Our metadata, stored as JSON in the native task's `metaData` so a task can
/// be traced back to its transfer row even after the app restarts.
class TransferTaskMeta {
  const TransferTaskMeta({
    required this.transferId,
    required this.type,
    required this.displayName,
    required this.createdAt,
    this.remoteName,
  });

  final String transferId;
  final TransferType type;
  final String displayName;
  final String? remoteName;
  final DateTime createdAt;

  String encode() => jsonEncode({
    'transferId': transferId,
    'type': type.name,
    'displayName': displayName,
    'remoteName': remoteName,
    'createdAt': createdAt.toIso8601String(),
  });

  /// Returns `null` for tasks that were not created by this app.
  static TransferTaskMeta? tryDecode(String raw) {
    if (raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final type = TransferType.values.asNameMap()[json['type']];
      final id = json['transferId'];
      if (type == null || id is! String) return null;
      return TransferTaskMeta(
        transferId: id,
        type: type,
        displayName: json['displayName'] as String? ?? '',
        remoteName: json['remoteName'] as String?,
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
            DateTime.now(),
      );
    } on FormatException {
      return null;
    }
  }
}
