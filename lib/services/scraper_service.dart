import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:intl/intl.dart';
import 'package:knue_moa/models/notice_model.dart';

class KnueScraper {
  // 사용자님께서 주신 모든 링크를 하나도 빠짐없이 그룹화했습니다.
  final Map<String, Map<String, String>> boardGroups = {
    'MAIN': {
      '대학소식': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=25&key=806',
      '학사공지': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=26&key=807',
      '청람소양': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=256&key=1609',
      '학점교류': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=254&key=1562',
      '등록금': 'https://www.knue.ac.kr/www/selectBbsNttList.do?key=550&bbsNo=11',
      '장학금': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=207&key=1443',
      '교환학생': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=13&key=597',
      '임용안내': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=259&key=1630',
      '취업정보': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=12&key=574',
      '행사세미나': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=28&key=809',
      '채용공고': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=27&key=808',
      '입찰공고': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=29&key=810',
    },
    'ANNEX': {
      '도서관일반': 'https://lib.knue.ac.kr/bbs/list/1',
      '도서관학술': 'https://lib.knue.ac.kr/bbs/list/2',
      '종합연수원': 'https://tot.knue.ac.kr/common/bbs/management/selectCmmnBBSMgmtList.do?menuId=3000001755&bbsId=BBSMSTR_003000000094',
      '영유아연수원': 'https://tot.knue.ac.kr/common/bbs/management/selectCmmnBBSMgmtList.do?menuId=3000001756&bbsId=BBSMSTR_003000000576',
      '신문방송사': 'https://news.knue.ac.kr/',
    },
    'DEPT1': {
      '교육학과': 'https://www.knue.ac.kr/education/index.do',
      '유아교육': 'https://www.knue.ac.kr/ece/index.do',
      '초등교육': 'https://cafe.daum.net/knue-primary',
      '특수교육': 'https://www.knue.ac.kr/sped/index.do',
    },
    'DEPT2': {
      '국어교육': 'https://www.knue.ac.kr/korean/index.do', '영어교육': 'https://www.knue.ac.kr/english/index.do',
      '독어교육': 'https://www.knue.ac.kr/german/index.do', '불어교육': 'https://www.knue.ac.kr/french/index.do',
      '중국어교육': 'https://www.knue.ac.kr/chinese/index.do', '윤리교육': 'https://www.knue.ac.kr/ethics/index.do',
      '일반사회': 'https://www.knue.ac.kr/social/index.do', '지리교육': 'https://www.knue.ac.kr/geography/index.do',
      '역사교육': 'https://www.knue.ac.kr/history/index.do',
    },
    'DEPT3': {
      '수학교육': 'https://www.knue.ac.kr/math/index.do', '물리교육': 'https://www.knue.ac.kr/phys/index.do',
      '화학교육': 'https://www.knue.ac.kr/chemedu/index.do', '생물교육': 'https://www.knue.ac.kr/bioedu/index.do',
      '지구과학': 'https://www.knue.ac.kr/earth/index.do', '가정교육': 'https://www.knue.ac.kr/homeedu/index.do',
      '환경교육': 'https://www.knue.ac.kr/envi/index.do', '기술교육': 'https://www.knue.ac.kr/techedu/index.do',
      '컴퓨터교육': 'https://www.knue.ac.kr/comedu/index.do',
    },
    'DEPT4': {
      '음악교육': 'https://www.knue.ac.kr/music/index.do', '미술교육': 'https://www.knue.ac.kr/artedu/index.do',
      '체육교육': 'https://www.knue.ac.kr/phy/index.do',
    },
    'GRAD': {
      '대학원': 'https://www.knue.ac.kr/grad/selectBbsNttList.do?bbsNo=67&key=645',
      '교육대학원': 'https://www.knue.ac.kr/grad/selectBbsNttList.do?bbsNo=68&key=646',
      '정책대학원': 'https://www.knue.ac.kr/edupol/selectBbsNttList.do?bbsNo=73&key=659',
    }
  };

  // 모든 데이터를 한 번에 가져오는 함수 (메인 공지 우선)
  Future<List<Notice>> fetchAllNotices() async {
    List<Notice> all = [];
    // 성능을 위해 메인 그룹은 실제 크롤링하여 리스트화
    for (var entry in boardGroups['MAIN']!.entries) {
      var res = await _fetchBoard('MAIN', entry.key, entry.value);
      all.addAll(res);
    }
    all.sort((a, b) => b.date.compareTo(a.date));
    return all;
  }

  Future<List<Notice>> _fetchBoard(String group, String category, String url) async {
    try {
      final response = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) {
        var doc = parser.parse(response.body);
        return doc.querySelectorAll('tbody tr').map((row) {
          var titleEl = row.querySelector('.p-subject a');
          var tds = row.querySelectorAll('td');
          String title = titleEl?.text.trim() ?? "제목 없음";
          String date = tds.length > 4 ? tds[4].text.trim() : "";
          return Notice(
            id: (title + date).hashCode,
            category: category,
            group: group,
            title: title,
            date: date,
            author: tds.length > 2 ? tds[2].text.trim() : "학교",
            link: url, // 실제 게시판 연동 URL
            isNew: date == DateFormat('yyyy.MM.dd').format(DateTime.now()),
          );
        }).toList();
      }
    } catch (e) { print(e); }
    return [];
  }
}