import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:knue_moa/constants/theme_constants.dart';
import 'package:knue_moa/providers/providers.dart';
import 'package:knue_moa/services/scraper_service.dart';
import 'package:knue_moa/widgets/notice_card.dart';
import 'package:knue_moa/widgets/keyword_chip.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with SingleTickerProviderStateMixin {
  int _activeTab = 0;
  String _selectedGroup = 'MAIN';
  String _selectedBoard = 'ALL';
  String _searchScope = '전체';
  String _searchQuery = '';
  bool _isInputVisible = false;
  final TextEditingController _keywordController = TextEditingController();
  int _aiBannerIndex = 0;
  Timer? _bannerTimer;

  late final TabController _tabController;

  final KnueScraper _scraper = KnueScraper();

  // 그룹 재정의: DEPT1-4를 'DEPT'로 통합
  final Map<String, Map<String, dynamic>> _noticeGroups = {
    'MY': {'label': 'MY', 'icon': LucideIcons.star},
    'MAIN': {'label': '본부 공지', 'icon': LucideIcons.building2},
    'ANNEX': {'label': '부속 기관', 'icon': LucideIcons.library},
    'DEPT': {'label': '학과 홈페이지', 'icon': LucideIcons.graduationCap},
    'GRAD': {'label': '대학원', 'icon': LucideIcons.school},
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _startAiBanner();
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    _keywordController.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _startAiBanner() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (t) {
      final notices = ref.read(noticesProvider).valueOrNull;
      if (notices != null && notices.isNotEmpty) {
        setState(() {
          _aiBannerIndex = (_aiBannerIndex + 1) % 5;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeKey = ref.watch(themeKeyProvider);
    final themeData = AppTheme.getTheme(themeKey);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            if (_activeTab != 1) _buildHeader(themeData),
            Expanded(
              child: IndexedStack(
                index: _activeTab,
                children: [
                  _buildHomeTab(themeData),
                  _buildSearchTab(themeData),
                  _buildSettingsTab(themeData),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(themeData),
    );
  }

  Widget _buildHeader(Map<String, dynamic> theme) {
    final isAlarmOn = ref.watch(alarmProvider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
              children: [
                const TextSpan(text: 'KNUE '),
                TextSpan(text: 'MoA', style: TextStyle(color: theme['primary'])),
              ],
            ),
          ),
          IconButton(
            onPressed: () => ref.read(alarmProvider.notifier).state = !isAlarmOn,
            icon: Icon(
              isAlarmOn ? LucideIcons.bell : LucideIcons.bellOff,
              color: const Color(0xFF334155),
            ),
          ),
        ],
      ),
    );
  }

  // ========== 홈 탭 ==========
  Widget _buildHomeTab(Map<String, dynamic> theme) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(noticesProvider);
        ref.invalidate(refreshNoticesProvider);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _buildKeywordCard(theme),
          _buildAiBanner(theme),
          _buildFolderSystem(theme),
          _buildNoticeList(theme),
        ],
      ),
    );
  }

  Widget _buildKeywordCard(Map<String, dynamic> theme) {
    final keywordsAsync = ref.watch(keywordsProvider);
    final keywords = keywordsAsync.value ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: theme['gradient'],
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: theme['primary'].withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(LucideIcons.star, color: Colors.yellow, size: 22),
                  SizedBox(width: 8),
                  Text(
                    '나의 키워드',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                  ),
                ],
              ),
              IconButton(
                onPressed: () => setState(() => _isInputVisible = !_isInputVisible),
                icon: Icon(
                  _isInputVisible ? LucideIcons.x : LucideIcons.plus,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (_isInputVisible) _buildKeywordInput(theme),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: keywords.map((k) => KeywordChip(
              label: k,
              onDeleted: () => ref.read(keywordsNotifierProvider.notifier).remove(k),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildKeywordInput(Map<String, dynamic> theme) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _keywordController,
              decoration: InputDecoration(
                hintText: '예: 장학금, 수강신청',
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              onSubmitted: (_) => _addKeyword(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: _addKeyword,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: theme['primary'],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
            child: const Text('추가'),
          ),
        ],
      ),
    );
  }

  void _addKeyword() {
    if (_keywordController.text.isNotEmpty) {
      ref.read(keywordsNotifierProvider.notifier).add(_keywordController.text);
      _keywordController.clear();
      setState(() => _isInputVisible = false);
    }
  }

  Widget _buildAiBanner(Map<String, dynamic> theme) {
    final noticesAsync = ref.watch(noticesProvider);
    final notices = noticesAsync.valueOrNull ?? [];

    if (notices.isEmpty) return const SizedBox.shrink();

    final notice = notices[_aiBannerIndex % notices.length];

    return GestureDetector(
      onTap: () => _launchUrl(notice.link),
      child: Container(
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: theme['bannerBg'],
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: theme['bannerBg'].withOpacity(0.4),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(LucideIcons.sparkles, color: Colors.yellow, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI 추천 공지',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                  ),
                  Text(
                    '[${notice.category}] ${notice.title}',
                    style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(LucideIcons.chevronRight, color: Colors.white54, size: 18),
          ],
        ),
      ),
    );
  }

  Widget _buildFolderSystem(Map<String, dynamic> theme) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: _noticeGroups.entries.map((entry) {
              final active = _selectedGroup == entry.key;
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedGroup = entry.key;
                  _selectedBoard = 'ALL';
                }),
                child: Container(
                  width: 75,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: active ? theme['bgLight'] : Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: active ? theme['primary'] : Colors.grey.shade200,
                            width: active ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          entry.value['icon'],
                          color: active ? theme['primary'] : Colors.grey.shade400,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.value['label'],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: active ? theme['primary'] : Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        if (_selectedGroup != 'MY') _buildBoardSelector(theme),
      ],
    );
  }

  // 게시판 선택기 (그룹에 따라 다른 board 목록 표시)
  Widget _buildBoardSelector(Map<String, dynamic> theme) {
    List<String> boards = [];

    if (_selectedGroup == 'MAIN') {
      boards = ['ALL', ...(_scraper.boardGroups['MAIN']?.keys ?? [])];
    } else if (_selectedGroup == 'ANNEX') {
      boards = ['ALL', ...(_scraper.boardGroups['ANNEX']?.keys ?? [])];
    } else if (_selectedGroup == 'DEPT') {
      // 모든 학과 게시판 통합
      Set<String> deptBoards = {};
      ['DEPT1', 'DEPT2', 'DEPT3', 'DEPT4'].forEach((key) {
        deptBoards.addAll(_scraper.boardGroups[key]?.keys ?? []);
      });
      boards = ['ALL', ...deptBoards];
    } else if (_selectedGroup == 'GRAD') {
      boards = ['ALL', ...(_scraper.boardGroups['GRAD']?.keys ?? [])];
    }

    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: boards.length,
        itemBuilder: (ctx, index) {
          final board = boards[index];
          final selected = _selectedBoard == board;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(board == 'ALL' ? '전체보기' : board),
              selected: selected,
              onSelected: (s) => setState(() => _selectedBoard = board),
              selectedColor: theme['bgLight'],
              labelStyle: TextStyle(
                color: selected ? theme['primary'] : Colors.grey.shade700,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoticeList(Map<String, dynamic> theme) {
    final noticesAsync = ref.watch(noticesProvider);
    final favorites = ref.watch(favoritesNotifierProvider);

    return noticesAsync.when(
      data: (notices) {
        if (notices.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text('공지사항이 없습니다.'),
            ),
          );
        }

        final filtered = notices.where((n) {
          if (_selectedGroup == 'MY') return favorites.contains(n.id);
          
          // 그룹별 필터링
          if (_selectedGroup == 'DEPT') {
            // 학과 그룹: n.group이 DEPT1-4 중 하나여야 함
            if (!n.group.startsWith('DEPT')) return false;
            if (_selectedBoard != 'ALL') {
              return n.category == _selectedBoard;
            }
            return true;
          } else {
            // 다른 그룹
            if (_selectedBoard != 'ALL') return n.category == _selectedBoard;
            return n.group == _selectedGroup;
          }
        }).toList();

        if (filtered.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(40),
              child: Text('해당 게시판에 공지가 없습니다.'),
            ),
          );
        }

        return AnimationLimiter(
          child: ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            itemCount: filtered.length,
            itemBuilder: (ctx, i) {
              return AnimationConfiguration.staggeredList(
                position: i,
                duration: const Duration(milliseconds: 375),
                child: SlideAnimation(
                  verticalOffset: 50.0,
                  child: FadeInAnimation(
                    child: NoticeCard(notice: filtered[i], themeData: theme),
                  ),
                ),
              );
            },
          ),
        );
      },
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(LucideIcons.wifiOff, size: 60, color: Colors.grey.shade400),
              const SizedBox(height: 16),
              Text(
                '데이터를 불러올 수 없습니다',
                style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  ref.invalidate(noticesProvider);
                },
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      ),
      loading: () => ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 5,
        itemBuilder: (ctx, i) => const _LoadingNoticeCard(),
      ),
    );
  }

  // ========== 검색 탭 ==========
  Widget _buildSearchTab(Map<String, dynamic> theme) {
    final noticesAsync = ref.watch(noticesProvider);
    final notices = noticesAsync.valueOrNull ?? [];

    final results = notices.where((n) {
      final matchesQuery = _searchQuery.isEmpty ||
          n.title.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesScope = _searchScope == '전체' || n.category == _searchScope;
      return matchesQuery && matchesScope;
    }).toList();

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '검색',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: '제목으로 검색',
              prefixIcon: const Icon(LucideIcons.search),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '카테고리',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _buildSearchCategoryList(theme),
          ),
        ],
      ),
    );
  }

  // 검색 카테고리를 섹션별로 정리한 리스트
  Widget _buildSearchCategoryList(Map<String, dynamic> theme) {
    // 섹션 정의
    final sections = [
      {'title': '본부 공지', 'boards': _scraper.boardGroups['MAIN']?.keys.toList() ?? []},
      {'title': '부속 기관', 'boards': _scraper.boardGroups['ANNEX']?.keys.toList() ?? []},
      {
        'title': '학과 홈페이지',
        'boards': [
          ...? _scraper.boardGroups['DEPT1']?.keys,
          ...? _scraper.boardGroups['DEPT2']?.keys,
          ...? _scraper.boardGroups['DEPT3']?.keys,
          ...? _scraper.boardGroups['DEPT4']?.keys,
        ]
      },
      {'title': '대학원', 'boards': _scraper.boardGroups['GRAD']?.keys.toList() ?? []},
    ];

    return ListView.builder(
      itemCount: sections.length + 1, // +1 for "전체" at top
      itemBuilder: (ctx, index) {
        if (index == 0) {
          // "전체" 선택 칩 (상단에 고정)
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('전체'),
                  selected: _searchScope == '전체',
                  onSelected: (s) => setState(() => _searchScope = '전체'),
                  selectedColor: theme['bgLight'],
                  labelStyle: TextStyle(
                    color: _searchScope == '전체' ? theme['primary'] : Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          );
        }

        final section = sections[index - 1];
        final boards = section['boards'] as List<String>;
        if (boards.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                section['title'] as String,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: theme['primary'],
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: boards.map((board) {
                final selected = _searchScope == board;
                return ChoiceChip(
                  label: Text(board),
                  selected: selected,
                  onSelected: (s) => setState(() => _searchScope = board),
                  selectedColor: theme['bgLight'],
                  labelStyle: TextStyle(
                    color: selected ? theme['primary'] : Colors.grey.shade700,
                    fontSize: 12,
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  // ========== 설정 탭 ==========
  Widget _buildSettingsTab(Map<String, dynamic> theme) {
    final themeKey = ref.watch(themeKeyProvider);
    final isAlarmOn = ref.watch(alarmProvider);

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const Text(
          '설정',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 30),
        _buildSettingsGroup(
          '알림 및 개인화',
          [
            ListTile(
              leading: const Icon(LucideIcons.bell),
              title: const Text('키워드 알림'),
              trailing: Switch(
                value: isAlarmOn,
                activeColor: theme['primary'],
                onChanged: (v) => ref.read(alarmProvider.notifier).state = v,
              ),
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(LucideIcons.palette),
              title: const Text('테마 색상'),
              trailing: _buildThemeSelector(themeKey),
            ),
          ],
          theme,
        ),
        const SizedBox(height: 20),
        _buildSettingsGroup(
          '앱 정보',
          [
            const ListTile(
              leading: Icon(LucideIcons.info),
              title: Text('버전'),
              trailing: Text('v1.2.0'),
            ),
            const Divider(height: 0),
            const ListTile(
              leading: Icon(LucideIcons.user),
              title: Text('개발자'),
              subtitle: Text('한국교원대학교 예비교사'),
            ),
          ],
          theme,
        ),
      ],
    );
  }

  Widget _buildSettingsGroup(String title, List<Widget> children, Map<String, dynamic> theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: theme['primary'],
          ),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade100),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildThemeSelector(String currentKey) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: ['blue', 'green', 'orange'].map((key) {
        final isSelected = currentKey == key;
        Color color;
        switch (key) {
          case 'blue':
            color = Colors.blue;
            break;
          case 'green':
            color = Colors.green;
            break;
          case 'orange':
            color = Colors.orange;
            break;
          default:
            color = Colors.blue;
        }
        return GestureDetector(
          onTap: () => ref.read(themeKeyProvider.notifier).state = key,
          child: Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(left: 8),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: isSelected ? Border.all(color: Colors.black, width: 2) : null,
              boxShadow: isSelected
                  ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)]
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }

  // ========== 하단 네비게이션 ==========
  Widget _buildBottomNav(Map<String, dynamic> theme) {
    return Container(
      padding: const EdgeInsets.only(bottom: 25, top: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFF1F5F9))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(LucideIcons.home, '홈', 0, theme),
          _navCenterBtn(theme),
          _navItem(LucideIcons.settings, '설정', 2, theme),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index, Map<String, dynamic> theme) {
    final active = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? theme['primary'] : Colors.grey, size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? theme['primary'] : Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navCenterBtn(Map<String, dynamic> theme) {
    return GestureDetector(
      onTap: () => setState(() => _activeTab = 1),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: theme['gradient'],
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme['primary'].withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(LucideIcons.search, color: Colors.white, size: 28),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('링크를 열 수 없습니다: $url')),
        );
      }
    }
  }
}

// 로딩 스켈레톤 (커스텀)
class _LoadingNoticeCard extends StatelessWidget {
  const _LoadingNoticeCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 60,
            height: 20,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 200,
            height: 16,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 100,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              Container(
                width: 30,
                height: 14,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}