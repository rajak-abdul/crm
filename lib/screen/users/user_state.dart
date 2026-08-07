import 'package:equatable/equatable.dart';

class UserProfile extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? profileImage;
  final String role;
  final String currency;

  const UserProfile({
    required this.id,
    required this.name,
    required this.email,
    required this.profileImage,
    required this.role,
    required this.currency,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['_id'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      profileImage: json['profileImage'],
      role: (json['role'] is Map)
          ? json['role']['name'] ?? ''
          : '',
      currency: json['currency'] ?? 'INR',
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        profileImage,
        role,
        currency,
      ];
}

abstract class UserState extends Equatable {
  const UserState();

  @override
  List<Object?> get props => [];
}

class UserInitial extends UserState {}

class UserLoading extends UserState {}

class UserLoaded extends UserState {
  final UserProfile user;

  const UserLoaded(this.user);

  @override
  List<Object?> get props => [user];
}

class UserError extends UserState {
  final String message;

  const UserError(this.message);

  @override
  List<Object?> get props => [message];
}