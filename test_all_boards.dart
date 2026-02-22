import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  final Map<String, String> boards = {
    '대학소식': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=25&key=806',
    '도서관일반': 'https://lib.knue.ac.kr/bbs/list/1',
    '종합연수원':
        'https://tot.knue.ac.kr/common/bbs/management/selectCmmnBBSMgmtList.do?menuId=3000001755&bbsId=BBSMSTR_003000000094',
    '신문방송사':
        'https://m.news.knue.ac.kr/news/articleList.html?sc_section_code=S1N3',
    '초등교육과': 'https://m.cafe.daum.net/knue-primary/HhZk',
    '체육교육과':
        'https://www.knue.ac.kr/phy/selectBbsNttList.do?bbsNo=211&key=1327',
    '교육정책대학원':
        'https://www.knue.ac.kr/edupol/selectBbsNttList.do?bbsNo=73&key=659',
  };

  for (var entry in boards.entries) {
    try {
      final response = await http
          .get(Uri.parse(entry.value), headers: {'User-Agent': 'Mozilla/5.0'})
          .timeout(const Duration(seconds: 5));

      var doc = parser.parse(
        utf8.decode(response.bodyBytes, allowMalformed: true),
      );
      var rows = doc.querySelectorAll('tbody tr');

      print(
        '${entry.key}: Status ${response.statusCode}, Rows: ${rows.length}',
      );

      for (int i = 0; i < rows.length; i++) {
        var row = rows[i];
        try {
          var titleEl = row.querySelector('.p-subject a');
          String title = titleEl?.text.trim() ?? '제목 없음';
          var tds = row.querySelectorAll('td');
          String date = tds.length > 4 ? tds[4].text.trim() : 'NO_DATE';
          // print('  $title ($date)');
        } catch (e) {
          print('  Error parsing row $i: $e');
        }
      }
    } catch (e) {
      print('Failed ${entry.key}: $e');
    }
  }
}
