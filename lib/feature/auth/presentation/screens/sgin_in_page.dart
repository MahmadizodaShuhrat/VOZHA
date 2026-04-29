import 'dart:async';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/core/constants/app_text_styles.dart';
import 'package:vozhaomuz/core/providers/user_provider.dart';
import 'package:vozhaomuz/feature/auth/business/auth_repository.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/auth_notifier_provider.dart';
import 'package:vozhaomuz/feature/auth/presentation/screens/code_message.dart';
import 'package:vozhaomuz/feature/auth/state/auth_state.dart';
import 'package:vozhaomuz/shared/widgets/my_button.dart';

enum SignInType { phone, email }

final signInTypeProvider = NotifierProvider<SignInTypeNotifier, SignInType>(
  SignInTypeNotifier.new,
);

class SignInTypeNotifier extends Notifier<SignInType> {
  @override
  SignInType build() => SignInType.phone;
  void set(SignInType value) => state = value;
}

final userInputProvider = NotifierProvider<UserInputNotifier, String>(
  UserInputNotifier.new,
);

class UserInputNotifier extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

final isLoadingProvider = NotifierProvider<IsLoadingNotifier, bool>(
  IsLoadingNotifier.new,
);

class IsLoadingNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

class SignInPage extends ConsumerStatefulWidget {
  final bool isRegistration;

  const SignInPage({super.key, this.isRegistration = false});

  @override
  ConsumerState<SignInPage> createState() => _SignInPageState();
}

class _SignInPageState extends ConsumerState<SignInPage> {
  final textController = TextEditingController();
  bool _isInputValid = false;

  @override
  void initState() {
    super.initState();
    textController.addListener(_onInputChanged);
  }

  void _onInputChanged() {
    final signInType = ref.read(signInTypeProvider);
    final text = textController.text.trim();
    final valid = signInType == SignInType.phone
        ? text.length == 9
        : text.isNotEmpty && text.contains('@');
    if (valid != _isInputValid) {
      setState(() => _isInputValid = valid);
    }
  }

  @override
  void dispose() {
    textController.removeListener(_onInputChanged);
    textController.dispose();
    super.dispose();
  }

  /// Delegates the phone/email pick to the repository. Used twice in
  /// [handleSubmit] so the login → auto-register fallback stays a one-liner.
  Future<int> _sendCode(String input, bool register) {
    final action = register ? 'register' : 'login';
    final repo = ref.read(authRepositoryProvider);
    if (ref.read(signInTypeProvider) == SignInType.phone) {
      return repo.sendSmsCode(phone: input, action: action);
    }
    return repo.sendSmsCode(email: input, action: action);
  }

