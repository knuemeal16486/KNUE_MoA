import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  // API 엔드포인트 테스트 3 - pyxis-api
  var res1 = await http.get(
    Uri.parse(
      'https://lib.knue.ac.kr/pyxis-api/1/bulletin-boards/1/bulletins?max=20&offset=0',
    ),
  );
  print('API 1 Status: ${res1.statusCode}');
  if (res1.statusCode == 200) {
    print(
      'API 1 Response: ${res1.body.substring(0, res1.body.length > 500 ? 500 : res1.body.length)}',
    );
  }

  var res2 = await http.get(
    Uri.parse(
      'https://lib.knue.ac.kr/pyxis-api/1/bulletin-boards/2/bulletins?max=20&offset=0',
    ),
  );
  print('API 2 Status: ${res2.statusCode}');
  if (res2.statusCode == 200) {
    print(
      'API 2 Response: ${res2.body.substring(0, res2.body.length > 500 ? 500 : res2.body.length)}',
    );
  }
}
