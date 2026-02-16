import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:intl/intl.dart';
import 'package:knue_moa/models/notice_model.dart';
import 'package:hive/hive.dart';

class KnueScraper {
  // 모든 게시판 그룹 (기존과 동일)
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
      '교육학과': 'https://www.knue.ac.kr/education/board/list.do?boardId=BBS_0000176',
      '유아교육과': 'https://www.knue.ac.kr/ece/board/list.do?boardId=BBS_0000185',
      // 초등교육과는 다음카페라 크롤링 방식이 다를 수 있음 (일단 URL 매핑만)
      '초등교육과': 'https://cafe.daum.net/knue-primary', 
      '특수교육과': 'https://www.knue.ac.kr/sped/board/list.do?boardId=BBS_0000203',
    },
    'DEPT2': {
      '국어교육과': 'https://www.knue.ac.kr/korean/board/list.do?boardId=BBS_0000213',
      '영어교육과': 'https://www.knue.ac.kr/english/board/list.do?boardId=BBS_0000223',
      '독어교육과': 'https://www.knue.ac.kr/german/board/list.do?boardId=BBS_0000233',
      '불어교육과': 'https://www.knue.ac.kr/french/board/list.do?boardId=BBS_0000243',
      '중국어교육과': 'https://www.knue.ac.kr/chinese/board/list.do?boardId=BBS_0000253',
      '윤리교육과': 'https://www.knue.ac.kr/ethics/board/list.do?boardId=BBS_0000263',
      '일반사회교육과': 'https://www.knue.ac.kr/social/board/list.do?boardId=BBS_0000273',
      '지리교육과': 'https://www.knue.ac.kr/geography/board/list.do?boardId=BBS_0000283',
      '역사교육과': 'https://www.knue.ac.kr/history/board/list.do?boardId=BBS_0000293',
    },
    'DEPT3': {
      '수학교육과': 'https://www.knue.ac.kr/math/board/list.do?boardId=BBS_0000303',
      '물리교육과': 'https://www.knue.ac.kr/phys/board/list.do?boardId=BBS_0000313',
      '화학교육과': 'https://www.knue.ac.kr/chemedu/board/list.do?boardId=BBS_0000323',
      '생물교육과': 'https://www.knue.ac.kr/bioedu/board/list.do?boardId=BBS_0000333',
      '지구과학교육과': 'https://www.knue.ac.kr/earth/board/list.do?boardId=BBS_0000343',
      '가정교육과': 'https://www.knue.ac.kr/homeedu/board/list.do?boardId=BBS_0000353',
      '환경교육과': 'https://www.knue.ac.kr/envi/board/list.do?boardId=BBS_0000363',
      '기술교육과': 'https://www.knue.ac.kr/techedu/board/list.do?boardId=BBS_0000373',
      '컴퓨터교육과': 'https://www.knue.ac.kr/comedu/board/list.do?boardId=BBS_0000383',
    },
    'DEPT4': {
      '음악교육과': 'https://www.knue.ac.kr/music/board/list.do?boardId=BBS_0000393',
      '미술교육과': 'https://www.knue.ac.kr/artedu/board/list.do?boardId=BBS_0000403',
      '체육교육과': 'https://www.knue.ac.kr/phy/board/list.do?boardId=BBS_0000413',
    },
    'GRAD': {
      '대학원공지': 'https://grad.knue.ac.kr/board/list.do?boardId=BBS_0000676',
    },
  };

