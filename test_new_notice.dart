import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:cp949_codec/cp949_codec.dart';
import 'dart:convert';

void main() async {
  String url = 'http://rec.knue.ac.kr/bbs/lstBoard.jsp?bodcode=edunotice';
  final response = await http
      .get(Uri.parse(url), headers: {'User-Agent': 'Mozilla/5.0'})
      .timeout(const Duration(seconds: 10));

  print('Status: \${response.statusCode}');

  String decodedHtml;
  try {
    decodedHtml = utf8.decode(response.bodyBytes);
  } catch (e) {
    decodedHtml = cp949.decode(response.bodyBytes);
  }

  var doc = parser.parse(decodedHtml);
  var rows = doc.querySelectorAll('tbody tr');
  print('Found \${rows.length} rows.');

  for (int i = 0; i < rows.length; i++) {
    var row = rows[i];
    try {
      var titleEl = row.querySelector('.p-subject a') ?? row.querySelector('a');
      String title = titleEl?.text.trim() ?? '제목 없음';

      var tds = row.querySelectorAll('td');
      String date = tds.length > 4
          ? tds[4].text.trim()
          : (tds.length > 3 ? tds[3].text.trim() : '');

      print('Row $i: $title ($date)');
    } catch (e) {
      print('Error on row $i: $e');
    }
  }
}
