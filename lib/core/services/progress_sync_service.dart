import 'package:dio/dio.dart';
import 'package:vozhaomuz/core/constants/app_constants.dart';
import 'package:vozhaomuz/feature/progress/data/models/progress_models.dart';
import '../utils/progress_storage.dart';

class ProgressSyncService {
  static final _dio = Dio(BaseOptions(baseUrl: ApiConstants.baseUrl));

  /// первый вход: пытаемся скачать, иначе создаём пустой
  static Future<ProgressFile> pullIfExists(int userId, String token) async {
    try {
      final res = await _dio.get(
        '/files/progress/$userId.json',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );
      final data = ProgressFile.fromJson(res.data);
      await ProgressStorage.save(userId, data);
      return data;
    } catch (_) {
      final empty = ProgressFile.empty();
      await ProgressStorage.save(userId, empty);
      return empty;
    }
  }

  /// регулярная отправка
  static Future<void> push(int userId, String token) async {
    final data = await ProgressStorage.read(userId);
    await _dio.post(
      '/api/v1/dict/sync-progress',
      data: data.toJson(),
      options: Options(headers: {'Authorization': 'Bearer $token'}),
    );
  }
}
