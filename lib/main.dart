import 'dart:io' show Platform;
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:knue_moa/constants/theme_constants.dart';
import 'package:knue_moa/models/notice_model.dart';
import 'package:knue_moa/models/personal_schedule_model.dart';
import 'package:knue_moa/models/dday_model.dart';
import 'package:knue_moa/providers/providers.dart';
import 'package:knue_moa/screens/home_page.dart';
import 'package:knue_moa/services/scraper_service.dart';
import 'package:knue_moa/models/application_model.dart';
import 'package:knue_moa/services/notification_service.dart';
import 'package:home_widget/home_widget.dart';
import 'package:firebase_core/firebase_core.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase 초기화 (config 파일이 없을 경우 에러가 날 수 있으므로 try-catch 또는 수동 추가 확인 필요)
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint("Firebase initialization failed: $e");
    debugPrint(
      "Please add google-services.json to android/app and GoogleService-Info.plist to ios/Runner",
    );
  }

  await NotificationService.init();

  // home_widget은 Android / iOS 전용 (Windows에서는 스킵)
  if (Platform.isAndroid || Platform.isIOS) {
    await HomeWidget.setAppGroupId('group.com.knuemoa.app');
  }

  await Hive.initFlutter();
  Hive.registerAdapter(NoticeAdapter());
  Hive.registerAdapter(ApplicationFormAdapter());
  Hive.registerAdapter(PersonalScheduleAdapter());
  Hive.registerAdapter(DDayAdapter());
  await Hive.openBox<Notice>(KnueScraper.noticeBoxName);
  await Hive.openBox<PersonalSchedule>(PersonalScheduleNotifier.boxName);
  await Hive.openBox<DDay>(DDayNotifier.boxName);

  // Riverpod: ProviderScope를 루트로 두어 전역 상태·의존성 주입 제공
  runApp(const ProviderScope(child: KnueMoaApp()));
}

class KnueMoaApp extends ConsumerWidget {
  const KnueMoaApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 테마만 변경될 때만 리빌드되도록 watch
    final primaryColor = ref.watch(themeColorProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'KNUE MoA',
      theme: AppTheme.getTheme(primaryColor, Brightness.light),
      darkTheme: AppTheme.getTheme(primaryColor, Brightness.dark),
      themeMode: themeMode,
      home: const HomePage(),
    );
  }
}
