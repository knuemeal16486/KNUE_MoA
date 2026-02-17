import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:knue_moa/constants/theme_constants.dart';
import 'package:knue_moa/models/notice_model.dart';
import 'package:knue_moa/models/application_model.dart';
import 'package:knue_moa/services/scraper_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hive/hive.dart';
import 'dart:async';
import 'dart:convert';

// === 테마 색상 관련 ===
final themeColorProvider = StateNotifierProvider<ThemeColorNotifier, Color>((ref) {
  return ThemeColorNotifier();
});

class ThemeColorNotifier extends StateNotifier<Color> {
  ThemeColorNotifier() : super(AppTheme.palette[0]) { _load(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final colorValue = prefs.getInt('theme_color');
    if (colorValue != null) state = Color(colorValue);
  }
  Future<void> setColor(Color color) async {
    state = color;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_color', color.value);
  }
}

// === 테마 모드 관련 ===
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) { _load(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt('theme_mode');
    if (index != null) state = ThemeMode.values[index];
  }
  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', mode.index);
  }
}

// === 읽은 게시글 관리 ===
final readNoticesProvider = StateNotifierProvider<ReadNoticesNotifier, List<int>>((ref) {
  return ReadNoticesNotifier();
});

class ReadNoticesNotifier extends StateNotifier<List<int>> {
  ReadNoticesNotifier() : super([]) { _load(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final strings = prefs.getStringList('read_notices') ?? [];
    state = strings.map(int.parse).toList();
  }
  Future<void> markAsRead(int id) async {
    if (state.contains(id)) return;
    final newList = [...state, id];
    state = newList;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('read_notices', newList.map((e) => e.toString()).toList());
  }
}

// === 키워드 관련 ===
final keywordsProvider = FutureProvider<List<String>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getStringList('keywords') ?? ['장학', '수강', '졸업'];
});

final keywordsNotifierProvider = StateNotifierProvider<KeywordsNotifier, List<String>>((ref) {
  return KeywordsNotifier();
});

class KeywordsNotifier extends StateNotifier<List<String>> {
  KeywordsNotifier() : super([]) { _load(); }
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

// === 게시글 즐겨찾기 ===
final favoritesProvider = FutureProvider<List<int>>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final strings = prefs.getStringList('favorites') ?? [];
  return strings.map(int.parse).toList();
});

final favoritesNotifierProvider = StateNotifierProvider<FavoritesNotifier, List<int>>((ref) {
  return FavoritesNotifier();
});

class FavoritesNotifier extends StateNotifier<List<int>> {
  FavoritesNotifier() : super([]) { _load(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final strings = prefs.getStringList('favorites') ?? [];
    state = strings.map(int.parse).toList();
  }
  Future<void> toggle(int id) async {
    final newList = state.contains(id) ? state.where((i) => i != id).toList() : [...state, id];
    state = newList;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favorites', newList.map((e) => e.toString()).toList());
  }
}

// === 게시판 즐겨찾기 (게시판 이름 저장) ===
final boardFavoritesProvider = StateNotifierProvider<BoardFavoritesNotifier, List<String>>((ref) {
  return BoardFavoritesNotifier();
});

class BoardFavoritesNotifier extends StateNotifier<List<String>> {
  BoardFavoritesNotifier() : super([]) { _load(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getStringList('fav_boards') ?? [];
  }
  Future<void> toggle(String boardName) async {
    if (boardName == 'ALL' || boardName == '전체') return; 
    final newList = state.contains(boardName)
        ? state.where((b) => b != boardName).toList()
        : [...state, boardName];
    state = newList;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('fav_boards', newList);
  }
}

// === 게시글 클릭 기록 (AI 추천용) ===
final clickHistoryProvider = StateNotifierProvider<ClickHistoryNotifier, Map<String, int>>((ref) {
  return ClickHistoryNotifier();
});

class ClickHistoryNotifier extends StateNotifier<Map<String, int>> {
  ClickHistoryNotifier() : super({}) { _load(); }
  
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('click_history');
    if (jsonStr != null) {
      state = Map<String, int>.from(json.decode(jsonStr));
    }
  }

  Future<void> logClick(String title) async {
    final words = title.split(' ').where((w) => w.length >= 2).take(3);
    final newState = Map<String, int>.from(state);
    
    for (var word in words) {
      newState[word] = (newState[word] ?? 0) + 1;
    }
    
    state = newState;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('click_history', json.encode(newState));
  }
}

// === [수정] 나의 지원서 관리 (프리징 해결 및 안정성 강화) ===
final applicationProvider = StateNotifierProvider<ApplicationNotifier, List<ApplicationForm>>((ref) {
  return ApplicationNotifier();
});

class ApplicationNotifier extends StateNotifier<List<ApplicationForm>> {
  ApplicationNotifier() : super([]) { _load(); }

