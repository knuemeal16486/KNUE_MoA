import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:knue_moa/services/scraper_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:knue_moa/models/notice_model.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ─────────────────────────────────────────────────────────────────
// Workmanager 백그라운드 진입점 — @pragma 필수
// ─────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task != 'check_new_notices_task') return Future.value(true);

    try {
      // 백그라운드 격리 환경에서는 Hive를 별도로 초기화해야 함
      await Hive.initFlutter();
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(NoticeAdapter());
      }

      final prefs = await SharedPreferences.getInstance();

      // 알림 설정 확인
      final isAlarmOn = prefs.getBool('alarm_on') ?? true;
      if (!isAlarmOn) return Future.value(true);

      // 공지사항 새로 가져오기
      final scraper = KnueScraper();
      final notices = await scraper.fetchAllNotices(forceRefresh: true);
      if (notices.isEmpty) return Future.value(true);

      // 첫 실행 여부 확인
      final bool initialized =
          prefs.getBool('notification_initialized') ?? false;

      if (!initialized) {
        // 첫 실행: 현재 최신 글 ID를 기준선으로 저장하고 알림은 보내지 않음
        final currentIds = notices
            .take(50)
            .map((n) => n.id.toString())
            .toList();
        await prefs.setStringList('notified_ids', currentIds);
        await prefs.setBool('notification_initialized', true);
        return Future.value(true);
      }

      // 즐겨찾기 게시판 · 키워드 로드
      final favBoards = prefs.getStringList('fav_boards') ?? [];
      final keywords = prefs.getStringList('keywords') ?? [];
      final List<String> notifiedIds =
          prefs.getStringList('notified_ids') ?? [];

      // ── 새 글 탐지 ──
      final List<Map<String, String>> newItems = [];
      final List<String> newNotifiedIds = List.from(notifiedIds);

      for (final notice in notices.take(50)) {
        final idStr = notice.id.toString();

        // 이미 알림 보낸 글이면 스킵
        if (notifiedIds.contains(idStr)) continue;

        // 즐겨찾기 게시판 필터: 비어 있으면 전체, 있으면 해당 게시판만
        final inFav = favBoards.isEmpty || favBoards.contains(notice.category);

        // ID는 항상 기록 (알림 여부와 무관하게 중복 방지)
        newNotifiedIds.add(idStr);

        if (!inFav) continue;

        // 키워드 필터: 키워드가 없으면 전부, 있으면 제목에 포함된 것만
        final matchesKeyword =
            keywords.isEmpty ||
            keywords.any(
              (kw) => notice.title.toLowerCase().contains(kw.toLowerCase()),
            );

        if (matchesKeyword) {
          newItems.add({'category': notice.category, 'title': notice.title});
        }
      }

      // ── 알림 발송 ──
      if (newItems.isNotEmpty) {
        // 백그라운드 격리 환경에서도 로컬 알림 플러그인 재초기화
        await _initPlugin();

        if (newItems.length == 1) {
          await NotificationService.showNotification(
            title: '[${newItems[0]['category']}] 새 공지사항',
            body: newItems[0]['title']!,
          );
        } else {
          final first = newItems[0];
          final rest = newItems.length - 1;
          await NotificationService.showNotification(
            title: '새 공지사항 ${newItems.length}건',
            body: '[${first['category']}] ${first['title']} 외 $rest건',
          );
        }
      }

      // ── notified_ids 최대 100개로 유지 (오래된 것부터 삭제) ──
      final trimmed = newNotifiedIds.length > 100
          ? newNotifiedIds.sublist(newNotifiedIds.length - 100)
          : newNotifiedIds;
      await prefs.setStringList('notified_ids', trimmed);
    } catch (e) {
      // ignore: avoid_print
      print('Background task error: $e');
    }

    return Future.value(true);
  });
}

/// 플러그인 초기화 헬퍼 (포어그라운드 & 백그라운드 공용)
Future<void> _initPlugin() async {
  const AndroidInitializationSettings androidInit =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const DarwinInitializationSettings iosInit = DarwinInitializationSettings();
  await flutterLocalNotificationsPlugin.initialize(
    settings: const InitializationSettings(android: androidInit, iOS: iosInit),
  );
}

// ─────────────────────────────────────────────────────────────────
// NotificationService
// ─────────────────────────────────────────────────────────────────
class NotificationService {
  static Future<void> init() async {
    // ── 플러그인 초기화 설정 ──
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    // Windows 전용 설정 (없으면 Windows에서 실행 시 예외 발생)
    const WindowsInitializationSettings initializationSettingsWindows =
        WindowsInitializationSettings(
          appName: 'KNUE MoA',
          appUserModelId: 'com.knue.knuemoa',
          guid: 'd3b3b3b3-b3b3-b3b3-b3b3-b3b3b3b3b3b3',
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          windows: initializationSettingsWindows,
        );

    // Android 13+ 알림 권한 요청
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    // iOS 알림 권한 요청
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    // ── Workmanager는 Android / iOS 전용 (Windows에서는 사용 불가) ──
    if (Platform.isAndroid || Platform.isIOS) {
      await Workmanager().initialize(callbackDispatcher);

      // ExistingPeriodicWorkPolicy.keep: 이미 같은 uniqueName으로 등록된 태스크가 있으면 유지
      await Workmanager().registerPeriodicTask(
        'check_new_notices',
        'check_new_notices_task',
        frequency: const Duration(minutes: 15),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
        constraints: Constraints(networkType: NetworkType.connected),
      );
    }
  }

  /// 로컬 푸시 알림 표시
  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    // Android 채널 설정
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'knue_moa_notice_channel',
          '공지사항 알림',
          channelDescription: '새로운 공지사항을 알려드립니다.',
          importance: Importance.max,
          priority: Priority.high,
          ticker: '새 공지사항',
          playSound: true,
          enableVibration: true,
        );

    // iOS 알림 설정 (이전 코드에서 누락 → iOS에서 알림이 표시되지 않던 원인)
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // 알림 ID: 시간 기반으로 고유하게 생성 (같은 ID를 쓰면 이전 알림이 덮어써짐)
    final notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000 & 0x7FFFFFFF;

    await flutterLocalNotificationsPlugin.show(
      id: notifId,
      title: title,
      body: body,
      notificationDetails: platformDetails,
    );
  }

  /// 알림 초기화 상태 리셋 (설정 화면에서 "알림 초기화" 버튼 시 호출)
  static Future<void> resetNotificationState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('notified_ids');
    await prefs.remove('notification_initialized');
  }
}