static const Map<String, List<String>> collegeStructure = {
    '제1대학': ['교육학과', '유아교육과', '초등교육과', '특수교육과'],
    '제2대학': ['국어교육과', '영어교육과', '독어교육과', '불어교육과', '중국어교육과', '윤리교육과', '일반사회교육과', '지리교육과', '역사교육과'],
    '제3대학': ['수학교육과', '물리교육과', '화학교육과', '생물교육과', '지구과학교육과', '가정교육과', '환경교육과', '기술교육과', '컴퓨터교육과'],
    '제4대학': ['음악교육과', '미술교육과', '체육교육과'],
  };
  // Hive 박스 이름
  static const String noticeBoxName = 'notices';

  // 최대 재시도 횟수
  static const int maxRetries = 3;

  // 모든 게시판에서 공지 가져오기 (캐싱 포함)
  Future<List<Notice>> fetchAllNotices({bool forceRefresh = false}) async {
    // Hive 박스 열기
    final box = await Hive.openBox<Notice>(noticeBoxName);

    // 캐시된 데이터가 있고 강제 새로고침이 아니면 캐시 반환
    if (!forceRefresh && box.isNotEmpty) {
      return box.values.toList()..sort((a, b) => b.date.compareTo(a.date));
    }

    // 새 데이터 가져오기
    List<Notice> all = [];
    for (var entry in boardGroups['MAIN']!.entries) {
      try {
        final notices = await _fetchBoardWithRetry('MAIN', entry.key, entry.value);
        all.addAll(notices);
      } catch (e) {
        print('Error fetching ${entry.key}: $e');
      }
    }

    all.sort((a, b) => b.date.compareTo(a.date));

    // Hive에 저장 (기존 데이터 삭제 후 추가)
    await box.clear();
    await box.addAll(all);

    return all;
  }

  // 재시도 로직이 포함된 게시판 가져오기
  Future<List<Notice>> _fetchBoardWithRetry(String group, String category, String url, {int retry = 0}) async {
    try {
      return await _fetchBoard(group, category, url);
    } catch (e) {
      if (retry < maxRetries) {
        await Future.delayed(Duration(seconds: 1 * (retry + 1)));
        return _fetchBoardWithRetry(group, category, url, retry: retry + 1);
      }
      rethrow;
    }
  }

  Future<List<Notice>> _fetchBoard(String group, String category, String url) async {
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36'},
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    var doc = parser.parse(utf8.decode(response.bodyBytes));
    var rows = doc.querySelectorAll('tbody tr');

    return rows.map((row) {
      try {
        // 제목과 링크 추출
        var titleEl = row.querySelector('.p-subject a');
        String title = titleEl?.text.trim() ?? '제목 없음';

        // 🔥 제목에서 '새글' 관련 문자열 제거 (대괄호 포함, 앞뒤 공백 처리)
        title = title.replaceAll(RegExp(r'\[?새글\]?\s*'), '').trim();

        String relativeLink = titleEl?.attributes['href'] ?? '';
        String fullLink = _resolveLink(url, relativeLink);

        // 날짜 추출 (td 인덱스는 게시판마다 다를 수 있음, 여기서는 대략 4번째)
        var tds = row.querySelectorAll('td');
        String date = tds.length > 4 ? tds[4].text.trim() : '';
        String author = tds.length > 2 ? tds[2].text.trim() : '학교';

        // ID 생성 (게시판 URL + 제목 + 날짜)로 고유성 확보
        int id = _generateId(group, category, title, date, fullLink);

        // 오늘 날짜인지 확인
        bool isNew = date.contains(DateFormat('yyyy.MM.dd').format(DateTime.now()));

        return Notice(
          id: id,
          category: category,
          group: group,
          title: title,
          date: date,
          author: author,
          link: fullLink,
          isNew: isNew,
        );
      } catch (e) {
        print('Parsing error in $category: $e');
        // 파싱 실패 시 더미 객체 반환하지 않고 건너뜀
        rethrow;
      }
    }).toList();
  }

  // 상대 경로를 절대 경로로 변환
  String _resolveLink(String baseUrl, String relative) {
    if (relative.isEmpty) return baseUrl;
    if (relative.startsWith('http')) return relative;
    try {
      var uri = Uri.parse(baseUrl);
      var resolved = uri.resolve(relative);
      return resolved.toString();
    } catch (e) {
      return baseUrl + (relative.startsWith('/') ? relative : '/$relative');
    }
  }

  // 고유 ID 생성
  int _generateId(String group, String category, String title, String date, String link) {
    return Object.hash(group, category, title, date, link);
  }
}