import 'package:crm_app/modals/modals.dart';
import 'package:equatable/equatable.dart';

abstract class UserRoleState extends Equatable {
  const UserRoleState();
  @override List<Object?> get props => [];
}
class UserRoleInitial extends UserRoleState {}
class UserRoleLoading  extends UserRoleState {}

class UserRoleLoaded extends UserRoleState {
  final List<AppUser> users, salesUsers;
  final List<AppRole> roles;
  const UserRoleLoaded({required this.users, required this.roles, this.salesUsers = const []});
  @override List<Object?> get props => [users, roles, salesUsers];
}

class UserRoleActionSuccess extends UserRoleLoaded {
  final String   message;
  final DateTime _ts; // breaks Equatable equality when same message fires twice
  UserRoleActionSuccess({
    required super.users, required super.roles,
    super.salesUsers, required this.message,
  }) : _ts = DateTime.now();
  @override List<Object?> get props => [users, roles, salesUsers, message, _ts];
}

class UserRoleError extends UserRoleState {
  final String message;
  const UserRoleError(this.message);
  @override List<Object?> get props => [message];
}