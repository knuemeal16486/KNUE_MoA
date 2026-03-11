import 'dart:io' show Platform;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:knue_moa/services/scraper_service.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:knue_moa/models/notice_model.dart';
import 'package:knue_moa/models/personal_schedule_model.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

// ─────────────────────────────────────────────────────────────────
// Workmanager 백그라운드 진입점 — @pragma 필수
// ─────────────────────────────────────────────────────────────────
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'check_new_notices_task') {
      try {
        // 백그라운드 격리 환경에서는 Hive를 별도로 초기화해야 함
        await Hive.initFlutter();
        if (!Hive.isAdapterRegistered(0)) {
          Hive.registerAdapter(NoticeAdapter());
        }
        if (!Hive.isAdapterRegistered(3)) {
          Hive.registerAdapter(PersonalScheduleAdapter());
        }

        final prefs = await SharedPreferences.getInstance();

        // 알림 설정 확인
        final isAlarmOn = prefs.getBool('alarm_on') ?? true;
        if (isAlarmOn) {
          final notices = await KnueScraper().fetchAllNotices(
            forceRefresh: true,
          );
          if (notices.isNotEmpty) {
            final bool initialized =
                prefs.getBool('notification_initialized') ?? false;

            if (!initialized) {
              final currentIds = notices
                  .take(50)
                  .map((n) => n.id.toString())
                  .toList();
              await prefs.setStringList('notified_ids', currentIds);
              await prefs.setBool('notification_initialized', true);
            } else {
              final favBoards = prefs.getStringList('fav_boards') ?? [];
              final keywords = prefs.getStringList('keywords') ?? [];
              final List<String> notifiedIds =
                  prefs.getStringList('notified_ids') ?? [];

              final List<Map<String, String>> newItems = [];
              final List<String> newNotifiedIds = List.from(notifiedIds);

              for (final notice in notices.take(50)) {
                final idStr = notice.id.toString();
                if (notifiedIds.contains(idStr)) continue;
                final inFav =
                    favBoards.isEmpty || favBoards.contains(notice.category);
                newNotifiedIds.add(idStr);
                if (!inFav) continue;
                final matchesKeyword =
                    keywords.isEmpty ||
                    keywords.any(
                      (kw) =>
                          notice.title.toLowerCase().contains(kw.toLowerCase()),
                    );
                if (matchesKeyword) {
                  newItems.add({
                    'category': notice.category,
                    'title': notice.title,
                  });
                }
              }

              if (newItems.isNotEmpty) {
                await _initPlugin();
                if (newItems.length == 1) {
                  await NotificationService.showNotification(
                    title: '[${newItems[0]['category']}] 새 공지사항',
                    body: newItems[0]['title']!,
                    channelId: 'knue_moa_notice_channel',
                    channelName: '공지사항 알림',
                  );
                } else {
                  final first = newItems[0];
                  await NotificationService.showNotification(
                    title: '새 공지사항 ${newItems.length}건',
                    body:
                        '[${first['category']}] ${first['title']} 외 ${newItems.length - 1}건',
                    channelId: 'knue_moa_notice_channel',
                    channelName: '공지사항 알림',
                  );
                }
              }

              final trimmed = newNotifiedIds.length > 100
                  ? newNotifiedIds.sublist(newNotifiedIds.length - 100)
                  : newNotifiedIds;
              await prefs.setStringList('notified_ids', trimmed);
            }
          }
        }

        // ── 달력 알림 체크 ──
        await _checkCalendarNotifications();
      } catch (e) {
        // ignore: avoid_print
        print('Background task error (notices): $e');
      }
    }

    return Future.value(true);
  });
}

