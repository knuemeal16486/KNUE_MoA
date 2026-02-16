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
    final primaryColor = ref.watch(themeColorProvider);
    // 기존 코드 호환용 theme 맵
    final themeData = {
      'primary': primaryColor,
      'gradient': LinearGradient(
        colors: [primaryColor, primaryColor.withOpacity(0.7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      'bgLight': primaryColor.withOpacity(0.1),
      'bannerBg': Colors.black87,
    };

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            if (_activeTab != 1) _buildHeader(primaryColor),
            Expanded(
              child: IndexedStack(
                index: _activeTab,
                children: [
                  _buildHomeTab(themeData),
                  _buildSearchTab(themeData),
                  _buildSettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(primaryColor),
    );
  }

  Widget _buildHeader(Color primaryColor) {
    final isAlarmOn = ref.watch(alarmProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: isDark ? Colors.white : const Color(0xFF1E293B)),
              children: [
                const TextSpan(text: 'KNUE '),
                TextSpan(text: 'MoA', style: TextStyle(color: primaryColor)),
              ],
            ),
          ),
          IconButton(
            onPressed: () => ref.read(alarmProvider.notifier).state = !isAlarmOn,
            icon: Icon(
              isAlarmOn ? LucideIcons.bell : LucideIcons.bellOff,
              color: isDark ? Colors.grey : const Color(0xFF334155),
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
            color: (theme['primary'] as Color).withOpacity(0.3),
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
      onTap: () async {
        final uri = Uri.parse(notice.link);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
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
    final primary = theme['primary'] as Color;
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
                          color: active ? primary.withOpacity(0.1) : Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: active ? primary : Colors.grey.shade200,
                            width: active ? 2 : 1,
                          ),
                        ),
                        child: Icon(
                          entry.value['icon'],
                          color: active ? primary : Colors.grey.shade400,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        entry.value['label'],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: active ? primary : Colors.grey,
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

  Widget _buildBoardSelector(Map<String, dynamic> theme) {
    List<String> boards = [];
    if (_selectedGroup == 'MAIN') {
      boards = ['ALL', ...(_scraper.boardGroups['MAIN']?.keys ?? [])];
    } else if (_selectedGroup == 'ANNEX') {
      boards = ['ALL', ...(_scraper.boardGroups['ANNEX']?.keys ?? [])];
    } else if (_selectedGroup == 'DEPT') {
      Set<String> deptBoards = {};
      ['DEPT1', 'DEPT2', 'DEPT3', 'DEPT4'].forEach((key) {
        deptBoards.addAll(_scraper.boardGroups[key]?.keys ?? []);
      });
      boards = ['ALL', ...deptBoards];
    } else if (_selectedGroup == 'GRAD') {
      boards = ['ALL', ...(_scraper.boardGroups['GRAD']?.keys ?? [])];
    }

    final primary = theme['primary'] as Color;

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
              selectedColor: primary.withOpacity(0.1),
              backgroundColor: Theme.of(context).cardColor,
              labelStyle: TextStyle(
                color: selected ? primary : Colors.grey.shade700,
                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: BorderSide(color: selected ? primary : Colors.transparent),
              ),
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
          return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('공지사항이 없습니다.')));
        }

        final filtered = notices.where((n) {
          if (_selectedGroup == 'MY') return favorites.contains(n.id);
          
          if (_selectedGroup == 'DEPT') {
            if (!n.group.startsWith('DEPT')) return false;
            if (_selectedBoard != 'ALL') return n.category == _selectedBoard;
            return true;
          } else {
            if (_selectedBoard != 'ALL') return n.category == _selectedBoard;
            return n.group == _selectedGroup;
          }
        }).toList();

        if (filtered.isEmpty) {
          return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('해당 게시판에 공지가 없습니다.')));
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
      error: (error, stack) => Center(child: Text('에러가 발생했습니다: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }

  // ========== [수정] 검색 탭 ==========
  Widget _buildSearchTab(Map<String, dynamic> theme) {
    final noticesAsync = ref.watch(noticesProvider);
    final notices = noticesAsync.valueOrNull ?? [];
    final primary = theme['primary'] as Color;

    // [수정] 제목 정제 후 검색
    final results = notices.where((n) {
      final cleanTitle = n.title.replaceAll('새글', '').replaceAll('[새글]', '').trim();
      final matchesQuery = _searchQuery.isEmpty ||
          cleanTitle.toLowerCase().contains(_searchQuery.toLowerCase());
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
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 24),
          
          // [수정] 검색어가 없으면 카테고리 칩, 있으면 결과 리스트
          if (_searchQuery.isEmpty) ...[
            const Text(
              '카테고리',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _buildSearchCategoryList(theme),
            ),
          ] else ...[
             Row(
               children: [
                 const Text(
                  '검색 결과',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                 ),
                 const SizedBox(width: 8),
                 Text(
                  '${results.length}건',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primary),
                 ),
               ],
             ),
             const SizedBox(height: 12),
             Expanded(
               child: results.isEmpty 
               ? const Center(child: Text("검색 결과가 없습니다."))
               : AnimationLimiter(
                  child: ListView.builder(
                    itemCount: results.length,
                    itemBuilder: (ctx, i) {
                      return AnimationConfiguration.staggeredList(
                        position: i,
                        duration: const Duration(milliseconds: 375),
                        child: SlideAnimation(
                          verticalOffset: 50.0,
                          child: FadeInAnimation(
                            child: NoticeCard(notice: results[i], themeData: theme),
                          ),
                        ),
                      );
                    },
                  ),
               ),
             ),
          ]
        ],
      ),
    );
  }

  Widget _buildSearchCategoryList(Map<String, dynamic> theme) {
    final primary = theme['primary'] as Color;
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
      itemCount: sections.length + 1,
      itemBuilder: (ctx, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('전체'),
                  selected: _searchScope == '전체',
                  onSelected: (s) => setState(() => _searchScope = '전체'),
                  selectedColor: primary.withOpacity(0.1),
                  backgroundColor: Theme.of(context).cardColor,
                  labelStyle: TextStyle(
                    color: _searchScope == '전체' ? primary : Colors.grey.shade700,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: Colors.transparent)),
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
                  color: primary,
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
                  selectedColor: primary.withOpacity(0.1),
                  backgroundColor: Theme.of(context).cardColor,
                  labelStyle: TextStyle(
                    color: selected ? primary : Colors.grey.shade700,
                    fontSize: 12,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30), side: BorderSide(color: Colors.transparent)),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
          ],
        );
      },
    );
  }

  // ========== [수정] 설정 탭 (KNUE Mate 스타일) ==========
  Widget _buildSettingsTab() {
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate([
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '설정',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),

                  _buildSectionTitle('앱 테마'),
                  _buildSettingsCard(
                    children: [
                      _buildThemeModeSelector(), 
                      _buildDivider(),
                      _buildColorPalette(), 
                    ],
                  ),
                  
                  const SizedBox(height: 24),

                  _buildSectionTitle('알림'),
                  _buildSettingsCard(
                    children: [
                      _buildSwitchTile(
                        icon: LucideIcons.bell,
                        title: '키워드 알림',
                        subtitle: '등록한 키워드 포함 시 알림 수신',
                        value: ref.watch(alarmProvider),
                        onChanged: (v) => ref.read(alarmProvider.notifier).state = v,
                        color: Colors.orange,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  _buildSectionTitle('앱 정보'),
                  _buildSettingsCard(
                    children: [
                      _buildInfoTile(
                        icon: LucideIcons.info,
                        title: '버전 정보',
                        trailing: 'v1.2.0',
                        color: Colors.blue,
                        onTap: () {},
                      ),
                      _buildDivider(),
                      _buildInfoTile(
                        icon: LucideIcons.user,
                        title: '개발자 정보',
                        subtitle: '한국교원대학교 예비교사',
                        color: Colors.purple,
                        onTap: () => _showDeveloperInfo(context),
                      ),
                      _buildDivider(),
                      _buildInfoTile(
                        icon: LucideIcons.github,
                        title: '오픈소스 라이선스',
                        color: Colors.grey,
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName: 'KNUE MoA', 
                          applicationVersion: '1.2.0',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      "© 2026 KNUE MoA",
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider() {
    return Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor);
  }

  Widget _buildThemeModeSelector() {
    final currentMode = ref.watch(themeModeProvider);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          _buildThemeModeItem('라이트', LucideIcons.sun, ThemeMode.light, currentMode),
          _buildThemeModeItem('다크', LucideIcons.moon, ThemeMode.dark, currentMode),
          _buildThemeModeItem('시스템', LucideIcons.smartphone, ThemeMode.system, currentMode),
        ],
      ),
    );
  }

  Widget _buildThemeModeItem(String label, IconData icon, ThemeMode mode, ThemeMode current) {
    final isSelected = mode == current;
    final primary = Theme.of(context).primaryColor;
    return Expanded(
      child: GestureDetector(
        onTap: () => ref.read(themeModeProvider.notifier).setMode(mode),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? primary : Colors.grey.withOpacity(0.2),
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? primary : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? primary : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildColorPalette() {
    final currentColor = ref.watch(themeColorProvider);
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("테마 색상", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: AppTheme.palette.map((color) {
              final isSelected = color.value == currentColor.value;
              return GestureDetector(
                onTap: () => ref.read(themeColorProvider.notifier).setColor(color),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected ? Border.all(color: Colors.white, width: 2) : null,
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(color: color.withOpacity(0.5), blurRadius: 6),
                    ],
                  ),
                  child: isSelected 
                    ? const Icon(Icons.check, color: Colors.white, size: 18) 
                    : null,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSwitchTile({
    required IconData icon,
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: Colors.white,
            activeTrackColor: color,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTile({
    required IconData icon,
    required String title,
    String? subtitle,
    String? trailing,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade400),
              )
            else
              Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey.shade300),
          ],
        ),
      ),
    );
  }

  void _showDeveloperInfo(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: 400,
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 40),
             Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.blue.withOpacity(0.1),
              ),
              child: const Icon(LucideIcons.user, size: 50, color: Colors.blue),
            ),
            const SizedBox(height: 20),
            const Text("Hwang", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text("KNUE Physics & Elementary Edu", style: TextStyle(fontSize: 16, color: Colors.grey.shade500)),
            const SizedBox(height: 30),
            _buildDevInfoRow(LucideIcons.graduationCap, "소속", "한국교원대 물리교육/초등교육"),
            _buildDevInfoRow(LucideIcons.code, "관심분야", "Flutter, Embedded, AI"),
            _buildDevInfoRow(LucideIcons.mail, "이메일", "knuemeal16486@gmail.com"),
          ],
        ),
      ),
    );
  }

  Widget _buildDevInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey.shade400),
          const SizedBox(width: 20),
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
          const SizedBox(width: 20),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildBottomNav(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.only(bottom: 25, top: 10),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.1))),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(LucideIcons.home, '홈', 0, primaryColor),
          _navCenterBtn(primaryColor),
          _navItem(LucideIcons.settings, '설정', 2, primaryColor),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, int index, Color primaryColor) {
    final active = _activeTab == index;
    return GestureDetector(
      onTap: () => setState(() => _activeTab = index),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: active ? primaryColor : Colors.grey, size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: active ? primaryColor : Colors.grey,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _navCenterBtn(Color primaryColor) {
    return GestureDetector(
      onTap: () => setState(() => _activeTab = 1),
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.7)]),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.4),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(LucideIcons.search, color: Colors.white, size: 28),
      ),
    );
  }
}