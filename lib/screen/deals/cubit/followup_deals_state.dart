import 'package:equatable/equatable.dart';

abstract class FollowUpsTemplateState extends Equatable {
  const FollowUpsTemplateState();

  @override
  List<Object?> get props => [];
}

class FollowUpsTemplateInitial extends FollowUpsTemplateState {}

class FollowUpsTemplateLoading extends FollowUpsTemplateState {}

class FollowUpsTemplateSuccess extends FollowUpsTemplateState {
  final String message;

  const FollowUpsTemplateSuccess(this.message);

  @override
  List<Object?> get props => [message];
}

class FollowUpsTemplateError extends FollowUpsTemplateState {
  final String message;

  const FollowUpsTemplateError(this.message);

  @override
  List<Object?> get props => [message];
}