/// 달력 알림 체크 (학사일정 + 개인일정)
Future<void> _checkCalendarNotifications() async {
  try {
    final prefs = await SharedPreferences.getInstance();

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ── 학사일정 알림 ──
    final academicAlarmOn = prefs.getBool('academic_alarm_on') ?? true;
    if (academicAlarmOn) {
      final alarmDays = prefs.getInt('academic_alarm_days') ?? 1;
      final targetDate = today.add(Duration(days: alarmDays));

      final scraper = KnueScraper();
      final events = await scraper.fetchCalendarEvents(
        targetDate.year,
        targetDate.month,
      );

      // 이미 알린 학사일정 ID 목록
      final notifiedAcademic = prefs.getStringList('notified_academic') ?? [];
      final newNotifiedAcademic = List<String>.from(notifiedAcademic);

      for (final event in events) {
        final eventStart = DateTime(
          event.startDate.year,
          event.startDate.month,
          event.startDate.day,
        );
        if (!eventStart.isAtSameMomentAs(targetDate)) continue;

        final eventId = '${event.title}_${event.startDate.toIso8601String()}';
        if (notifiedAcademic.contains(eventId)) continue;

        await _initPlugin();
        await NotificationService.showNotification(
          title: '📅 학사일정 알림 (${alarmDays}일 후)',
          body: event.title,
          channelId: 'knue_moa_calendar_channel',
          channelName: '학사일정 알림',
        );
        newNotifiedAcademic.add(eventId);
      }

      // 알림 기록 최대 200개 유지
      final trimmedAcademic = newNotifiedAcademic.length > 200
          ? newNotifiedAcademic.sublist(newNotifiedAcademic.length - 200)
          : newNotifiedAcademic;
      await prefs.setStringList('notified_academic', trimmedAcademic);
    }

    // ── 개인 일정 알림 ──
    final personalAlarmOn = prefs.getBool('personal_alarm_on') ?? true;
    if (personalAlarmOn) {
      if (!Hive.isAdapterRegistered(3)) {
        Hive.registerAdapter(PersonalScheduleAdapter());
      }
      const boxName = 'personal_schedules';
      final box = Hive.isBoxOpen(boxName)
          ? Hive.box<PersonalSchedule>(boxName)
          : await Hive.openBox<PersonalSchedule>(boxName);

      final notifiedPersonal = prefs.getStringList('notified_personal') ?? [];
      final newNotifiedPersonal = List<String>.from(notifiedPersonal);

      for (final schedule in box.values) {
        if (!schedule.notifyBefore) continue;

        final notifyAt = schedule.startDate.subtract(
          Duration(minutes: schedule.notifyMinutesBefore),
        );
        final notifyDay = DateTime(notifyAt.year, notifyAt.month, notifyAt.day);

        if (!notifyDay.isAtSameMomentAs(today)) continue;

        final scheduleId = '${schedule.id}_notify';
        if (notifiedPersonal.contains(scheduleId)) continue;

        await _initPlugin();
        final minutesBefore = schedule.notifyMinutesBefore;
        final timeLabel = minutesBefore >= 1440
            ? '${minutesBefore ~/ 1440}일 전'
            : minutesBefore >= 60
            ? '${minutesBefore ~/ 60}시간 전'
            : '${minutesBefore}분 전';
        await NotificationService.showNotification(
          title: '🗓️ 개인 일정 알림 ($timeLabel)',
          body: schedule.title,
          channelId: 'knue_moa_personal_channel',
          channelName: '개인 일정 알림',
        );
        newNotifiedPersonal.add(scheduleId);
      }

      final trimmedPersonal = newNotifiedPersonal.length > 200
          ? newNotifiedPersonal.sublist(newNotifiedPersonal.length - 200)
          : newNotifiedPersonal;
      await prefs.setStringList('notified_personal', trimmedPersonal);
    }
  } catch (e) {
    // ignore: avoid_print
    print('Calendar notification error: $e');
  }
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

  /// 알림 채널별 showNotification 범용 메서드
  static Future<void> showNotification({
    required String title,
    required String body,
    String channelId = 'knue_moa_notice_channel',
    String channelName = '공지사항 알림',
    String channelDesc = '새로운 알림을 알려드립니다.',
  }) async {
    final AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: channelDesc,
          importance: Importance.max,
          priority: Priority.high,
          ticker: title,
          playSound: true,
          enableVibration: true,
        );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

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
