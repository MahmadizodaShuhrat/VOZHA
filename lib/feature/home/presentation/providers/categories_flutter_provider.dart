import 'dart:async';

import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:vozhaomuz/feature/home/data/categories_repository.dart';
import 'package:vozhaomuz/feature/home/data/models/category_flutter_dto.dart';

/// Provider that fetches categories from GET /api/v1/dict/categories-flutter/list
final categoriesFlutterProvider =
    AsyncNotifierProvider<CategoriesFlutterNotifier, List<CategoryFlutterDto>>(
      CategoriesFlutterNotifier.new,
    );

class CategoriesFlutterNotifier
    extends AsyncNotifier<List<CategoryFlutterDto>> {
  final _repository = CategoriesRepository();

  @override
  FutureOr<List<CategoryFlutterDto>> build() async {
    return await _repository.getCategories();
  }

  /// Force refresh categories
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _repository.getCategories());
  }
}
