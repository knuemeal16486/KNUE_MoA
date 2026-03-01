import 'package:hive/hive.dart';

part 'personal_schedule_model.g.dart';

@HiveType(typeId: 3)
class PersonalSchedule extends HiveObject {
  @HiveField(0)
  final String id;

  @HiveField(1)
  String title;

  @HiveField(2)
  DateTime startDate;

  @HiveField(3)
  DateTime endDate;

  @HiveField(4)
  String? memo;

  @HiveField(5)
  int colorValue; // Color.value 저장

  @HiveField(6)
  bool notifyBefore; // 알림 여부

  @HiveField(7)
  int notifyMinutesBefore; // 몇 분 전 알림

  PersonalSchedule({
    required this.id,
    required this.title,
    required this.startDate,
    required this.endDate,
    this.memo,
    this.colorValue = 0xFF6366F1, // 기본 인디고
    this.notifyBefore = false,
    this.notifyMinutesBefore = 60,
  });
}
