// // lib/providers/category_archives_providers.dart
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:dio/dio.dart';
// import 'package:vozhaomuz/core/utils/category_pack_repository.dart';

// final dioProvider = Provider<Dio>((ref) => Dio());

// final categoryArchivesRepoProvider = Provider<CategoryArchivesRepository>(
//   (ref) => CategoryArchivesRepository(ref.read(dioProvider)),
// );

// /// Быстрая проверка (true = оба архива уже локально и валидны)
// final archivesExistProvider =
//     FutureProvider.family<bool, int>((ref, categoryId) async {
//   final repo = ref.read(categoryArchivesRepoProvider);
//   return repo.archivesExist(categoryId);
// });

// /// Контроллер загрузки с агрегированным прогрессом (0..1)
// class ArchivesDownloadController extends StateNotifier<AsyncValue<double>> {
//   ArchivesDownloadController(this._repo) : super(const AsyncData(1.0));
//   final CategoryArchivesRepository _repo;

//   bool _running = false;

//   Future<void> ensureDownloaded(int categoryId) async {
//     if (_running) return;
//     _running = true;
//     state = const AsyncLoading();

//     try {
//       final missing = await _repo.findMissing(categoryId);
//       if (missing.isEmpty) {
//         state = const AsyncData(1.0);
//       } else {
//         state = const AsyncData(0.0);
//         await _repo.downloadMissing(
//           categoryId: categoryId,
//           missing: missing,
//           onTotalProgress: (p) => state = AsyncData(p.clamp(0, 1)),
//         );
//         state = const AsyncData(1.0);
//       }
//     } catch (e, st) {
//       state = AsyncError(e, st);
//       rethrow;
//     } finally {
//       _running = false;
//     }
//   }
// }

// final archivesDownloadControllerProvider =
//     StateNotifierProvider<ArchivesDownloadController, AsyncValue<double>>(
//   (ref) => ArchivesDownloadController(ref.read(categoryArchivesRepoProvider)),
// );
