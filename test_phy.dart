import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'dart:convert';

void main() async {
  var urls = [
    'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=25&key=806',
    'https://www.knue.ac.kr/phy/selectBbsNttList.do?bbsNo=211&key=1327',
    'https://tot.knue.ac.kr/common/bbs/management/selectCmmnBBSMgmtList.do?menuId=3000001755&bbsId=BBSMSTR_003000000094',
    'http://rec.knue.ac.kr/bbs/lstBoard.jsp?bodcode=edunotice',
    'https://m.news.knue.ac.kr/news/articleList.html?sc_section_code=S1N3',
    'https://lib.knue.ac.kr/bbs/list/1',
  ];
  for (var u in urls) {
    print('\n URL: $u');
    var res = await http.get(
      Uri.parse(u),
      headers: {'User-Agent': 'Mozilla/5.0'},
    );
    var d = parser.parse(utf8.decode(res.bodyBytes, allowMalformed: true));

    var rows = d.querySelectorAll('tbody tr');
    if (rows.isEmpty) rows = d.querySelectorAll('.list-item');
    if (rows.isEmpty) rows = d.querySelectorAll('li, div.row, div.list-block');

    for (var r in rows.take(2)) {
      var tds = r.querySelectorAll('td');
      if (tds.isNotEmpty) {
        print(
          ' tds: ${tds.map((t) => t.text.trim().replaceAll('\n', '').replaceAll('\t', '')).toList()}',
        );
        print(' link: ${r.querySelector('a')?.attributes['href']}');
      } else {
        print(
          ' no-tds: ${r.text.trim().replaceAll('\n', '').replaceAll('\t', '')}',
        );
        print(' link: ${r.querySelector('a')?.attributes['href']}');
      }
    }
  }
}
