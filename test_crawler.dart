import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;

void main() async {
  String url =
      'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=25&key=806';
  final response = await http
      .get(
        Uri.parse(url),
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      )
      .timeout(const Duration(seconds: 10));

  print('Status: ${response.statusCode}');

  var doc = parser.parse(utf8.decode(response.bodyBytes));
  var rows = doc.querySelectorAll('tbody tr');
  print('Found ${rows.length} rows.');

  for (int i = 0; i < rows.length; i++) {
    var row = rows[i];
    try {
      var titleEl = row.querySelector('.p-subject a');
      String title = titleEl?.text.trim() ?? '제목 없음';

      var tds = row.querySelectorAll('td');
      String date = tds.length > 4 ? tds[4].text.trim() : 'NO_DATE';

      print('Row $i: $title ($date)');
    } catch (e) {
      print('Error on row $i: $e');
    }
  }
}
