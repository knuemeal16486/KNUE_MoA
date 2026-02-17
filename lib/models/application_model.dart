import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'application_model.g.dart';

@HiveType(typeId: 1) // Notice가 0번이므로 1번 사용
class ApplicationForm {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String title; // 지원서 별칭 (예: 멘토링용, 교환학생용)
  @HiveField(2)
  final String name;
  @HiveField(3)
  final String gender;
  @HiveField(4)
  final String contact;
  @HiveField(5)
  final String major;
  @HiveField(6)
  final String studentId; // 학번
  @HiveField(7)
  final String grade; // 학점
  @HiveField(8)
  final String selfIntroduction; // 자기소개서 내용
  @HiveField(9)
  final String etc; // 기타

  ApplicationForm({
    String? id,
    required this.title,
    required this.name,
    required this.gender,
    required this.contact,
    required this.major,
    required this.studentId,
    required this.grade,
    required this.selfIntroduction,
    this.etc = '',
  }) : id = id ?? const Uuid().v4();

  String toShareText() {
    return '''
[지원서: $title]
이름: $name
성별: $gender
연락처: $contact
학과: $major
학번: $studentId
학점: $grade

[자기소개서]
$selfIntroduction

[기타]
$etc
''';
  }
}