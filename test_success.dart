import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  String url =
      'https://success.knue.ac.kr/ptfol/imng/icmpNsbjtPgm/findIcmpNsbjtPgmList.do';
  final response = await http.get(
    Uri.parse(url),
    headers: {'User-Agent': 'Mozilla/5.0'},
  );

  print('Status: ${response.statusCode}');
  print('Location: ${response.headers["location"]}');
  print('Body length: ${response.body.length}');
  if (response.body.length > 500) {
    print(response.body.substring(0, 500));
  } else {
    print(response.body);
  }
}
