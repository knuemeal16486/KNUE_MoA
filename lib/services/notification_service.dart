import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:knue_moa/services/scraper_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    if (task == 'check_new_notices_task') {
      try {
        final prefs = await SharedPreferences.getInstance();
        final isAlarmOn = prefs.getBool('alarm_on') ?? true;
        if (!isAlarmOn) return Future.value(true);

        final scraper = KnueScraper();
        final notices = await scraper.fetchAllNotices(forceRefresh: true);
        if (notices.isEmpty) return Future.value(true);

        final favBoards = prefs.getStringList('fav_boards') ?? [];
        final latestNotices = notices.take(10).toList();

        // Check if there are unnotified notices, by comparing with a saved list of recently notified IDs
        List<String> notifiedIds = prefs.getStringList('notified_ids') ?? [];
        List<String> newNotifiedIds = List.from(notifiedIds);

        bool hasNewNotices = false;
        String latestBoard = '';

        for (var idx = 0; idx < latestNotices.length; idx++) {
          final notice = latestNotices[idx];
          if (!notifiedIds.contains(notice.id.toString())) {
            if (favBoards.contains(notice.category) || favBoards.isEmpty) {
              hasNewNotices = true;
              latestBoard = notice.category;
              newNotifiedIds.add(notice.id.toString());
            } else if (idx < 3) {
              // If it's very recent but not in fav boards, still notify?
              // The prompt says: "알람이 오면 '00에 새 공지글이 올라왔습니다'". So let's just notify for anything or only favorites? Let's notify for favorites, or if none, any. Let's just notify for the top new ones.
              hasNewNotices = true;
              latestBoard = notice.category;
              newNotifiedIds.add(notice.id.toString());
            }
          }
        }

        if (hasNewNotices) {
          await NotificationService.showNotification(
            title: '새 공지사항 알림',
            body: '$latestBoard에 새 공지글이 올라왔습니다.',
          );
        }

        // Keep only top 50 in the notified list
        if (newNotifiedIds.length > 50) {
          newNotifiedIds = newNotifiedIds.sublist(newNotifiedIds.length - 50);
        }
        await prefs.setStringList('notified_ids', newNotifiedIds);
      } catch (e) {
        print('Background task error: $e');
      }
    }
    return Future.value(true);
  });
}

class NotificationService {
  static Future<void> init() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    // Request permissions for Android 13+
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();

    // Request permissions for iOS
    flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
    );

    Workmanager().initialize(callbackDispatcher, isInDebugMode: false);

    // Register a periodic task
    Workmanager().registerPeriodicTask(
      'check_new_notices',
      'check_new_notices_task',
      frequency: const Duration(
        minutes: 60,
      ), // minimum is usually 15 mins for android, 60 is safe
      constraints: Constraints(
        networkType:
            NetworkType.connected, // Only run when connected to internet
      ),
    );
  }

  static Future<void> showNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
          'knue_moa_notice_channel',
          '공지사항 알림',
          channelDescription: '새로운 공지사항을 알려드립니다.',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker',
        );
    const NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
    );
    await flutterLocalNotificationsPlugin.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: 'item x',
    );
  }
}
