import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:intl/intl.dart';
import '../models/notice_model.dart';

class KnueScraper {
  // 게시판별 URL 및 ID 매핑
  final Map<String, String> boardUrls = {
    '일반': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=26&key=807',
    '학사': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=25&key=806',
    '장학': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=207&key=1443',
    // 필요 시 URL 추가 가능 (예: 채용, 행사 등)
  };

  // 전체 게시판 데이터 가져오기
  Future<List<Notice>> fetchAllNotices() async {
    List<Notice> allNotices = [];
    
    // 각 게시판을 병렬로 크롤링하여 속도 향상
    await Future.forEach(boardUrls.entries, (entry) async {
      List<Notice> notices = await _fetchNoticesFromBoard(entry.key, entry.value);
      allNotices.addAll(notices);
    });

    // 날짜 최신순 정렬
    allNotices.sort((a, b) => b.date.compareTo(a.date));
    return allNotices;
  }

  Future<List<Notice>> _fetchNoticesFromBoard(String category, String urlString) async {
    try {
      final response = await http.get(Uri.parse(urlString));
      
      if (response.statusCode == 200) {
        var document = parser.parse(response.body);
        List<Notice> notices = [];
        
        // 교원대 게시판 구조 (tbody tr)
        var rows = document.querySelectorAll('tbody tr'); 

        for (var row in rows) {
          var subjectElement = row.querySelector('.p-subject a');
          var tds = row.querySelectorAll('td');

          if (subjectElement != null && tds.length >= 5) {
            String title = subjectElement.text.trim();
            
            // 링크 생성 (단순화를 위해 리스트 URL로 연결. 상세 페이지 파싱은 추가 구현 필요)
            String fullLink = urlString; 

            // 교원대 테이블 구조: 번호 | 제목 | 첨부 | 담당부서(2) | 작성일(4) | 조회수
            // 인덱스는 0부터 시작하므로 담당부서는 2, 작성일은 4 (변동 가능성 있음)
            String author = tds.length > 2 ? tds[2].text.trim() : "학교"; 
            String date = tds.length > 4 ? tds[4].text.trim() : "";

            // '오늘' 날짜인지 확인하여 New 태그 표시
            bool isNew = _isToday(date);

            notices.add(Notice(
              category: category,
              title: title,
              date: date,
              author: author,
              link: fullLink,
              isNew: isNew,
            ));
          }
        }
        return notices;
      }
    } catch (e) {
      print("크롤링 에러 ($category): $e");
    }
    return [];
  }

  bool _isToday(String dateStr) {
    try {
      // 날짜 형식이 2024.03.15 라고 가정
      final now = DateTime.now();
      final formatter = DateFormat('yyyy.MM.dd');
      final todayStr = formatter.format(now);
      return dateStr == todayStr;
    } catch (e) {
      return false;
    }
  }
}