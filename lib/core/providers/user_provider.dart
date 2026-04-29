import 'package:flutter_riverpod/flutter_riverpod.dart';

class User {
  final String id;
  final String name;
  final String jwtToken;
  User({
    required this.id,
    required this.name,
    required this.jwtToken,
  });
}
final userProvider = NotifierProvider<UserNotifier, User?>(UserNotifier.new);

class UserNotifier extends Notifier<User?> {
  @override
  User? build() => null;
  void set(User? value) => state = value;
}
