import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/storage_service.dart';
import '../services/websocket_service.dart';

/// Storage Service Provider (singleton)
final storageServiceProvider = Provider<StorageService>((ref) {
  return StorageService.instance;
});

/// API Service Provider
final apiServiceProvider = Provider<ApiService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return ApiService(storage: storage);
});

/// Database Service Provider (singleton)
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

/// WebSocket Service Provider
final webSocketServiceProvider = Provider<WebSocketService>((ref) {
  final storage = ref.watch(storageServiceProvider);
  final service = WebSocketService(storage: storage);
  
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

/// WebSocket Connection State Provider
final wsConnectionStateProvider = StreamProvider<WsConnectionState>((ref) {
  final wsService = ref.watch(webSocketServiceProvider);
  return wsService.stateStream;
});

/// Auth state - whether user is logged in
final isLoggedInProvider = FutureProvider<bool>((ref) async {
  final storage = ref.watch(storageServiceProvider);
  final token = await storage.getAccessToken();
  return token != null && token.isNotEmpty;
});

/// User ID provider
final currentUserIdProvider = Provider<int?>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.getUserId();
});

/// Premium status provider
final isPremiumProvider = Provider<bool>((ref) {
  final storage = ref.watch(storageServiceProvider);
  return storage.isPremium();
});
