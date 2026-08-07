import 'package:equatable/equatable.dart';

abstract class DealsTemplateState extends Equatable {
  const DealsTemplateState();

  @override
  List<Object?> get props => [];
}

class DealsTemplateInitial extends DealsTemplateState {}

class DealsTemplateLoading extends DealsTemplateState {}

class DealsTemplateSuccess extends DealsTemplateState {
  final String message;

  const DealsTemplateSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class DealsTemplateError extends DealsTemplateState {
  final String message;

  const DealsTemplateError(this.message);

  @override
  List<Object?> get props => [message];
}

// ── add near the top, alongside DealsState classes ──────────────
class BulkImportResult {
  final bool success;
  final int created;
  final int failed;
  final List<String> errors;

  const BulkImportResult({
    required this.success,
    required this.created,
    required this.failed,
    this.errors = const [],
  });

  factory BulkImportResult.fromJson(Map<String, dynamic> j) => BulkImportResult(
        success: j['success'] == true,
        created: (j['created'] as num?)?.toInt() ?? 0,
        failed: (j['failed'] as num?)?.toInt() ?? 0,
        errors: (j['errors'] is List)
            ? (j['errors'] as List).map((e) => e.toString()).toList()
            : const [],
      );

  bool get hasFailures => failed > 0 || errors.isNotEmpty;
}