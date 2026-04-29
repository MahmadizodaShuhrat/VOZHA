import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../business/lobby_ws_service.dart';
import '../data/ws_models.dart';
import 'websocket_provider.dart';

/// Состояние лобби.
class LobbyState {
  final bool isConnected;
  final bool isLoading;
  final List<PublicRoomInfo> rooms;

  const LobbyState({
    this.isConnected = false,
    this.isLoading = false,
    this.rooms = const [],
  });

  LobbyState copyWith({
    bool? isConnected,
    bool? isLoading,
    List<PublicRoomInfo>? rooms,
  }) {
    return LobbyState(
      isConnected: isConnected ?? this.isConnected,
      isLoading: isLoading ?? this.isLoading,
      rooms: rooms ?? this.rooms,
    );
  }
}

final lobbyProvider = NotifierProvider<LobbyNotifier, LobbyState>(
  LobbyNotifier.new,
);

class LobbyNotifier extends Notifier<LobbyState> {
  LobbyWsService? _ws;
  StreamSubscription<List<PublicRoomInfo>>? _sub;

  @override
  LobbyState build() {
    ref.onDispose(() {
      _sub?.cancel();
    });
    return const LobbyState();
  }

  Future<void> connect() async {
    state = state.copyWith(isLoading: true);
    _ws = ref.read(lobbyWsProvider);

    await _ws!.connect();

    _sub?.cancel();
    _sub = _ws!.rooms.listen((rooms) {
      state = state.copyWith(rooms: rooms, isConnected: true, isLoading: false);
    });

    state = state.copyWith(isConnected: _ws!.isConnected, isLoading: false);
  }

  void refresh() {
    _ws?.sendRefresh();
  }

  /// Drop a closed room from the local list immediately, without
  /// waiting for the server's next `public_rooms` push. Used when the
  /// battle provider receives `delete_room` — the closed room would
  /// otherwise sit there for a beat and let other users tap into a
  /// dead invite. `refresh()` is still called in parallel to reconcile
  /// with the server's view on the next tick.
  void removeRoomOptimistic(String roomId) {
    if (roomId.isEmpty) return;
    final filtered = state.rooms
        .where((r) => r.roomId != roomId)
        .toList(growable: false);
    if (filtered.length == state.rooms.length) return;
    state = state.copyWith(rooms: filtered);
  }

  void disconnect() {
    _sub?.cancel();
    _ws?.disconnect();
    state = const LobbyState();
  }
}
