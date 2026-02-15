import 'package:hive/hive.dart';

part 'notice_model.g.dart'; // Hive 코드 생성

@HiveType(typeId: 0)
class Notice {
  @HiveField(0)
  final int id;
  @HiveField(1)
  final String category;
  @HiveField(2)
  final String group;
  @HiveField(3)
  final String title;
  @HiveField(4)
  final String date;
  @HiveField(5)
  final String author;
  @HiveField(6)
  final String link;
  @HiveField(7)
  final bool isNew;
  @HiveField(8)
  bool isRead; // 읽음 여부 (추후 활용)

  Notice({
    required this.id,
    required this.category,
    required this.group,
    required this.title,
    required this.date,
    required this.author,
    required this.link,
    this.isNew = false,
    this.isRead = false,
  });

  // 복사 메서드
  Notice copyWith({bool? isRead}) {
    return Notice(
      id: id,
      category: category,
      group: group,
      title: title,
      date: date,
      author: author,
      link: link,
      isNew: isNew,
      isRead: isRead ?? this.isRead,
    );
  }
}