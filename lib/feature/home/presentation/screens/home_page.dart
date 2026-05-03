import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vozhaomuz/feature/auth/presentation/providers/locale_provider.dart';
import 'package:vozhaomuz/feature/auth/presentation/screens/start_page.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/get_profile_info_provider.dart';
import 'package:vozhaomuz/feature/profile/business/profile_repository.dart';
import 'package:vozhaomuz/feature/profile/presentation/providers/app_version_provider.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/user_rank_provider.dart';
import 'package:vozhaomuz/feature/progress/progress_provider.dart';
import 'package:vozhaomuz/feature/home/presentation/providers/banner_provider.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/widgets/home_shimmer_loading.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/widgets/home_header_section.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/widgets/home_banner_section.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/widgets/home_stats_row.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/widgets/home_action_buttons.dart';
import 'package:vozhaomuz/feature/rating/presentation/providers/top_3_users_day_provider.dart';
import 'package:vozhaomuz/feature/home/presentation/screens/widgets/premium_welcome_dialog.dart';
import 'package:vozhaomuz/shared/widgets/force_update_dialog.dart';
import 'package:vozhaomuz/core/providers/energy_provider.dart';

final isShowProvider = NotifierProvider<IsShowNotifier, bool>(
  IsShowNotifier.new,
);

class IsShowNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void set(bool value) => state = value;
}

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(getProfileInfoProvider);

    useEffect(() {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        ref.read(getProfileInfoProvider.notifier).getProfile();
        ref.invalidate(profileRatingProvider);
        // Sync energy with server (falls back to local cache + regen on failure).
        ref.read(energyProvider.notifier).refreshFromServer();
        // Update dialog runs once on mount. If an update is available we
        // surface it immediately. Capped at 5s so a slow /version
        // endpoint doesn't hold the Future open indefinitely — the
        // premium welcome (handled via ref.listen below) doesn't depend
        // on this await resolving.
        try {
          // 10s — rural-Tajikistan LTE/3G can take 5+ seconds just for
          // the TCP/TLS handshake. Anything shorter silently misses the
          // force-update dialog for users who actually need it the most.
          await _checkForUpdate(context, ref)
              .timeout(const Duration(seconds: 10));
        } catch (e) {
          debugPrint('[HomePage] _checkForUpdate timed out / failed: $e');
        }
      });
      return null;
    }, []);

    // Premium welcome dialog trigger. Fires exactly once per HomePage
    // lifetime, the first time the profile resolves with a non-null
    // user. The `hasCheckedPremium` flag prevents the listener from
    // re-firing on mid-session profile refreshes (optimistic money
    // updates, streak re-fetches, etc) — the dialog is meant as an
    // onboarding cue for new-premium accounts, not a recurring
    // notification.
    //
    // Why `ref.listen` instead of `useEffect(..., [])`? Because on a
    // cold start the profile Future is still pending when the post-
    // frame callback fires; `ref.read(...).value` returns null, and
    // `useEffect` never re-runs. Result: the dialog was silently
    // skipped on the launch it was meant for, and only appeared later
    // when some unrelated rebuild happened. The listener wakes up the
    // moment the profile lands, whenever that is.
    //
    // `checkAndShowPremiumWelcome` additionally guards via a
    // SharedPreferences flag — once shown for an account, it never
    // appears again, even across reinstalls of the home widget.
    final hasCheckedPremium = useState(false);
    ref.listen(getProfileInfoProvider, (prev, next) {
      if (hasCheckedPremium.value) return;
      final user = next.value;
      if (user == null) return; // profile still loading
      hasCheckedPremium.value = true; // arm-then-disarm
      if (user.userType != 'pre') return;
      // Defer one frame so showDialog doesn't race with the build that
      // delivered the profile value to us.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        // Only surface the modal while the user is actually looking at
        // /home (not a pushed subpage like repeat / a deeper screen).
        final currentRoute = ModalRoute.of(context);
        if (currentRoute?.isCurrent != true) return;
        checkAndShowPremiumWelcome(context, ref, user);
      });
    });

    return userAsync.when(
      loading: () => const HomeShimmerLoading(),
      error: (err, stack) {
        if (err is NoTokenException) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const StartPage()),
              (route) => false,
            );
          });
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        // Show SnackBar instead of full-screen error
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 20),
                    const SizedBox(width: 10),
                    Expanded(child: Text('no_internet_title'.tr())),
                  ],
                ),
                backgroundColor: const Color(0xFFEF4444),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'retry'.tr(),
                  textColor: Colors.white,
                  onPressed: () => ref.read(getProfileInfoProvider.notifier).getProfile(),
                ),
              ),
            );
          }
        });
        return const HomeShimmerLoading();
      },
      data: (user) {
        if (user == null) {
          // Профил null аст — дубора кӯшиш мекунем
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ref.invalidate(getProfileInfoProvider);
          });
          return const HomeShimmerLoading();
        }

        final isPremium = user.userType == 'pre';
        debugPrint(
          '[HomePage] user=${user.name}, userType=${user.userType}, isPremium=$isPremium',
        );

        // Keep energy notifier in sync with profile-derived premium status so
        // the gate stops applying the moment a purchase lands.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          ref.read(energyProvider.notifier).setPremium(isPremium);
        });

        // Note: `checkAndShowPremiumWelcome` is NOT called here anymore
        // because it was racing against `_checkForUpdate`. Both fire
        // together and the update dialog (which must win) arrived late
        // every time. The startup useEffect above now serialises them:
        // update-check resolves first; premium welcome is shown after
        // only if no update dialog was surfaced.

        ref.watch(localeProvider);
        // We pass the raw expiry to the header so it can pick the
        // right unit (days / hours / minutes) on every rebuild — the
        // previous integer-days API rounded down to 0 inside the last
        // 24 hours and the user saw "0 days left" for almost a full
        // day. `.toUtc()` normalizes the parse: the server may omit
        // the trailing "Z" on `tariff_expired_at`, and subtracting a
        // local-tz DateTime from a UTC `now` was leaking negative
        // counts to every user with a non-zero UTC offset.
        DateTime? expiryUtc;
        if (isPremium && user.tariffExpiredAt != null) {
          expiryUtc = DateTime.parse(user.tariffExpiredAt!).toUtc();
        }

        return SafeArea(
          child: Scaffold(
            backgroundColor: const Color(0xFFF5FAFF),
            body: RefreshIndicator(
              color: Colors.blue,
              onRefresh: () async {
                // Drop cached values first, then wait for every source to
                // actually finish refetching — otherwise the spinner
                // dismisses before the UI has the new data.
                ref.invalidate(profileRatingProvider);
                ref.invalidate(bannersControllerProvider);
                ref.invalidate(top3UsersDayProvider);

                Future<void> safe(Future<void> Function() op) async {
                  try {
                    await op();
                  } catch (_) {
                    // Swallow per-source errors so one failure doesn't block
                    // the rest — each widget shows its own error state.
                  }
                }

                await Future.wait([
                  safe(() => ref
                      .read(getProfileInfoProvider.notifier)
                      .getProfile()),
                  safe(() => ref
                      .read(progressProvider.notifier)
                      .fetchProgressFromBackend()),
                  safe(() => ref.read(profileRatingProvider.future)),
                  safe(() => ref.read(bannersControllerProvider.future)),
                  safe(() => ref.read(top3UsersDayProvider.future)),
                ]);
              },
              child: ListView(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 15,
                      horizontal: 15,
                    ),
                    child: Column(
                      children: [
                        HomeHeaderSection(
                          isPremium: isPremium,
                          expiryUtc: expiryUtc,
                        ),
                        const SizedBox(height: 10),
                        const HomeBannerSection(),
                        const SizedBox(height: 12),
                        const HomeStatsRow(),
                        const SizedBox(height: 4),
                        HomeActionButtons(userAsync: userAsync),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Check for app updates from server and show dialog if needed.
/// Returns `true` when an update dialog was surfaced so callers can skip
/// any subsequent "welcome" popups and avoid stacking two modals on top
/// of each other.
Future<bool> _checkForUpdate(BuildContext context, WidgetRef ref) async {
  try {
    final versionInfo = await ref.read(appVersionInfoProvider.future);
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final serverVersion = versionInfo.version;

    if (_compareVersions(serverVersion, currentVersion) > 0) {
      if (!context.mounted) return false;

      // Pick description for current locale
      final locale = context.locale.languageCode;
      final description = versionInfo.description[locale] ??
          versionInfo.description['tg'] ??
          versionInfo.description.values.firstOrNull ??
          '';

      if (versionInfo.updateRequired) {
        // Mandatory update — cannot dismiss
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => ForceUpdateDialog(
            version: serverVersion,
            description: description,
          ),
        );
      } else {
        // Optional update — can dismiss
        showDialog(
          context: context,
          builder: (_) => OptionalUpdateDialog(
            version: serverVersion,
            description: description,
          ),
        );
      }
      return true;
    }
  } catch (e) {
    debugPrint('⚠️ Version check failed: $e');
  }
  return false;
}

/// Compare two version strings (e.g. "2.56" vs "1.0.0").
/// Returns > 0 if v1 > v2, 0 if equal, < 0 if v1 < v2.
int _compareVersions(String v1, String v2) {
  final parts1 = v1.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final parts2 = v2.split('.').map((e) => int.tryParse(e) ?? 0).toList();
  final len = parts1.length > parts2.length ? parts1.length : parts2.length;
  for (int i = 0; i < len; i++) {
    final p1 = i < parts1.length ? parts1[i] : 0;
    final p2 = i < parts2.length ? parts2[i] : 0;
    if (p1 != p2) return p1 - p2;
  }
  return 0;
}
