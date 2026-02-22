import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:html/parser.dart' as parser;
import 'package:intl/intl.dart';
import 'package:knue_moa/models/notice_model.dart';
import 'package:hive/hive.dart';
import 'package:cp949_codec/cp949_codec.dart';

class KnueScraper {
  // 모든 게시판 그룹 (기존과 동일)
  final Map<String, Map<String, String>> boardGroups = {
    'MAIN': {
      '대학소식': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=25&key=806',
      '학사공지': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=26&key=807',
      '청람소양':
          'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=256&key=1609',
      '학점교류':
          'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=254&key=1562',
      '등록금': 'https://www.knue.ac.kr/www/selectBbsNttList.do?key=550&bbsNo=11',
      '장학금':
          'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=207&key=1443',
      '교환학생': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=13&key=597',
      '임용안내':
          'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=259&key=1630',
      '취업정보': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=12&key=574',
      '행사세미나':
          'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=28&key=809',
      '채용공고': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=27&key=808',
      '입찰공고': 'https://www.knue.ac.kr/www/selectBbsNttList.do?bbsNo=29&key=810',
    },
    'ANNEX': {
      '도서관일반': 'https://lib.knue.ac.kr/bbs/list/1',
      '도서관학술': 'https://lib.knue.ac.kr/bbs/list/2',
      // 종합교육연수원 (공통 게시판 패턴)
      '종합연수원':
          'https://tot.knue.ac.kr/common/bbs/management/selectCmmnBBSMgmtList.do?menuId=3000001755&bbsId=BBSMSTR_003000000094',
      // 영유아교육연수원
      '영유아연수원':
          'https://tot.knue.ac.kr/common/bbs/management/selectCmmnBBSMgmtList.do?menuId=3000001756&bbsId=BBSMSTR_003000000576',
      // 신문방송사 (기사 목록 URL)
      '신문방송사':
          'https://m.news.knue.ac.kr/news/articleList.html?sc_section_code=S1N3',
      // 사도교육원
      '사도교육원': 'http://rec.knue.ac.kr/bbs/lstBoard.jsp?bodcode=edunotice',
    },
    'DEPT': {
      // 제1대학
      '교육학과':
          'https://www.knue.ac.kr/education/selectBbsNttList.do?bbsNo=86&key=985',
      '유아교육과':
          'https://www.knue.ac.kr/ece/selectBbsNttList.do?bbsNo=93&key=1005',
      '초등교육과':
          'https://m.cafe.daum.net/knue-primary/HhZk', // 다음카페 모바일 주소 (공지사항 게시판 ID 확인 필요, 예시는 임의)
      '특수교육과':
          'https://www.knue.ac.kr/sped/selectBbsNttList.do?bbsNo=100&key=1025',

      // 제2대학 (확인된 일부만 적용, 나머지는 아래 패턴 참고하여 직접 수정 필요)
      // 패턴: https://www.knue.ac.kr/[학과영문명]/selectBbsNttList.do?bbsNo=[번호]&key=[번호]
      '국어교육과':
          'https://www.knue.ac.kr/korean/selectBbsNttList.do?bbsNo=106&key=1044',
      '영어교육과':
          'https://www.knue.ac.kr/english/selectBbsNttList.do?bbsNo=113&key=1114',

      // 제3대학
      '수학교육과':
          'https://www.knue.ac.kr/math/selectBbsNttList.do?bbsNo=151&key=1231',
      '물리교육과':
          'https://www.knue.ac.kr/phys/selectBbsNttList.do?bbsNo=158&key=1251',
      '컴퓨터교육과':
          'https://www.knue.ac.kr/comedu/selectBbsNttList.do?bbsNo=187&key=1281',

      // 제4대학
      '음악교육과':
          'https://www.knue.ac.kr/music/selectBbsNttList.do?bbsNo=204&key=1314',
      '체육교육과':
          'https://www.knue.ac.kr/phy/selectBbsNttList.do?bbsNo=211&key=1327',
      '미술교육과':
          'https://www.knue.ac.kr/artedu/selectBbsNttList.do?bbsNo=218&key=1342',
    },
    'GRAD': {
      '대학원': 'https://www.knue.ac.kr/grad/selectBbsNttList.do?bbsNo=67&key=645',
      '교육대학원':
          'https://www.knue.ac.kr/grad/selectBbsNttList.do?bbsNo=68&key=646',
      '교육정책대학원':
          'https://www.knue.ac.kr/edupol/selectBbsNttList.do?bbsNo=73&key=659',
    },
  };

