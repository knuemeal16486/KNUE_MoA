import 'package:hive/hive.dart';

part 'dday_model.g.dart';

@HiveType(typeId: 4)
class DDay extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  DateTime targetDate;

  @HiveField(3)
  int colorValue;

  DDay({
    required this.id,
    required this.title,
    required this.targetDate,
    this.colorValue = 0xFF6366F1,
  });

  /// 오늘로부터 D-Day 계산 (양수: 남은 날, 음수: 지난 날)
  int get daysLeft {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(targetDate.year, targetDate.month, targetDate.day);
    return target.difference(today).inDays;
  }

  String get ddayLabel {
    final d = daysLeft;
    if (d == 0) return 'D-Day';
    if (d > 0) return 'D-$d';
    return 'D+${d.abs()}';
  }
}