  static const String boxName = 'applications_v2'; // 박스 이름 변경하여 충돌 방지

  // 박스를 안전하게 여는 헬퍼 함수
  Future<Box<ApplicationForm>> _getBox() async {
    if (!Hive.isBoxOpen(boxName)) {
      return await Hive.openBox<ApplicationForm>(boxName);
    }
    return Hive.box<ApplicationForm>(boxName);
  }

  Future<void> _load() async {
    try {
      final box = await _getBox();
      // ID를 키로 사용하여 정렬된 상태로 가져오기 (최신순 등 필요시 로직 추가)
      state = box.values.toList().reversed.toList(); // 최신순으로 보여주기 위해 역순 정렬
    } catch (e) {
      print("Error loading applications: $e");
      state = [];
    }
  }

  Future<void> save(ApplicationForm form) async {
    try {
      final box = await _getBox();
      // ID를 Key로 사용하여 저장 (없으면 추가, 있으면 덮어쓰기)
      await box.put(form.id, form);
      await _load(); // 상태 새로고침
    } catch (e) {
      print("Error saving application: $e");
      // 에러 처리 로직 (예: 스낵바 표시)이 필요할 수 있음
      rethrow; // UI에서 catch 할 수 있도록 rethrow
    }
  }

  Future<void> delete(String id) async {
    try {
      final box = await _getBox();
      await box.delete(id);
      await _load(); // 상태 새로고침
    } catch (e) {
      print("Error deleting application: $e");
    }
  }
}

// === AI 추천 서비스 (Gemini) ===
final aiRecommendationProvider = FutureProvider<List<Notice>>((ref) async {
  final notices = await ref.watch(noticesProvider.future);
  if (notices.isEmpty) return [];

  final clickHistory = ref.read(clickHistoryProvider);
  final keywords = ref.read(keywordsNotifierProvider);
  final favBoards = ref.read(boardFavoritesProvider);

  // 1. 3개월 이내 공지 필터링
  final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
  final recentNotices = notices.where((n) {
    try {
      final date = DateTime.parse(n.date.replaceAll('.', '-'));
      return date.isAfter(threeMonthsAgo);
    } catch (e) {
      return false;
    }
  }).toList();

  if (recentNotices.isEmpty) return [];

  // 2. Gemini 호출
  const apiKey = 'AIzaSyAaeyQada46oab0XgbHzjajmHM4cDYARnQ'; 
  final model = GenerativeModel(model: 'gemini-1.5-flash', apiKey: apiKey);

  final candidateCount = recentNotices.length > 50 ? 50 : recentNotices.length;
  final candidates = recentNotices.take(candidateCount).toList();
  
  final candidatesJson = candidates.map((n) => {
    'id': n.id,
    'title': n.title,
    'category': n.category
  }).toList();

  final prompt = '''
  당신은 대학생을 위한 공지사항 추천 AI입니다.
  
  [사용자 정보]
  - 관심 키워드: ${keywords.join(', ')}
  - 자주 방문하는 게시판: ${favBoards.join(', ')}
  - 많이 클릭한 단어: ${clickHistory.keys.take(10).join(', ')}
  
  [최근 공지사항 목록 (최대 50개)]
  ${jsonEncode(candidatesJson)}
  
  위 사용자 정보를 바탕으로, 이 사용자가 가장 관심을 가질만한 공지사항 3개를 추천해주세요.
  
  응답 형식은 반드시 아래와 같은 순수한 JSON Array여야 합니다. Markdown 코드 블럭 없이 JSON만 출력하세요.
  [id1, id2, id3]
  ''';

  try {
    final content = [Content.text(prompt)];
    final response = await model.generateContent(content);
    final text = response.text?.replaceAll('```json', '').replaceAll('```', '').trim() ?? '[]';
    
    final List<dynamic> recommendedIds = jsonDecode(text);
    
    final recommendations = candidates
        .where((n) => recommendedIds.contains(n.id))
        .toList();
        
    return recommendations.take(3).toList();
  } catch (e) {
    print('AI Error: $e');
    return recentNotices.take(3).toList();
  }
});

// === 알람 설정 ===
final alarmProvider = StateProvider<bool>((ref) => true);

// === 공지사항 데이터 ===
final noticesProvider = FutureProvider<List<Notice>>((ref) async {
  final scraper = KnueScraper();
  return scraper.fetchAllNotices(forceRefresh: false);
});

final refreshNoticesProvider = FutureProvider<List<Notice>>((ref) async {
  final scraper = KnueScraper();
  return scraper.fetchAllNotices(forceRefresh: true);
});