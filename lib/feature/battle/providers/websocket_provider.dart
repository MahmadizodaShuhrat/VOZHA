import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../business/battle_ws_service.dart';
import '../business/lobby_ws_service.dart';

/// Провайдер игрового WebSocket-сервиса.
final battleWsProvider = Provider<BattleWsService>((ref) {
  final svc = BattleWsService();
  ref.onDispose(svc.dispose);
  return svc;
});

/// Провайдер лобби WebSocket-сервиса.
final lobbyWsProvider = Provider<LobbyWsService>((ref) {
  final svc = LobbyWsService();
  ref.onDispose(svc.dispose);
  return svc;
});
