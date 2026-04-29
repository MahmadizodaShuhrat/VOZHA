import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:vozhaomuz/app/bottom_navigation_bar/presentation/screens/navigation_bar.dart';

/// Holds a battle room code captured from an incoming deep link so the
/// battle UI can auto-fill it once the widget tree reaches the JoinRoom
/// tab. Cleared by the consumer after it's been applied.
final pendingBattleInviteProvider =
    NotifierProvider<PendingBattleInviteNotifier, String?>(
      PendingBattleInviteNotifier.new,
    );

class PendingBattleInviteNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void set(String roomId) => state = roomId;
  void clear() => state = null;
}

/// Singleton that owns the `app_links` subscription. Invoked once from
/// `main.dart` after the Riverpod container is built. Handles BOTH the
/// cold-start URI (`getInitialAppLink`) and any subsequent URIs while
/// the app is running (`uriLinkStream`).
class DeepLinkService {
  DeepLinkService._();
  static final DeepLinkService instance = DeepLinkService._();

  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _sub;
  bool _started = false;

  /// Start listening. Safe to call more than once — later calls are
  /// no-ops. Pass the app's [ProviderContainer] so we can stash the
  /// incoming room id, and the [GoRouter] so we can navigate once the
  /// home shell is ready.
  Future<void> start({
    required ProviderContainer container,
    required GoRouter router,
  }) async {
    if (_started) return;
    _started = true;

    // Cold start: app was launched directly from a tap on the link.
    try {
      final initial = await _appLinks.getInitialLink();
      if (initial != null) {
        _handle(initial, container: container, router: router);
      }
    } catch (e) {
      debugPrint('⚠️ [DeepLink] getInitialLink failed: $e');
    }

    // Warm start: a link arrived while the app was running.
    _sub = _appLinks.uriLinkStream.listen((uri) {
      _handle(uri, container: container, router: router);
    }, onError: (e) {
      debugPrint('⚠️ [DeepLink] uriLinkStream error: $e');
    });
  }

  void _handle(
    Uri uri, {
    required ProviderContainer container,
    required GoRouter router,
  }) {
    debugPrint('🔗 [DeepLink] received: $uri');

    // Two URL shapes we accept for a battle invite:
    //
    //   1. https://api.vozhaomuz.com/api/v1/deeplink?page=battle&room_id=X
    //      The proper universal link — works once the backend publishes
    //      /.well-known/assetlinks.json (Android) +
    //      /.well-known/apple-app-site-association (iOS). Here `battle`
    //      arrives as a query param (`page=battle`) and the code as
    //      `room_id`.
    //
    //   2. vozhaomuz://battle?room_id=X
    //      Custom-scheme fallback registered in AndroidManifest +
    //      Info.plist. Required because Telegram's in-app browser never
    //      honors universal links, and because shape (1) can't verify
    //      until the backend ships those files. Here `battle` is the
    //      URI host, not a `page` query parameter.
    final isUniversalBattle = uri.queryParameters['page'] == 'battle';
    final isCustomBattle =
        uri.scheme == 'vozhaomuz' && uri.host == 'battle';
    if (!isUniversalBattle && !isCustomBattle) return;

    final roomId = uri.queryParameters['room_id'];
    if (roomId == null || roomId.isEmpty) return;

    container.read(pendingBattleInviteProvider.notifier).set(roomId);
    // Flip the bottom-nav tab to Battle (index 3 after Courses tab was
    // inserted) so the user lands inside the battle shell once /home
    // is reached. BattlePage reads `pendingBattleInviteProvider` and
    // switches its inner tab to "Join" when the invite is live.
    container.read(bottomNavProvider.notifier).setIndex(3);
    // Navigate into the main shell. The router redirect logic
    // handles the auth gate — if the user is signed out they land
    // in the login flow instead, but the invite stays pinned in the
    // provider so we can apply it the moment they reach /home.
    router.go('/home');
    debugPrint('🔗 [DeepLink] stored battle invite roomId=$roomId');
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    _started = false;
  }
}
