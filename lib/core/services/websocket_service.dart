import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../constants/app_constants.dart';
import 'storage_service.dart';

/// WebSocket message types
enum WsMessageType {
  roomCreate,
  roomJoin,
  roomCheck,
  roomLeave,
  gameStart,
  gameAnswer,
  ping,
  pong,
  error,
  roomList,
  memberJoined,
  memberLeft,
  gameResult,
  roundStart,
  roundEnd,
}

/// WebSocket connection states
enum WsConnectionState { disconnected, connecting, connected, reconnecting }

/// WebSocket Service for Battle mode real-time communication
class WebSocketService {
  WebSocketChannel? _channel;
  WsConnectionState _state = WsConnectionState.disconnected;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;

  final StorageService _storage;

  // Stream controllers for different message types
  final _stateController = StreamController<WsConnectionState>.broadcast();
  final _messageController = StreamController<Map<String, dynamic>>.broadcast();
  final _roomListController =
      StreamController<List<Map<String, dynamic>>>.broadcast();
  final _gameEventController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  WebSocketService({required StorageService storage}) : _storage = storage;

  // ==================== Getters ====================

  WsConnectionState get state => _state;
  Stream<WsConnectionState> get stateStream => _stateController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;
  Stream<List<Map<String, dynamic>>> get roomListStream =>
      _roomListController.stream;
  Stream<Map<String, dynamic>> get gameEventStream =>
      _gameEventController.stream;
  Stream<String> get errorStream => _errorController.stream;

  bool get isConnected => _state == WsConnectionState.connected;

  // ==================== Connection ====================

  /// Connect to WebSocket server
  Future<void> connect() async {
    if (_state == WsConnectionState.connected ||
        _state == WsConnectionState.connecting) {
      return;
    }

    _updateState(WsConnectionState.connecting);

    try {
      final token = await _storage.getAccessToken();
      final uri = Uri.parse('${ApiConstants.wsGameUrl}?token=$token');

      _channel = WebSocketChannel.connect(uri);

      _channel!.stream.listen(_onMessage, onError: _onError, onDone: _onDone);

      _updateState(WsConnectionState.connected);
      _reconnectAttempts = 0;
      _startPing();

      debugPrint('WebSocket connected');
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
      _updateState(WsConnectionState.disconnected);
      _scheduleReconnect();
    }
  }

  /// Disconnect from WebSocket server
  void disconnect() {
    _stopPing();
    _reconnectTimer?.cancel();
    _channel?.sink.close();
    _channel = null;
    _updateState(WsConnectionState.disconnected);
    _reconnectAttempts = 0;
    debugPrint('WebSocket disconnected');
  }

  void _updateState(WsConnectionState newState) {
    _state = newState;
    _stateController.add(newState);
  }

  void _onMessage(dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String?;

      debugPrint('WebSocket message: $type');

      switch (type) {
        case 'pong':
          // Pong received, connection is alive
          break;
        case 'room_list':
          final rooms =
              (data['rooms'] as List?)?.cast<Map<String, dynamic>>() ?? [];
          _roomListController.add(rooms);
          break;
        case 'game_start':
        case 'round_start':
        case 'round_end':
        case 'game_result':
        case 'member_joined':
        case 'member_left':
          _gameEventController.add(data);
          break;
        case 'error':
          _errorController.add(data['message'] as String? ?? 'Unknown error');
          break;
        default:
          _messageController.add(data);
      }
    } catch (e) {
      debugPrint('WebSocket parse error: $e');
    }
  }

  void _onError(Object error) {
    debugPrint('WebSocket error: $error');
    _errorController.add(error.toString());
    _scheduleReconnect();
  }

  void _onDone() {
    debugPrint('WebSocket connection closed');
    _stopPing();
    if (_state != WsConnectionState.disconnected) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      debugPrint('Max reconnect attempts reached');
      _updateState(WsConnectionState.disconnected);
      return;
    }

    _updateState(WsConnectionState.reconnecting);
    final delay = Duration(seconds: (1 << _reconnectAttempts).clamp(1, 30));
    _reconnectAttempts++;

    debugPrint(
      'Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts)',
    );

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () {
      connect();
    });
  }

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _send({'type': 'ping'});
    });
  }

  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  // ==================== Send Messages ====================

  void _send(Map<String, dynamic> data) {
    if (_channel == null || !isConnected) {
      debugPrint('Cannot send: WebSocket not connected');
      return;
    }
    _channel!.sink.add(jsonEncode(data));
  }

  /// Create a new battle room
  void createRoom({
    required String name,
    required int maxPlayers,
    required int rounds,
    bool isPrivate = false,
  }) {
    _send({
      'type': 'room_create',
      'name': name,
      'max_players': maxPlayers,
      'rounds': rounds,
      'is_private': isPrivate,
    });
  }

  /// Join an existing room
  void joinRoom(String roomId) {
    _send({'type': 'room_join', 'room_id': roomId});
  }

  /// Leave current room
  void leaveRoom(String roomId) {
    _send({'type': 'room_leave', 'room_id': roomId});
  }

  /// Check room status
  void checkRoom(String roomId) {
    _send({'type': 'room_check', 'room_id': roomId});
  }

  /// Start the game (admin only)
  void startGame(String roomId) {
    _send({'type': 'game_start', 'room_id': roomId});
  }

  /// Send answer during game
  void sendAnswer({
    required String roomId,
    required int questionId,
    required int answerId,
    required int timeMs,
  }) {
    _send({
      'type': 'game_answer',
      'room_id': roomId,
      'question_id': questionId,
      'answer_id': answerId,
      'time_ms': timeMs,
    });
  }

  /// Request room list
  void refreshRoomList() {
    _send({'type': 'room_list'});
  }

  // ==================== Cleanup ====================

  void dispose() {
    disconnect();
    _stateController.close();
    _messageController.close();
    _roomListController.close();
    _gameEventController.close();
    _errorController.close();
  }
}
