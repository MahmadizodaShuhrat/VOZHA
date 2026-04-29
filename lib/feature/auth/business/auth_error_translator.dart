import 'package:easy_localization/easy_localization.dart';

/// Turns backend / client error tokens like `code_used`, `code_expired`,
/// `register_failed` into the user's language. Falls back to the raw
/// string when we don't have a translation — that way any new codes the
/// server introduces still show something readable instead of vanishing.
String translateAuthError(String raw) {
  final cleaned = raw.trim().toLowerCase();

  // Known codes — keep the list short; add new entries as backend coins them.
  const knownKeys = {
    'code_used',
    'code_expired',
    'code_invalid',
    'confirm_code_failed',
    'register_failed',
    'send_code_failed',
    'phone_number_already_exist',
    'phone_number_not_found',
    'code_not_confirmed',
    'invalid_phone',
  };

  // Normalise a few common backend phrasings into our keys.
  String key = cleaned;
  if (cleaned == 'phone number already exist' ||
      cleaned == 'phone already exist') {
    key = 'phone_number_already_exist';
  } else if (cleaned == 'phone number not found' ||
      cleaned == 'user not found') {
    key = 'phone_number_not_found';
  } else if (cleaned.contains('sms') && cleaned.contains('used')) {
    key = 'code_used';
  } else if (cleaned.contains('sms') && cleaned.contains('expired')) {
    key = 'code_expired';
  }

  if (knownKeys.contains(key)) {
    return 'auth_error_$key'.tr();
  }
  // Unknown code — return as-is (backend likely gave a human-readable
  // message such as "phone or email required").
  return raw;
}
