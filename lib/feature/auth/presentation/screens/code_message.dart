import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gap/gap.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/feature/auth/business/auth_error_translator.dart';
import 'package:vozhaomuz/feature/auth/business/auth_repository.dart';
import 'package:vozhaomuz/feature/auth/presentation/screens/sgin_in_page.dart';
import 'package:vozhaomuz/core/providers/user_provider.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';
import 'package:vozhaomuz/core/services/storage_service.dart';
import 'dart:async';

/// Absolute wall-clock expiry of the current SMS code. Storing a timestamp
/// (instead of a countdown int) means navigating away and back — or
/// backgrounding the app — doesn't "freeze" the timer: the remaining
/// seconds are always derived from (expiresAt - now).
final smsCodeExpiresAtProvider =
    NotifierProvider<SmsCodeExpiresAtNotifier, DateTime?>(
      SmsCodeExpiresAtNotifier.new,
    );

class SmsCodeExpiresAtNotifier extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;

  /// Anchor the expiry [seconds] from now. Called after every
  /// send-sms-code / resend success.
  void setSeconds(int seconds) {
    state = DateTime.now().add(Duration(seconds: seconds));
  }

  void clear() => state = null;
}

/// Derived seconds-until-expiry — pure function, never holds state.
int _remainingSeconds(DateTime? expiresAt) {
  if (expiresAt == null) return 0;
  final diff = expiresAt.difference(DateTime.now()).inSeconds;
  return diff > 0 ? diff : 0;
}

class CodeMessage extends ConsumerStatefulWidget {
  final bool isRegistration;

  const CodeMessage({super.key, this.isRegistration = false});

  @override
  ConsumerState<CodeMessage> createState() => _CodeMessageState();
}

class _CodeMessageState extends ConsumerState<CodeMessage> {
  bool _mounted = true;
  final TextEditingController _codeController = TextEditingController();
  Timer? _timer;
  bool _autoSubmitting = false;

