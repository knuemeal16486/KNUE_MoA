import 'dart:io';
import 'package:html/parser.dart' as parser;

void main() {
  final files = ['library.html', 'news.html', 'sado.html'];
  for (var file in files) {
    if (!File(file).existsSync()) continue;
    var html = File(file).readAsStringSync();
    var doc = parser.parse(html);
    var rows = doc.querySelectorAll('tbody tr');

    if (rows.isEmpty) {
      if (file == 'news.html') {
        rows = doc.querySelectorAll(
          '.list-block',
        ); // usually news sites use this or similar
      } else if (file == 'library.html') {
        rows = doc.querySelectorAll('li, tr, div.row');
      }
    }

    print('\n--- $file: found ${rows.length} items ---');
    for (int i = 0; i < (rows.length > 2 ? 2 : rows.length); i++) {
      var text = rows[i].text.replaceAll(RegExp(r'\s+'), ' ').trim();
      print(' row $i text: $text');
      var a = rows[i].querySelector('a');
      print(' row $i link: ${a?.attributes['href']}');
    }
  }
}
