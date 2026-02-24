import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'dart:convert';

void main() async {
  var urls = [
    'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=25&key=806',
    'https://www.knue.ac.kr/phy/selectBbsNttList.do?bbsNo=211&key=1327',
    'https://tot.knue.ac.kr/common/bbs/management/selectCmmnBBSMgmtList.do?menuId=3000001755&bbsId=BBSMSTR_003000000094',
    'http://rec.knue.ac.kr/bbs/lstBoard.jsp?bodcode=edunotice',
  ];
  for (var url in urls) {
    print('\n URL: $url');
    var res = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'Mozilla/5.0'},
    );
    var doc = parser.parse(utf8.decode(res.bodyBytes, allowMalformed: true));

    var rows = doc.querySelectorAll('tbody tr');
    for (var row in rows.take(2)) {
      var titleEl = row.querySelector('.p-subject a') ?? row.querySelector('a');
      if (titleEl == null) continue;
      String title = titleEl.text.trim();


      var tds = row.querySelectorAll('td');
      String date = '';
      final dateRegex = RegExp(r'\d{2,4}[-.]\d{2}[-.]\d{2}');
      for (var td in tds) {
        final match = dateRegex.firstMatch(td.text.trim());
        if (match != null) {
          date = match.group(0)!.replaceAll('-', '.');
          break;
        }
      }
      if (date.isEmpty && tds.length > 2) {
        date = tds.length > 4 ? tds[4].text.trim() : tds[2].text.trim();
        date = date.replaceAll('-', '.');
      }
      print(' Title: $title | Date: $date');
    }
  }
}