  @override
  void dispose() {
    _mounted = false;
    _timer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    // The countdown value is derived from smsCodeExpiresAtProvider inside
    // build(); this ticker just forces a rebuild every second so the text
    // refreshes and we know when to reset the code field on expiry.
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!_mounted) return;
      final expiresAt = ref.read(smsCodeExpiresAtProvider);
      final current = _remainingSeconds(expiresAt);
      if (current == 0) {
        timer.cancel();
        _codeController.clear();
        _autoSubmitting = false;
      }
      setState(() {}); // refresh the MM:SS text
    });
  }

  @override
  void initState() {
    super.initState();
    _startTimer();

    // We rely ONLY on the OS autofill hint (AutofillHints.oneTimeCode) for
    // SMS pickup — Android shows the code as a keyboard suggestion when a
    // new SMS arrives. No clipboard polling: that used to paste any stray
    // 6-digit string (old codes, phone numbers, etc.) before the real SMS
    // arrived, which often submitted garbage and burned the attempt.
    //
    // Auto-submit still fires when the field has 6 digits, but only from
    // explicit user input (keyboard, paste, or OS autofill suggestion).
    _codeController.addListener(() {
      if (_mounted) setState(() {});
      final text = _codeController.text.trim();
      if (text.length == 6 && !_autoSubmitting && !_isLoading) {
        _autoSubmitting = true;
        Future.delayed(const Duration(milliseconds: 300), () {
          if (_mounted) _submitCode();
        });
      }
    });
  }

  /// Format seconds as MM:SS. With a backend ttl_seconds of 600 the naive
  /// "00:$seconds" rendering produced "00:587" — this correctly rolls the
  /// minutes column so the user sees "09:47".
  String _formatMmSs(int totalSeconds) {
    final m = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final s = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  /// Submit the SMS code (used by button, auto-paste, and auto-submit)
  Future<void> _submitCode() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    HapticFeedback.lightImpact();
    final authService = ref.read(authRepositoryProvider);
    final signInType = ref.read(signInTypeProvider);
    final userInput = ref.read(userInputProvider);
    final code = _codeController.text.trim();

    debugPrint('CONFIRMING... type=$signInType, input=$userInput, code=$code');

    if (code.isEmpty || code.length < 6) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('enter_code_hint'.tr())));
      setState(() => _isLoading = false);
      _autoSubmitting = false;
      return;
    }

    try {
      if (signInType == SignInType.phone) {
        await authService.confirmSmsCode(
          phone: userInput,
          code: code,
          isRegistration: widget.isRegistration,
        );
      } else {
        await authService.confirmSmsCode(
          email: userInput,
          code: code,
          isRegistration: widget.isRegistration,
        );
      }

      if (!context.mounted) return;

      // Registration path: SMS is confirmed but user record doesn't exist
      // yet. Previously we deferred /auth/register until the END of the
      // signup wizard (push_notification screen). That was fragile —
      // if the user quit mid-wizard they stayed unregistered, and the
      // last wizard step had to juggle phone/email state that kept
      // leaking. We now create the account RIGHT HERE so tokens are
      // saved and the wizard is pure configuration.
      if (widget.isRegistration) {
        final phoneForRegister =
            signInType == SignInType.phone ? userInput : '';
        final emailForRegister =
            signInType == SignInType.email ? userInput : '';
        final ok = await _registerNow(
          phone: phoneForRegister,
          email: emailForRegister,
          smsCode: code,
        );
        if (!ok) {
          // Error was already surfaced via SnackBar inside _registerNow.
          _autoSubmitting = false;
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      debugPrint('✅ Login success! isRegistration=${widget.isRegistration}');

      final savedToken = await StorageService.instance.getAccessToken();
      debugPrint(
        '🔑 Token after login: ${savedToken != null ? '${savedToken.substring(0, 10)}...' : 'NULL!'}',
      );

      // FCM device registration happens automatically via the global
      // StorageService listener wired in `main.dart` — by the time
      // we reach this point GoRouter has likely unmounted this screen
      // already, so any context-dependent work has to live elsewhere.

      final dest = widget.isRegistration ? '/auth/level' : '/home';
      debugPrint('🚀 Navigating to $dest');
      if (mounted) context.go(dest);
    } on AccountNotFoundException {
      // Phone registration path: login said "not found" after confirm.
      // Same story as the explicit-registration branch above — create
      // the account right here so the wizard stays stateless.
      debugPrint(
        '🔄 Login said "user not found" after confirm → registering inline',
      );
      final phoneForRegister =
          signInType == SignInType.phone ? userInput : '';
      final emailForRegister =
          signInType == SignInType.email ? userInput : '';
      final ok = await _registerNow(
        phone: phoneForRegister,
        email: emailForRegister,
        smsCode: code,
      );
      if (!ok) {
        _autoSubmitting = false;
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      if (mounted) context.go('/auth/level');
    } catch (e) {
      _autoSubmitting = false;
      String errorMessage = 'something_went_wrong'.tr();

      if (e.toString().contains('Timeout')) {
        errorMessage = 'timeout_error'.tr();
      } else if (e.toString().contains('SocketException')) {
        errorMessage = 'no_internet'.tr();
      } else {
        // Strip Dart's "Exception: " prefix, then map known error codes
        // (code_used, code_expired, ...) to localized messages. Unknown
        // codes fall through and the backend's raw text is shown.
        final raw = e.toString();
        final cleaned =
            raw.startsWith('Exception: ') ? raw.substring(11) : raw;
        errorMessage = translateAuthError(cleaned);
      }

      // Use State.mounted (not context.mounted) — accessing
      // `context.mounted` after the widget unmounted throws inside the
      // BuildContext getter before the property check even runs.
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
      }
    } finally {
      if (_mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  /// Create the account right after SMS confirm succeeds. Returns `true`
  /// on success (tokens saved, user provider populated) and `false` on
  /// any error after surfacing a SnackBar. The signup wizard pages
  /// downstream can then assume the user is already registered and
  /// just collect preferences.
  Future<bool> _registerNow({
    required String phone,
    required String email,
    required String smsCode,
  }) async {
    // Build a default display name from whatever identifier we have.
    // User can rename later; backend just needs `name` to be non-empty.
    final String placeholder;
    if (phone.isNotEmpty) {
      final p = phone.startsWith('+992')
          ? phone
          : '+992${phone.replaceAll(' ', '')}';
      placeholder = p.length >= 4 ? p.substring(p.length - 4) : p;
    } else if (email.isNotEmpty) {
      final at = email.indexOf('@');
      final local = at > 0 ? email.substring(0, at) : email;
      placeholder = local.length > 16 ? local.substring(0, 16) : local;
    } else {
      placeholder = 'new';
    }
    try {
      final authRepo = ref.read(authRepositoryProvider);
      final result = await authRepo.register(
        name: 'User $placeholder',
        phone: phone.isEmpty
            ? ''
            : (phone.startsWith('+992')
                ? phone
                : '+992${phone.replaceAll(' ', '')}'),
        email: email,
        smsCode: smsCode,
        // `aboutUs` is collected later in the referral wizard step.
        // Leave empty now; the value can be persisted via a separate
        // profile-update call from the wizard's final screen.
      );
      final accessToken = result['access_token'] as String?;
      final refreshToken = result['refresh_token'] as String?;
      final userId = result['id']?.toString() ?? '';
      final userName = result['name'] as String? ?? 'User $placeholder';
      if (accessToken == null || accessToken.isEmpty) {
        debugPrint('⚠️ _registerNow: register returned no access_token');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('something_went_wrong'.tr())),
          );
        }
        return false;
      }
      await StorageService.instance.setAccessToken(accessToken);
      if (refreshToken != null && refreshToken.isNotEmpty) {
        await StorageService.instance.setRefreshToken(refreshToken);
      }
      ref
          .read(userProvider.notifier)
          .set(User(id: userId, name: userName, jwtToken: accessToken));
      debugPrint('✅ _registerNow: account created, tokens saved');
      return true;
    } catch (e) {
      debugPrint('❌ _registerNow: $e');
      if (mounted) {
        final raw = e.toString();
        final cleaned =
            raw.startsWith('Exception: ') ? raw.substring(11) : raw;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(translateAuthError(cleaned))),
        );
      }
      return false;
    }
  }

  bool _isLoading = false;
  @override
  Widget build(BuildContext context) {
    // Derived live from the absolute expiry — survives navigating away and
    // back to this page.
    final remainingSeconds = _remainingSeconds(
      ref.watch(smsCodeExpiresAtProvider),
    );
    return Scaffold(
      backgroundColor: Color(0xFFF5FAFF),
      appBar: AppBar(
        backgroundColor: Color(0xFFF5FAFF),
        leading: GestureDetector(
          onTap: () {
            context.go('/auth/signin', extra: widget.isRegistration);
          },
          child: Icon(Icons.arrow_back_rounded, size: 30),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isRegistration ? 'register'.tr() : 'login'.tr(),
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 33),
                  ),
                  Gap(40),
                  Text(
                    ref.watch(signInTypeProvider) == SignInType.email
                        ? 'verify_email_code'.tr()
                        : 'verify_phone_code'.tr(),
                    style: AppTextStyles.whiteTextStyle.copyWith(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black.withOpacity(0.9),
                    ),
                  ),
                  Gap(10),

                  SizedBox(
                    height: 50,
                    child: AutofillGroup(
                      child: TextFormField(
                        keyboardType: TextInputType.number,
                        controller: _codeController,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(6),
                        ],
                        decoration: InputDecoration(
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: Color(0xffe8e2f4),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Gap(10),
                  Row(
                    children: [
                      Image.asset(
                        'assets/images/time_half.png',
                        width: 16,
                        height: 16,
                      ),
                      SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          remainingSeconds == 0
                              ? 'code_expired'.tr()
                              : 'code_expires_in'.tr(
                                  args: [_formatMmSs(remainingSeconds)],
                                ),
                          style: AppTextStyles.whiteTextStyle.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w400,
                            color: remainingSeconds == 0
                                ? Colors.red
                                : Colors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Gap(5),
                  remainingSeconds == 0
                      ? Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: MyButton(
                            borderColor: Color(0xffE39d57),
                            backButtonColor: Color(0xffE39d57),
                            height: 52,
                            borderRadius: 7,
                            padding: EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 2,
                            ),
                            depth: 4,
                            buttonColor:
                                true // TEMP: disabled cooldown for testing
                                ? Color.fromARGB(255, 237, 212, 87)
                                : Colors.grey.shade100,
                            onPressed:
                                true // TEMP: disabled cooldown for testing
                                ? () async {
                                    HapticFeedback.lightImpact();
                                    final authService = ref.read(
                                      authRepositoryProvider,
                                    );
                                    final userInput = ref.read(
                                      userInputProvider,
                                    );
                                    final signInType = ref.read(
                                      signInTypeProvider,
                                    );

                                    try {
                                      final int expiresIn;
                                      // Resend must use the same action the
                                      // user originally picked; otherwise a
                                      // register-flow user hits /send-code
                                      // with action=login (the default) and
                                      // backend 404s even though the first
                                      // send worked.
                                      final resendAction = widget.isRegistration
                                          ? 'register'
                                          : 'login';
                                      if (signInType == SignInType.phone) {
                                        expiresIn = await authService.sendSmsCode(
                                          phone: userInput,
                                          action: resendAction,
                                        );
                                      } else {
                                        expiresIn = await authService.sendSmsCode(
                                          email: userInput,
                                          action: resendAction,
                                        );
                                      }

                                      // Clear old code so the field is ready for the freshly
                                      // sent one from the OS autofill suggestion.
                                      _codeController.clear();
                                      _autoSubmitting = false;

                                      // Re-anchor expiry at now + server TTL.
                                      ref
                                          .read(
                                            smsCodeExpiresAtProvider.notifier,
                                          )
                                          .setSeconds(expiresIn);

                                      _startTimer();
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text('code_resent'.tr()),
                                        ),
                                      );
                                    } catch (e) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            '${'code_send_failed'.tr()}: $e',
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                : null,
                            child: Text(
                              'resend_code_button'.tr(),
                              style: AppTextStyles.whiteTextStyle.copyWith(
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        )
                      : SizedBox.shrink(),
                ],
              ),

              remainingSeconds == 0
                  ? SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: MyButton(
                        height: 52,
                        padding: EdgeInsets.zero,
                        width: double.infinity,
                        depth: _codeController.text.trim().length == 6 ? 4 : 0,
                        buttonColor: _codeController.text.trim().length == 6
                            ? Colors.blue
                            : Colors.blue.withValues(alpha: 0.5),
                        backButtonColor: Color(0xff0e77b1),
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                                textAlign: TextAlign.center,
                                'next'.tr(),
                                style: AppTextStyles.whiteTextStyle.copyWith(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                        onPressed: _codeController.text.trim().length == 6
                            ? _submitCode
                            : null,
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}
