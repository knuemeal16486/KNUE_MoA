class Notice {
  final String category; // '학사', '장학', '일반' 등
  final String title;
  final String date;
  final String author;
  final String link; // 클릭 시 이동할 링크
  final bool isNew;  // 새 글 여부 (날짜 기준 판단)

  Notice({
    required this.category,
    required this.title,
    required this.date,
    required this.author,
    required this.link,
    this.isNew = false,
  });
}