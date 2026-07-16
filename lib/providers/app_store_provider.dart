import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/app_store_api.dart';
import '../models/app_store_item.dart';

/// App store search with retry support
class AppStoreNotifier extends AsyncNotifier<List<AppStoreItem>> {
  @override
  Future<List<AppStoreItem>> build() async {
    return _searchWithRetry();
  }

  Future<List<AppStoreItem>> _searchWithRetry({int maxRetries = 2}) async {
    for (int i = 0; i < maxRetries; i++) {
      try {
        return await _search();
      } catch (_) {
        if (i >= maxRetries - 1) rethrow;
        await Future.delayed(Duration(seconds: 1 + i));
      }
    }
    return [];
  }

  Future<List<AppStoreItem>> _search() async {
    final result = await AppStoreApi.search(page: 1, pageSize: 50);
    return List<AppStoreItem>.from(result['items'] ?? []);
  }

  Future<void> refresh() async {
    try {
      final data = await _search();
      state = AsyncValue.data(data);
    } catch (e, st) {
      if (state is! AsyncData) {
        state = AsyncValue.error(e, st);
      }
    }
  }
}

final appStoreProvider =
    AsyncNotifierProvider<AppStoreNotifier, List<AppStoreItem>>(
  AppStoreNotifier.new,
);

/// App detail by key
final appDetailProvider =
    FutureProvider.family<AppDetail, String>((ref, key) async {
  return AppStoreApi.getDetail(key);
});
