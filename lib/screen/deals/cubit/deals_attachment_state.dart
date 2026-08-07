import 'package:equatable/equatable.dart';

enum DealsAttachmentStatus {
  initial,
  loading,
  previewSuccess,
  downloadSuccess,
  uploadSuccess,
  error,
}

class DealsAttachmentState extends Equatable {
  final DealsAttachmentStatus status;
  final String? message;
  final String? filePath;

  const DealsAttachmentState({
    this.status = DealsAttachmentStatus.initial,
    this.message,
    this.filePath,
  });

  DealsAttachmentState copyWith({
    DealsAttachmentStatus? status,
    String? message,
    String? filePath,
  }) {
    return DealsAttachmentState(
      status: status ?? this.status,
      message: message,
      filePath: filePath ?? this.filePath,
    );
  }

  @override
  List<Object?> get props => [
        status,
        message,
        filePath,
      ];
}