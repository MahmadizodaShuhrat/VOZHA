import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Data that has to survive the sign-up wizard (level → referral →
/// notifications) so the final `/auth/register` call can include the SMS
/// code that was verified back on the code-verify screen.
///
/// Note: the class name still says "Phone" for history — it also carries
/// an [email] now so the same state survives email-based signups. Exactly
/// one of [phone] / [email] is populated per registration.
class PendingPhoneRegistration {
  final String phone; // canonical, +992-prefixed (empty when email flow)
  final String email; // empty when phone flow
  final String smsCode;

  const PendingPhoneRegistration({
    required this.phone,
    required this.email,
    required this.smsCode,
  });
}

final pendingPhoneRegistrationProvider =
    NotifierProvider<PendingPhoneRegistrationNotifier,
        PendingPhoneRegistration?>(PendingPhoneRegistrationNotifier.new);

class PendingPhoneRegistrationNotifier
    extends Notifier<PendingPhoneRegistration?> {
  @override
  PendingPhoneRegistration? build() => null;

  /// Stash the credentials collected on the code-verify screen so the
  /// last step of the signup wizard can hit `/auth/register` with them.
  /// Exactly ONE of [phone] / [email] is expected to be non-empty.
  ///
  /// Previously this method force-prefixed every `phone` with "+992",
  /// which meant the email-registration path stored `phone = "+992"`
  /// (just the prefix) and the backend then rejected the register call
  /// with "phone number must be in Tajikistan format". Now we only add
  /// the prefix when there actually IS a phone number.
  void set({
    required String phone,
    required String email,
    required String smsCode,
  }) {
    final String formattedPhone;
    if (phone.isEmpty) {
      formattedPhone = '';
    } else {
      formattedPhone = phone.startsWith('+992')
          ? phone
          : '+992${phone.replaceAll(' ', '')}';
    }
    state = PendingPhoneRegistration(
      phone: formattedPhone,
      email: email.trim(),
      smsCode: smsCode,
    );
  }

  void clear() => state = null;
}
