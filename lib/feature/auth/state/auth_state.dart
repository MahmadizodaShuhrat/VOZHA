import 'package:freezed_annotation/freezed_annotation.dart';

import 'response_register_token.dart';

part 'auth_state.freezed.dart';

/// Authentication state using union types for different states
@freezed
class AuthState with _$AuthState {
  /// Initial state when app starts
  const factory AuthState.initial() = _Initial;
  
  /// Loading state during API calls
  const factory AuthState.loading() = _Loading;
  
  /// User is fully authenticated
  const factory AuthState.authenticated(ResponseRegisterToken user) = _Authenticated;
  
  /// User needs to complete sign up (OAuth flow)
  const factory AuthState.needsSignUp(Map<String, dynamic> registerData, String provider) = _NeedsSignUp;
  
  /// Error occurred
  const factory AuthState.error(String message) = _Error;
}
