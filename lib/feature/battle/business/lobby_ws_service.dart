import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../data/ws_models.dart';

/// WebSocket-клиент для лобби — подписка на публичные комнаты.
/// Эндпоинт: /api/v1/ws/public-rooms
class LobbyWsService {
  static const String _lobbyUrl =
      'ws://62.72.35.72:8081/api/v1/ws/public-rooms';

  WebSocketChannel? _channel;
  final _roomsController = StreamController<List<PublicRoomInfo>>.broadcast();
  bool _isConnected = false;
  bool _disposed = false;

  /// Стрим обновлений списка публичных комнат.
  Stream<List<PublicRoomInfo>> get rooms => _roomsController.stream;

  bool get isConnected => _isConnected;

  Future<void> connect() async {
    if (_disposed) return;
    if (_isConnected) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_lobbyUrl));
      await _channel!.ready;

      _isConnected = true;
      debugPrint('[LobbyWS] Подключено к лобби');

      _channel!.stream.listen(
        _onMessage,
        onError: (e) {
          debugPrint('[LobbyWS] Ошибка: $e');
          _isConnected = false;
        },
        onDone: () {
          debugPrint('[LobbyWS] Соединение закрыто');
          _isConnected = false;
        },
      );
    } catch (e) {
      debugPrint('[LobbyWS] Ошибка подключения: $e');
      _isConnected = false;
    }
  }

  void sendRefresh() {
    if (!_isConnected || _channel == null) return;
    _channel!.sink.add(jsonEncode({'type': 'refresh'}));
  }

  void disconnect() {
    _isConnected = false;
    _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _roomsController.close();
  }

  void _onMessage(dynamic raw) {
    if (_disposed) return;
    try {
      final json = jsonDecode(raw as String);
      if (json is Map<String, dynamic> && json['type'] == 'public_rooms') {
        final roomsList =
            (json['rooms'] as List?)
                ?.map((e) => PublicRoomInfo.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        _roomsController.add(roomsList);
      }
    } catch (e) {
      debugPrint('[LobbyWS] Ошибка парсинга: $e');
    }
  }
}