  static const Map<String, List<String>> collegeStructure = {
    '제1대학': ['교육학과', '유아교육과', '초등교육과', '특수교육과'],
    '제2대학': [
      '국어교육과',
      '영어교육과',
      '독어교육과',
      '불어교육과',
      '중국어교육과',
      '윤리교육과',
      '일반사회교육과',
      '지리교육과',
      '역사교육과',
    ],
    '제3대학': [
      '수학교육과',
      '물리교육과',
      '화학교육과',
      '생물교육과',
      '지구과학교육과',
      '가정교육과',
      '환경교육과',
      '기술교육과',
      '컴퓨터교육과',
    ],
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

    // 새 데이터 가져오기 (병렬 처리로 속도 개선)
    List<Notice> all = [];
    List<Future<List<Notice>>> futures = [];

    for (var groupEntry in boardGroups.entries) {
      String groupName = groupEntry.key;
      for (var entry in groupEntry.value.entries) {
        futures.add(
          _fetchBoardWithRetry(groupName, entry.key, entry.value).catchError((
            e,
          ) {
            print('Error fetching $groupName - ${entry.key}: $e');
            return <Notice>[];
          }),
        );
      }
    }

    // 5개씩 묶어서 병렬 요청 (서버 부하 방지 및 속도 최적화)
    for (int i = 0; i < futures.length; i += 5) {
      int end = (i + 5 < futures.length) ? i + 5 : futures.length;
      final results = await Future.wait(futures.sublist(i, end));
      for (var res in results) {
        all.addAll(res);
      }
    }

    all.sort((a, b) => b.date.compareTo(a.date));

    // Hive에 저장 (기존 데이터 삭제 후 추가)
    await box.clear();
    await box.addAll(all);

    return all;
  }

  // 재시도 로직이 포함된 게시판 가져오기
  Future<List<Notice>> _fetchBoardWithRetry(
    String group,
    String category,
    String url, {
    int retry = 0,
  }) async {
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

  Future<List<Notice>> _fetchBoard(
    String group,
    String category,
    String url,
  ) async {
    final response = await http
        .get(
          Uri.parse(url),
          headers: {
            'User-Agent':
                'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
          },
        )
        .timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    String decodedHtml;
    try {
      decodedHtml = utf8.decode(response.bodyBytes);
    } catch (e) {
      decodedHtml = cp949.decode(response.bodyBytes);
    }

    var doc = parser.parse(decodedHtml);
    var rows = doc.querySelectorAll('tbody tr');

    final notices = <Notice>[];
    for (var row in rows) {
      try {
        // 제목과 링크 추출
        var titleEl =
            row.querySelector('.p-subject a') ?? row.querySelector('a');
        if (titleEl == null) continue;

        String title = titleEl.text.trim();
        // 🔥 제목에서 '새글' 관련 문자열 제거 (대괄호 포함, 앞뒤 공백 처리)
        title = title.replaceAll(RegExp(r'\[?새글\]?\s*'), '').trim();

        String relativeLink = titleEl.attributes['href'] ?? '';
        String fullLink = _resolveLink(url, relativeLink);

        var tds = row.querySelectorAll('td');
        String date = '';
        String author = '학교';

        // 1. 날짜 추출 (정규식으로 yyyy-mm-dd 또는 yyyy.mm.dd 패턴 찾기)
        final dateRegex = RegExp(r'\d{2,4}[-.]\d{2}[-.]\d{2}');
        for (var td in tds) {
          final match = dateRegex.firstMatch(td.text.trim());
          if (match != null) {
            date = match.group(0)!.replaceAll('-', '.');
            break;
          }
        }

        // 정규식으로 못 찾은 경우 기존 방식 활용
        if (date.isEmpty && tds.length > 2) {
          date = tds.length > 4 ? tds[4].text.trim() : tds[2].text.trim();
          date = date.replaceAll('-', '.');
        }

        // 2. 작성자 추출 (날짜나 숫자가 아닌 텍스트를 가진 td를 찾음)
        if (tds.length > 2) {
          String tempAuthor = tds[2].text.trim();
          // date와 같거나 숫자가 많이 포함되어 있으면 작성자가 아닐 확률이 높으므로 '학교'로 처리
          if (tempAuthor != date && !RegExp(r'\d{4}').hasMatch(tempAuthor)) {
            author = tempAuthor;
          }
        }

        // ID 생성 (게시판 URL + 제목 + 날짜)로 고유성 확보
        int id = _generateId(group, category, title, date, fullLink);

        // 오늘 날짜인지 확인
        bool isNew = date.contains(
          DateFormat('yyyy.MM.dd').format(DateTime.now()),
        );

        notices.add(
          Notice(
            id: id,
            category: category,
            group: group,
            title: title,
            date: date,
            author: author,
            link: fullLink,
            isNew: isNew,
          ),
        );
      } catch (e) {
        print('Parsing error in $category: $e');
      }
    }
    return notices;
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
  int _generateId(
    String group,
    String category,
    String title,
    String date,
    String link,
  ) {
    return Object.hash(group, category, title, date, link);
  }
}
