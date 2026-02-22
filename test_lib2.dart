import 'package:knue_moa/services/scraper_service.dart';
import 'package:hive/hive.dart';
import 'package:knue_moa/models/notice_model.dart';
import 'package:hive_flutter/hive_flutter.dart';

void main() async {
  await Hive.initFlutter();
  Hive.registerAdapter(NoticeAdapter());

  final scraper = KnueScraper();
  print('Testing Library (General)...');
  try {
    var general = await scraper.fetchAllNotices(forceRefresh: true);
    var libNotices = general
        .where((n) => n.group == 'ANNEX' && n.category.contains('도서관'))
        .toList();
    if (libNotices.isEmpty) {
      print('No library notices found among ${general.length} total notices.');
    } else {
      print('Found ${libNotices.length} library notices!');
      for (var n in libNotices.take(5)) {
        print('- ${n.title} (${n.date})');
      }
    }
  } catch (e) {
    print('Failed: $e');
  }
}
