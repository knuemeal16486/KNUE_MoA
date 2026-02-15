import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knue_moa/models/notice_model.dart';
import 'package:knue_moa/services/scraper_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

// === 테마 관련 ===
final themeKeyProvider = StateProvider<String>((ref) => 'blue');

// === 키워드 관련 ===
final keywordsProvider = FutureProvider<List<String>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('keywords') ?? ['장학', '수강', '졸업'];
});

final keywordsNotifierProvider = StateNotifierProvider<KeywordsNotifier, List<String>>((ref) {
  return KeywordsNotifier();
});

class KeywordsNotifier extends StateNotifier<List<String>> {
  KeywordsNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList('keywords') ?? ['장학', '수강', '졸업'];
  }

  Future<void> add(String keyword) async {
    if (keyword.isEmpty || state.contains(keyword)) return;
    final newList = [...state, keyword];
    state = newList;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('keywords', newList);
  }

  Future<void> remove(String keyword) async {
    final newList = state.where((k) => k != keyword).toList();
    state = newList;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('keywords', newList);
  }
}

// === 즐겨찾기 관련 ===
final favoritesProvider = FutureProvider<List<int>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final strings = prefs.getStringList('favorites') ?? [];
  return strings.map(int.parse).toList();
});

final favoritesNotifierProvider = StateNotifierProvider<FavoritesNotifier, List<int>>((ref) {
  return FavoritesNotifier();
});

class FavoritesNotifier extends StateNotifier<List<int>> {
  FavoritesNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final strings = prefs.getStringList('favorites') ?? [];
    state = strings.map(int.parse).toList();
  }

  Future<void> toggle(int id) async {
    final newList = state.contains(id)
        ? state.where((i) => i != id).toList()
        : [...state, id];
    state = newList;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', newList.map((e) => e.toString()).toList());
  }
}

// === 알람 설정 ===
final alarmProvider = StateProvider<bool>((ref) => true);

// === 공지사항 데이터 (Hive 캐싱 + 스크래핑) ===
final noticesProvider = FutureProvider<List<Notice>>((ref) async {
  final scraper = KnueScraper();
  return scraper.fetchAllNotices(forceRefresh: false);
});

// 강제 새로고침용 provider (ref.refresh 용)
final refreshNoticesProvider = FutureProvider<List<Notice>>((ref) async {
  final scraper = KnueScraper();
  return scraper.fetchAllNotices(forceRefresh: true);
});