  Future<void> handleSubmit() async {
    final input = textController.text.trim();
    ref.read(userInputProvider.notifier).set(input);

    if (ref.read(isLoadingProvider) || input.isEmpty) {
      if (input.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.read(signInTypeProvider) == SignInType.phone
                  ? 'enter_phone'.tr()
                  : 'enter_email'.tr(),
            ),
          ),
        );
      }
      return;
    }

    ref.read(isLoadingProvider.notifier).set(true);
    try {
      // Single-field flow: user types a phone and Next — the client figures
      // out whether it's login or register from the server's response.
      //   * Login tab + unknown phone    → auto-switch to register
      //   * Register tab + known phone   → auto-switch to login
      var isRegisterFlow = widget.isRegistration;
      int expiresIn;
      // Keep a handle on the in-flight request even after the UX
      // deadline fires, so we can reconcile the timer once the backend
      // actually responds. Without this, emulator / rural-LTE users
      // were stuck at the 60s fallback even though the backend had
      // granted, say, 120s.
      Future<int>? pendingRequest;
      // Short "UX deadline": if the server responds within ~2.5s we use
      // the real TTL and can still pivot on 404/409. If it's slower than
      // that, navigate to /verify with a fallback TTL — the SMS is
      // almost certainly on its way and the user shouldn't be stuck
      // staring at a spinner. The HTTP request itself keeps running
      // (auth_repository uses a 60s timeout) so the server still
      // processes the send.
      const uxDeadline = Duration(milliseconds: 2500);
      try {
        pendingRequest = _sendCode(input, isRegisterFlow);
        expiresIn = await pendingRequest.timeout(uxDeadline);
      } on AccountNotFoundException {
        if (isRegisterFlow) rethrow;
        debugPrint('🔄 Login phone not found → auto-switching to register');
        isRegisterFlow = true;
        pendingRequest = _sendCode(input, true);
        try {
          expiresIn = await pendingRequest.timeout(uxDeadline);
        } on TimeoutException {
          expiresIn = AppConstants.smsCodeExpiryFallbackSeconds;
        }
      } on AccountAlreadyExistsException {
        if (!isRegisterFlow) rethrow;
        debugPrint('🔄 Register phone already exists → auto-switching to login');
        isRegisterFlow = false;
        pendingRequest = _sendCode(input, false);
        try {
          expiresIn = await pendingRequest.timeout(uxDeadline);
        } on TimeoutException {
          expiresIn = AppConstants.smsCodeExpiryFallbackSeconds;
        }
      } on TimeoutException {
        debugPrint(
          '⏱️ Slow network — navigating to /verify with fallback TTL, '
          'request continues in background',
        );
        expiresIn = AppConstants.smsCodeExpiryFallbackSeconds;
      }
      // Anchor expiry at (now + server TTL). CodeMessage derives its
      // countdown from this timestamp, so navigating away and back keeps
      // the timer consistent with real elapsed time.
      ref.read(smsCodeExpiresAtProvider.notifier).setSeconds(expiresIn);
      // If the UX deadline fired first, keep listening to the in-flight
      // request. When the real backend TTL finally arrives the /verify
      // screen (which watches `smsCodeExpiresAtProvider`) will repaint
      // the countdown to match what the server actually granted. If the
      // background request fails we just keep the fallback.
      final fallbackUsed = expiresIn;
      pendingRequest?.then((realTtl) {
        if (realTtl > 0 && realTtl != fallbackUsed) {
          debugPrint('✅ Background SMS response: updating TTL to ${realTtl}s');
          ref.read(smsCodeExpiresAtProvider.notifier).setSeconds(realTtl);
        }
      }).catchError((e) {
        debugPrint('⚠️ Background SMS request failed: $e — keeping fallback');
      });
      if (!mounted) return;
      context.go('/auth/verify', extra: isRegisterFlow);
    } on TooManyRequestsException catch (e) {
      // Show the backend's retry_after_seconds in the message when present,
      // so the user knows exactly how long to wait instead of a generic
      // "try later".
      final msg = e.retryAfterSeconds != null
          ? 'too_many_requests_with_retry'.tr(
              namedArgs: {'seconds': e.retryAfterSeconds.toString()},
            )
          : 'too_many_requests'.tr();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      final msg = e.toString().contains('Timeout')
          ? 'timeout_error'.tr()
          : e.toString().contains('SocketException')
          ? 'no_internet'.tr()
          : e.toString();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      ref.read(isLoadingProvider.notifier).set(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signInType = ref.watch(signInTypeProvider);
    final isLoading = ref.watch(isLoadingProvider);
    final authState = ref.watch(authNotifierProvider);
    final isOAuthLoading = authState == const AuthState.loading();

    // Listen to auth state changes for Google/Apple sign-in navigation
    // Mirrors Unity: PrepareUser → login goes to home, register goes to sign-up
    ref.listen<AuthState>(authNotifierProvider, (prev, next) {
      next.when(
        initial: () {},
        loading: () {},
        authenticated: (user) {
          // Tokens already saved in auth_notifier_provider._handleOAuthResponse
          if (!context.mounted) return;
          ref
              .read(userProvider.notifier)
              .set(User(id: '', name: '', jwtToken: user.accessToken));
          if (context.mounted) context.go('/home');
        },
        needsSignUp: (data, provider) {
          // New user needs to complete registration
          if (context.mounted) context.go('/auth/referral');
        },
        error: (message) {
          if (!context.mounted) return;
          // Show short friendly error, not raw exception text
          final String displayMsg;
          if (message.contains('timeout') || message.contains('Timeout')) {
            displayMsg = 'timeout_error'.tr();
          } else if (message.contains('SocketException') || message.contains('network')) {
            displayMsg = 'no_internet'.tr();
          } else if (message.contains('CANCELED') || message.contains('cancel')) {
            return; // Don't show anything on cancel
          } else {
            displayMsg = 'login_error'.tr();
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(displayMsg)),
          );
        },
      );
    });

    return Scaffold(
      backgroundColor: const Color(0xffF0F4FD),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/auth/start'),
        ),
        backgroundColor: const Color(0xffF0F4FD),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.isRegistration ? 'register'.tr() : 'login'.tr(),
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 33,
                ),
              ),
              const Gap(20),
              if (!widget.isRegistration)
                Row(
                  children: [
                    _buildTabButton(SignInType.phone, 'phone_number'.tr()),
                    _buildTabButton(SignInType.email, 'email'.tr()),
                  ],
                ),
              if (!widget.isRegistration) const Gap(30),
              if (!widget.isRegistration)
                Divider(thickness: 2, color: Colors.blue.shade100),
              const Gap(40),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.isRegistration
                        ? 'sign_up_by_phone'.tr()
                        : (signInType == SignInType.phone
                              ? 'login_by_phone'.tr()
                              : 'login_by_email'.tr()),
                    style: const TextStyle(
                      color: Color(0xff202939),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Gap(5),
                  Row(
                    children: [
                      if (signInType == SignInType.phone)
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(12),
                              topLeft: Radius.circular(12),
                            ),
                          ),
                          child: const Text(
                            '+992',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      Expanded(
                        child: TextFormField(
                          minLines: 1,
                          maxLines: 1,
                          key: ValueKey(signInType),
                          controller: textController,
                          keyboardType: signInType == SignInType.email
                              ? TextInputType.emailAddress
                              : TextInputType.phone,
                          maxLength: signInType == SignInType.phone ? 9 : null,
                          inputFormatters: signInType == SignInType.phone
                              ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(9)]
                              : null,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            counterText: '',
                            enabledBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Color(0xffE8EDF4),
                                width: 3,
                              ),
                              borderRadius: _inputBorderRadius(signInType),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(
                                color: Colors.blue,
                                width: 2,
                              ),
                              borderRadius: _inputBorderRadius(signInType),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: _inputBorderRadius(signInType),
                            ),
                            prefixIcon: signInType == SignInType.email
                                ? const Icon(
                                    Icons.email,
                                    color: Color(0xFF9AA4B2),
                                  )
                                : null,
                            labelText: signInType == SignInType.phone
                                ? 'enter_phone'.tr()
                                : 'enter_email'.tr(),
                            labelStyle: const TextStyle(
                              color: Color(0xFF9AA4B2),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const Gap(40),
              MyButton(
                width: double.infinity,
                height: 52,
                padding: EdgeInsets.zero,
                depth: _isInputValid ? 4 : 0,
                buttonColor: _isInputValid ? Colors.blue : Colors.blue.withValues(alpha: 0.5),
                backButtonColor: const Color(0xff0e77b1),
                onPressed: _isInputValid ? handleSubmit : null,
                child: Center(
                  child: isLoading
                      ? const SizedBox(
                          width: 30,
                          height: 30,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.0,
                          ),
                        )
                      : Text(
                          'next'.tr(),
                          textAlign: TextAlign.center,
                          style: AppTextStyles.whiteTextStyle.copyWith(
                            fontSize: 18,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                ),
              ),
              if (!widget.isRegistration) ...[
                const Gap(40),
                Divider(thickness: 2, color: Colors.blue.shade100),
                const Gap(40),
                Center(
                  child: Text(
                    'or'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w200,
                      fontSize: 28,
                    ),
                  ),
                ),
                const Gap(20),
                // ── Google Sign-In ──
                // Mirrors Unity: UIButtonLogInWithGoogle → SignInWithGoogle()
                MyButton(
                  height: 45,
                  padding: EdgeInsets.zero,
                  borderRadius: 12,
                  depth: 4,
                  buttonColor: Colors.white,
                  backButtonColor: const Color.fromARGB(255, 226, 226, 226),
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await ref
                        .read(authNotifierProvider.notifier)
                        .signInWithGoogle();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/google_logo.png',
                        width: 24,
                        height: 24,
                      ),
                      const Gap(10),
                      Text(
                        'sign_in_with_google'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(20),
                // ── Apple Sign-In ──
                // Mirrors Unity: UIButtonLogInWithApple → SignInWithApple()
                MyButton(
                  height: 52,
                  padding: EdgeInsets.zero,
                  borderRadius: 13,
                  depth: 4,
                  buttonColor: Colors.white,
                  backButtonColor: const Color.fromARGB(255, 226, 226, 226),
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await ref
                        .read(authNotifierProvider.notifier)
                        .signInWithApple();
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset(
                        'assets/images/apple_logo.png',
                        width: 24,
                        height: 24,
                      ),
                      const Gap(15),
                      Text(
                        'sign_in_with_apple'.tr(),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
          ),

          // ── Loading overlay for Google/Apple OAuth ──
          if (isOAuthLoading)
            Container(
              color: Colors.black54,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                    const Gap(16),
                    Text(
                      'loading'.tr(),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Returns the InputBorder radius based on the sign-in type.
  BorderRadius _inputBorderRadius(SignInType type) {
    return BorderRadius.only(
      topRight: const Radius.circular(12),
      bottomRight: const Radius.circular(12),
      bottomLeft: type == SignInType.phone
          ? Radius.zero
          : const Radius.circular(12),
      topLeft: type == SignInType.phone
          ? Radius.zero
          : const Radius.circular(12),
    );
  }

  Widget _buildTabButton(SignInType type, String label) {
    final selected = ref.watch(signInTypeProvider) == type;
    return Expanded(
      child: ElevatedButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          ref.read(signInTypeProvider.notifier).set(type);
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: selected ? Colors.blue : Colors.white,
          foregroundColor: selected ? Colors.white : Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: type == SignInType.phone
                ? const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    bottomLeft: Radius.circular(12),
                  )
                : const BorderRadius.only(
                    topRight: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
          ),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(label, maxLines: 1),
        ),
      ),
    );
  }
}
