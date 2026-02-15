class Notice {
  final int id;
  final String category; // 학사, 장학, 물리 등
  final String group;    // MAIN, ANNEX, DEPT, GRAD, NEWS
  final String title;
  final String date;
  final String author;
  final String link;     // 이동할 URL
  final bool isNew;

  Notice({
    required this.id,
    required this.category,
    required this.group,
    required this.title,
    required this.date,
    required this.author,
    required this.link,
    this.isNew = false,
  });
}