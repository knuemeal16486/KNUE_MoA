import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';

part 'application_model.g.dart';

@HiveType(typeId: 2) // Changed TypeId to 2 for new schema compatibility
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
  final String major; // 주전공
  @HiveField(6)
  final String studentId; // 학번
  @HiveField(7)
  final String gpa; // 학점 (4.5 만점 기준 등)
  @HiveField(8)
  final String selfIntroduction; // 자기소개서 내용
  @HiveField(9)
  final String etc; // 기타
  @HiveField(10)
  final String completedSemesters; // 이수 학기 수
  @HiveField(11)
  final String doubleMajor; // 복수/부전공
  @HiveField(12)
  final String birthDate; // 생년월일
  @HiveField(13)
  final String age; // 나이
  @HiveField(14)
  final String certifications; // 자격증
  @HiveField(15)
  final String volunteerHours; // 총 봉사시간

  ApplicationForm({
    String? id,
    required this.title,
    required this.name,
    required this.gender,
    required this.contact,
    required this.major,
    required this.studentId,
    required this.gpa,
    required this.selfIntroduction,
    this.etc = '',
    this.completedSemesters = '',
    this.doubleMajor = '',
    this.birthDate = '',
    this.age = '',
    this.certifications = '',
    this.volunteerHours = '',
  }) : id = id ?? const Uuid().v4();

  String toShareText() {
    final sb = StringBuffer();
    sb.writeln('[지원서: $title]');
    sb.writeln('이름: $name');
    sb.writeln('성별: $gender');
    sb.writeln('생년월일/나이: $birthDate ${age.isNotEmpty ? "($age세)" : ""}');
    sb.writeln('연락처: $contact');
    sb.writeln('학번: $studentId');
    sb.writeln('주전공: $major');
    if (doubleMajor.isNotEmpty) {
      sb.writeln('복수/부전공: $doubleMajor');
    }
    sb.writeln('평점평균: $gpa / 4.5');
    if (completedSemesters.isNotEmpty) {
      sb.writeln('이수학기: $completedSemesters학기');
    }
    if (certifications.isNotEmpty) {
      sb.writeln('자격증: $certifications');
    }
    if (volunteerHours.isNotEmpty) {
      sb.writeln('봉사시간: $volunteerHours시간');
    }
    sb.writeln('\n[자기소개서]');
    sb.writeln(selfIntroduction);
    if (etc.isNotEmpty) {
      sb.writeln('\n[기타]');
      sb.writeln(etc);
    }
    return sb.toString();
  }
}
