import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// WebSocket-клиент для основного игрового канала /ws/computation.
///
/// JWT передаётся в каждом JSON-сообщении (не в URL).
/// Поддерживает пинг, автореконнект, и корректную очистку ресурсов.
class BattleWsService {
  static const String _gameUrl =
      'wss://api.vozhaomuz.com/api/v1/ws/computation';
  static const Duration _pingInterval = Duration(seconds: 10);
  static const int _maxReconnectAttempts = 5;

  WebSocketChannel? _channel;
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  Timer? _pingTimer;
  bool _isConnected = false;
  bool _disposed = false;
  bool _shouldReconnect = false;
  int _reconnectAttempts = 0;
  /// Track whether we've connected at least once. Flips to true after the
  /// first successful `_doConnect`; subsequent successful connects are
  /// reconnects and fire `onReconnected`. Used by `BattleNotifier` to
  /// re-send an authenticated message after a drop (e.g. the app coming
  /// back from background). The backend's admin grace window calls
  /// `tryRestoreAdminSession` on the first authenticated frame of the
  /// fresh socket — without it the server deletes the room when the
  /// grace timer elapses, even if the client has silently reconnected.
  bool _hasEverConnected = false;

  /// Fires after a reconnect (NOT after the initial connect). The
  /// owning notifier uses it to re-arm the admin session on the server.
  void Function()? onReconnected;

  /// Buffered messages to send after reconnection.
  final List<String> _pendingMessages = [];

  /// Входящие JSON-сообщения от сервера.
  Stream<Map<String, dynamic>> get messages => _messageController.stream;

  bool get isConnected => _isConnected;

  // ── Подключение ──

  Future<void> connect() async {
    if (_disposed) return;
    if (_isConnected) return;

    _shouldReconnect = true;
    _reconnectAttempts = 0;

    await _doConnect();
  }

  Future<void> _doConnect() async {
    if (_disposed) return;
    if (_isConnected) return;

    try {
      _channel = WebSocketChannel.connect(Uri.parse(_gameUrl));
      await _channel!.ready;

      final wasReconnect = _hasEverConnected;
      _isConnected = true;
      _reconnectAttempts = 0;
      _hasEverConnected = true;
      debugPrint('[BattleWS] Подключено к $_gameUrl');

      _channel!.stream.listen(_onMessage, onError: _onError, onDone: _onDone);

      _startPing();

      // Flush pending messages — пас аз муваффақият пок мекунем
      if (_pendingMessages.isNotEmpty) {
        debugPrint(
          '[BattleWS] Отправка ${_pendingMessages.length} буферных сообщений',
        );
        final sent = <String>[];
        for (final msg in _pendingMessages) {
          try {
            _channel!.sink.add(msg);
            sent.add(msg);
          } catch (e) {
            debugPrint('[BattleWS] Ошибка отправки буферного сообщения: $e');
            break;
          }
        }
        _pendingMessages.removeWhere((m) => sent.contains(m));
      }

      // Fire the reconnect hook only on subsequent connects — the very
      // first `_doConnect` is the initial handshake, not a recovery.
      // BattleNotifier listens here to re-authenticate the fresh socket
      // before the backend's admin grace window elapses.
      if (wasReconnect) {
        try {
          onReconnected?.call();
        } catch (e) {
          debugPrint('[BattleWS] onReconnected callback error: $e');
        }
      }
    } catch (e) {
      debugPrint('[BattleWS] Ошибка подключения: $e');
      _isConnected = false;
      _tryReconnect();
    }
  }

  void disconnect() {
    _shouldReconnect = false;
    _stopPing();
    _isConnected = false;
    _pendingMessages.clear();
    _channel?.sink.close();
    _channel = null;
    debugPrint('[BattleWS] Отключено');
  }

  void dispose() {
    _disposed = true;
    disconnect();
    _messageController.close();
  }

  // ── Отправка сообщений ──

  void send(String jsonString) {
    if (!_isConnected || _channel == null) {
      debugPrint('[BattleWS] Нет подключения — буферизуем сообщение');
      _pendingMessages.add(jsonString);
      // Try to reconnect if we should
      if (_shouldReconnect && !_disposed) {
        _tryReconnect();
      }
      return;
    }
    try {
      _channel!.sink.add(jsonString);
    } catch (e) {
      debugPrint('[BattleWS] Ошибка отправки: $e — буферизуем');
      _pendingMessages.add(jsonString);
      _isConnected = false;
      _tryReconnect();
    }
  }

  void sendJson(Map<String, dynamic> msg) => send(jsonEncode(msg));

  // ── Автореконнект ──

  void _tryReconnect() {
    if (_disposed || !_shouldReconnect) return;
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('[BattleWS] Превышено макс. количество реконнектов');
      return;
    }

    _reconnectAttempts++;
    final delay = Duration(seconds: _reconnectAttempts); // 1s, 2s, 3s...
    debugPrint(
      '[BattleWS] Реконнект попытка $_reconnectAttempts через ${delay.inSeconds}с',
    );

    Future.delayed(delay, () {
      if (!_disposed && _shouldReconnect && !_isConnected) {
        _doConnect();
      }
    });
  }

  // ── Пинг ──

  void _startPing() {
    _stopPing();
    _pingTimer = Timer.periodic(_pingInterval, (_) {
      if (_isConnected && _channel != null) {
        try {
          _channel!.sink.add('Ping');
        } catch (e) {
          debugPrint('[BattleWS] Ошибка пинга: $e');
          _isConnected = false;
          _tryReconnect();
        }
      }
    });
  }

  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  // ── Обработка входящих ──

  void _onMessage(dynamic raw) {
    if (_disposed) return;
    final str = raw as String;
    if (str == 'Pong' || str == 'pong') return;

    try {
      final json = jsonDecode(str);
      if (json is Map<String, dynamic>) {
        _messageController.add(json);
      }
    } catch (e) {
      debugPrint('[BattleWS] Ошибка парсинга: $e');
    }
  }

  void _onError(Object error) {
    debugPrint('[BattleWS] Ошибка стрима: $error');
    _isConnected = false;
    if (!_disposed) {
      _messageController.addError(error);
      _tryReconnect();
    }
  }

  void _onDone() {
    debugPrint('[BattleWS] Соединение закрыто');
    _isConnected = false;
    _stopPing();
    _tryReconnect();
  }
}
