import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

void main() async {
  String url =
      'https://lib.knue.ac.kr/pyxis-api/1/bulletin-boards/1/bulletins?max=20&offset=0';
  final response = await http.get(
    Uri.parse(url),
    headers: {'User-Agent': 'Mozilla/5.0'},
  );

  if (response.statusCode != 200) {
    print('Failed: ${response.statusCode}');
    return;
  }

  try {
    final decoded = jsonDecode(response.body);
    final list = decoded['data']['list'] as List;
    print('Found ${list.length} items');
    for (var item in list) {
      String title = item['title'] ?? '제목없음';
      String date = (item['dateCreated'] ?? '')
          .split(' ')[0]
          .replaceAll('-', '.');
      String author = item['writer'] ?? '학교';
      String fullLink =
          'https://lib.knue.ac.kr/#/bbs/notice/${item['id']}?offset=0&max=20';
      print('- $title / $date / $author / $fullLink');
    }
  } catch (e) {
    print('Error: $e');
  }
}
