import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:knue_moa/constants/theme_constants.dart';
import 'package:knue_moa/providers/providers.dart';
import 'package:knue_moa/services/scraper_service.dart';
import 'package:knue_moa/widgets/notice_card.dart';
import 'package:knue_moa/widgets/keyword_chip.dart';
import 'package:knue_moa/models/notice_model.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:knue_moa/screens/application_manage_page.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with SingleTickerProviderStateMixin {
  int _activeTab = 0;

  @override
  Widget build(BuildContext context) {
    final primaryColor = ref.watch(themeColorProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            if (_activeTab != 1 && _activeTab != 2) _buildHeader(primaryColor, isDark),
            Expanded(
              child: IndexedStack(
                index: _activeTab,
                children: const [
                  HomeTab(),
                  SearchTab(),
                  SettingsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(primaryColor),
    );
  }

  Widget _buildHeader(Color primaryColor, bool isDark) {
    final isAlarmOn = ref.watch(alarmProvider);
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
            onPressed: () {
              ref.read(alarmProvider.notifier).state = !isAlarmOn;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(!isAlarmOn ? '키워드 알림이 설정되었습니다.' : '알림이 해제되었습니다.')),
              );
            },
            icon: Icon(
              isAlarmOn ? LucideIcons.bell : LucideIcons.bellOff,
              color: isAlarmOn ? primaryColor : (isDark ? Colors.grey : const Color(0xFF334155)),
            ),
          ),
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
            style: TextStyle(color: active ? primaryColor : Colors.grey, fontSize: 11, fontWeight: FontWeight.bold),
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
          boxShadow: [BoxShadow(color: primaryColor.withOpacity(0.4), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: const Icon(LucideIcons.search, color: Colors.white, size: 28),
      ),
    );
  }
}

// =============================================================================
// [1] HomeTab
// =============================================================================
class HomeTab extends ConsumerStatefulWidget {
  const HomeTab({super.key});
  @override
  ConsumerState<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends ConsumerState<HomeTab> {
  String _selectedGroup = 'MAIN';
  String _selectedCollege = '제1대학';
  String _selectedDept = 'ALL';
  String _selectedBoard = 'ALL';
  bool _isInputVisible = false;
  final TextEditingController _keywordController = TextEditingController();
  
  // [수정] 각 그룹별 아이콘과 고유 색상 정의
  final Map<String, Map<String, dynamic>> _noticeGroups = {
    'MY': {'label': 'MY', 'icon': LucideIcons.star, 'color': Colors.amber},
    'FAV_BOARD': {'label': '즐겨찾기판', 'icon': LucideIcons.bookmark, 'color': Colors.redAccent},
    'MAIN': {'label': '본부 공지', 'icon': LucideIcons.building2, 'color': Colors.blue},
    'ANNEX': {'label': '부속 기관', 'icon': LucideIcons.library, 'color': Colors.green},
    'DEPT': {'label': '학과 홈페이지', 'icon': LucideIcons.graduationCap, 'color': Colors.purple},
    'GRAD': {'label': '대학원', 'icon': LucideIcons.school, 'color': Colors.orange},
  };

  @override
  Widget build(BuildContext context) {
    final primaryColor = ref.watch(themeColorProvider);
    final themeData = {
      'primary': primaryColor,
      'gradient': LinearGradient(colors: [primaryColor, primaryColor.withOpacity(0.7)], begin: Alignment.topLeft, end: Alignment.bottomRight),
    };

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(noticesProvider);
        ref.invalidate(aiRecommendationProvider); 
        return ref.read(refreshNoticesProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          _buildKeywordCard(themeData),
          const AiBanner(), 
          _buildFolderSystem(themeData),
          _buildNoticeList(themeData),
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
        boxShadow: [BoxShadow(color: (theme['primary'] as Color).withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Row(children: [Icon(LucideIcons.star, color: Colors.yellow, size: 22), SizedBox(width: 8), Text('나의 키워드', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))]),
          IconButton(onPressed: () => setState(() => _isInputVisible = !_isInputVisible), icon: Icon(_isInputVisible ? LucideIcons.x : LucideIcons.plus, color: Colors.white)),
        ]),
        if (_isInputVisible) 
          Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [Expanded(child: TextField(controller: _keywordController, decoration: InputDecoration(hintText: '예: 장학금', fillColor: Colors.white, filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12)), onSubmitted: (_) => _addKeyword())), const SizedBox(width: 8), ElevatedButton(onPressed: _addKeyword, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: theme['primary'], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14)), child: const Text('추가'))])),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: keywords.map((k) => KeywordChip(label: k, onDeleted: () => ref.read(keywordsNotifierProvider.notifier).remove(k))).toList()),
      ]),
    );
  }

  void _addKeyword() {
    if (_keywordController.text.isNotEmpty) {
      ref.read(keywordsNotifierProvider.notifier).add(_keywordController.text);
      _keywordController.clear();
      setState(() => _isInputVisible = false);
    }
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
              // [수정] 각 그룹별 고유 색상 사용
              final groupColor = entry.value['color'] as Color; 
              final effectiveColor = active ? groupColor : Colors.grey.shade400;
              
              return GestureDetector(
                onTap: () => setState(() {
                  _selectedGroup = entry.key;
                  _selectedBoard = 'ALL';
                  if (entry.key == 'DEPT') {
                    _selectedCollege = '제1대학';
                    _selectedDept = 'ALL';
                  }
                }),
                child: Container(
                  width: 75,
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        // [수정] 활성화 시 해당 그룹 색상의 배경 및 테두리 적용
                        decoration: BoxDecoration(
                          color: active ? groupColor.withOpacity(0.15) : Theme.of(context).cardColor, 
                          borderRadius: BorderRadius.circular(18), 
                          border: Border.all(color: active ? groupColor : Colors.grey.shade200, width: active ? 2 : 1)
                        ),
                        child: Icon(entry.value['icon'], color: effectiveColor, size: 24),
                      ),
                      const SizedBox(height: 6),
                      Text(entry.value['label'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: active ? groupColor : Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        _buildBoardSelector(theme),
      ],
    );
  }

  Widget _buildBoardSelector(Map<String, dynamic> theme) {
    final primary = theme['primary'] as Color;
    final scraper = KnueScraper();
    final favBoards = ref.watch(boardFavoritesProvider);

    if (_selectedGroup == 'FAV_BOARD') {
      if (favBoards.isEmpty) {
        return const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text("게시판 칩을 길게 눌러 즐겨찾기에 추가해보세요!", style: TextStyle(color: Colors.grey, fontSize: 12)),
        );
      }
      return Container(
        height: 50,
        margin: const EdgeInsets.only(bottom: 12),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: favBoards.length,
          itemBuilder: (ctx, index) {
            final board = favBoards[index];
            final selected = _selectedBoard == board;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _buildBoardChip(board, selected, primary, isRemovable: true),
            );
          },
        ),
      );
    }

    if (_selectedGroup == 'DEPT') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 8),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: KnueScraper.collegeStructure.keys.map((college) {
                final selected = _selectedCollege == college;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(college), selected: selected,
                    onSelected: (s) => setState(() { _selectedCollege = college; _selectedDept = 'ALL'; }),
                    selectedColor: primary.withOpacity(0.2), backgroundColor: Theme.of(context).cardColor,
                    labelStyle: TextStyle(color: selected ? primary : Colors.grey.shade700, fontWeight: FontWeight.bold, fontSize: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
                  ),
                );
              }).toList(),
            ),
          ),
          Container(
            height: 40,
            margin: const EdgeInsets.only(bottom: 12),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20),
              children: [
                 Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: const Text('전체'), selected: _selectedDept == 'ALL', onSelected: (s) => setState(() => _selectedDept = 'ALL'), selectedColor: primary.withOpacity(0.1), backgroundColor: Theme.of(context).cardColor, labelStyle: TextStyle(color: _selectedDept == 'ALL' ? primary : Colors.grey.shade700, fontSize: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: const BorderSide(color: Colors.transparent)))),
                ...(KnueScraper.collegeStructure[_selectedCollege] ?? []).map((dept) {
                  final selected = _selectedDept == dept;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildBoardChip(dept, selected, primary), 
                  );
                }).toList(),
              ],
            ),
          ),
        ],
      );
    } else {
      List<String> boards = [];
      if (_selectedGroup == 'MAIN') boards = ['ALL', ...?(scraper.boardGroups['MAIN']?.keys)];
      else if (_selectedGroup == 'ANNEX') boards = ['ALL', ...?(scraper.boardGroups['ANNEX']?.keys)];
      else if (_selectedGroup == 'GRAD') boards = ['ALL', ...?(scraper.boardGroups['GRAD']?.keys)];
      
      if (boards.isEmpty) return const SizedBox(height: 12);

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
              child: _buildBoardChip(board, selected, primary),
            );
          },
        ),
      );
    }
  }

  Widget _buildBoardChip(String boardName, bool selected, Color primary, {bool isRemovable = false}) {
    final isFav = ref.watch(boardFavoritesProvider).contains(boardName);
    
    return GestureDetector(
      onLongPress: () {
        if (boardName == 'ALL' || boardName == '전체') return;
        ref.read(boardFavoritesProvider.notifier).toggle(boardName);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(isFav ? '$boardName 즐겨찾기 해제' : '$boardName 즐겨찾기 추가'),
          duration: const Duration(milliseconds: 1000),
        ));
      },
      child: ChoiceChip(
        avatar: isFav && !isRemovable ? Icon(Icons.star, size: 14, color: primary) : null,
        label: Text(boardName == 'ALL' ? '전체보기' : boardName),
        selected: selected,
        onSelected: (s) => setState(() => _selectedBoard = boardName),
        selectedColor: primary.withOpacity(0.1),
        backgroundColor: Theme.of(context).cardColor,
        labelStyle: TextStyle(
          color: selected ? primary : Colors.grey.shade700,
          fontWeight: selected ? FontWeight.bold : FontWeight.normal
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
          side: BorderSide(color: selected ? primary : Colors.transparent)
        ),
      ),
    );
  }

  Widget _buildNoticeList(Map<String, dynamic> theme) {
    final noticesAsync = ref.watch(noticesProvider);
    final favorites = ref.watch(favoritesNotifierProvider);
    final favBoards = ref.watch(boardFavoritesProvider);

    return noticesAsync.when(
      data: (notices) {
        if (notices.isEmpty) return const Center(child: Padding(padding: EdgeInsets.all(40), child: Text('공지사항이 없습니다.\n(새로고침을 당겨주세요)')));

        final filtered = notices.where((n) {
          if (_selectedGroup == 'MY') return favorites.contains(n.id);
          
          if (_selectedGroup == 'FAV_BOARD') {
            if (favBoards.isEmpty) return false;
            if (!favBoards.contains(n.category)) return false;
            if (_selectedBoard != 'ALL' && _selectedBoard != '전체') return n.category == _selectedBoard;
            return true;
          }

          if (_selectedGroup == 'DEPT') {
            final targetDepts = KnueScraper.collegeStructure[_selectedCollege] ?? [];
            if (!targetDepts.contains(n.category)) return false;
            if (_selectedDept != 'ALL') return n.category == _selectedDept;
            return true;
          } else {
            if (n.group != _selectedGroup) return false;
            if (_selectedBoard != 'ALL') return n.category == _selectedBoard;
            return true;
          }
        }).toList();

        if (filtered.isEmpty) {
          String msg = '게시글이 없습니다.';
          if (_selectedGroup == 'FAV_BOARD' && favBoards.isEmpty) msg = '즐겨찾기한 게시판이 없습니다.\n다른 탭에서 게시판을 길게 눌러 추가해보세요.';
          return Center(child: Padding(padding: const EdgeInsets.all(40), child: Text(msg, textAlign: TextAlign.center)));
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
                    child: GestureDetector(
                      onTap: () {
                         ref.read(clickHistoryProvider.notifier).logClick(filtered[i].title);
                      },
                      child: NoticeCard(notice: filtered[i], themeData: theme),
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
      error: (error, stack) => Center(child: Text('에러 발생: $error')),
      loading: () => const Center(child: CircularProgressIndicator()),
    );
  }
}

// =============================================================================
// [2] AiBanner
// =============================================================================
class AiBanner extends ConsumerStatefulWidget {
  const AiBanner({super.key});
  @override
  ConsumerState<AiBanner> createState() => _AiBannerState();
}

class _AiBannerState extends ConsumerState<AiBanner> {
  int _aiBannerIndex = 0;
  Timer? _bannerTimer;

  @override
  void initState() {
    super.initState();
    _bannerTimer = Timer.periodic(const Duration(seconds: 5), (t) {
      if (mounted) setState(() => _aiBannerIndex++);
    });
  }

  @override
  void dispose() {
    _bannerTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final aiNoticesAsync = ref.watch(aiRecommendationProvider);

    return aiNoticesAsync.when(
      data: (notices) {
        if (notices.isEmpty) return const SizedBox.shrink();
        final notice = notices[_aiBannerIndex % notices.length];

        return GestureDetector(
          onTap: () async {
            ref.read(clickHistoryProvider.notifier).logClick(notice.title);
            final uri = Uri.parse(notice.link);
            if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
          },
          child: Container(
            margin: const EdgeInsets.all(20),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [Color(0xFF6A11CB), Color(0xFF2575FC)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2575FC).withOpacity(0.4),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                  child: const Icon(LucideIcons.sparkles, color: Colors.yellowAccent, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('AI 맞춤 추천 (Gemini) ✨', style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(
                        '[${notice.category}] ${notice.title}',
                        style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight, color: Colors.white54, size: 20),
              ],
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (e, s) => const SizedBox.shrink(),
    );
  }
}

// =============================================================================
// [3] SearchTab
// =============================================================================
class SearchTab extends ConsumerStatefulWidget {
  const SearchTab({super.key});
  @override
  ConsumerState<SearchTab> createState() => _SearchTabState();
}

class _SearchTabState extends ConsumerState<SearchTab> {
  String _searchQuery = '';
  String _searchScope = '전체';
  
  @override
  Widget build(BuildContext context) {
    final primary = ref.watch(themeColorProvider);
    final themeData = {'primary': primary};
    
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('검색', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            onChanged: (v) => setState(() => _searchQuery = v),
            decoration: InputDecoration(
              hintText: '제목으로 검색',
              prefixIcon: const Icon(LucideIcons.search),
              filled: true,
              fillColor: Theme.of(context).cardColor,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 24),
          if (_searchQuery.isEmpty) ...[
            const Text('카테고리', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 12),
            Expanded(child: _buildSearchCategoryList(primary)),
          ] else
            Expanded(child: _buildSearchResults(themeData)),
        ],
      ),
    );
  }

  Widget _buildSearchResults(Map<String, dynamic> theme) {
    final noticesAsync = ref.watch(noticesProvider);
    final notices = noticesAsync.valueOrNull ?? [];
    final results = notices.where((n) {
      final cleanTitle = n.title.replaceAll('새글', '').replaceAll('[새글]', '').trim();
      final matchesQuery = cleanTitle.toLowerCase().contains(_searchQuery.toLowerCase());
      final matchesScope = _searchScope == '전체' || n.category == _searchScope;
      return matchesQuery && matchesScope;
    }).toList();

    return Column(
      children: [
        Row(children: [const Text('검색 결과', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(width: 8), Text('${results.length}건', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme['primary']))]),
        const SizedBox(height: 12),
        Expanded(
          child: results.isEmpty 
          ? const Center(child: Text("검색 결과가 없습니다."))
          : AnimationLimiter(
              child: ListView.builder(
                itemCount: results.length,
                itemBuilder: (ctx, i) => AnimationConfiguration.staggeredList(
                  position: i,
                  duration: const Duration(milliseconds: 375),
                  child: SlideAnimation(
                    verticalOffset: 50.0, 
                    child: FadeInAnimation(
                      child: GestureDetector(
                        onTap: () => ref.read(clickHistoryProvider.notifier).logClick(results[i].title),
                        child: NoticeCard(notice: results[i], themeData: theme)
                      )
                    )
                  ),
                ),
              ),
            ),
        ),
      ],
    );
  }

  Widget _buildSearchCategoryList(Color primary) {
    final scraper = KnueScraper();
    final sections = [
      {'title': '본부 공지', 'boards': scraper.boardGroups['MAIN']?.keys.toList() ?? []},
      {'title': '부속 기관', 'boards': scraper.boardGroups['ANNEX']?.keys.toList() ?? []},
      {'title': '대학원', 'boards': scraper.boardGroups['GRAD']?.keys.toList() ?? []},
    ];

    return ListView.builder(
      itemCount: sections.length + 1,
      itemBuilder: (ctx, index) {
        if (index == 0) return Padding(padding: const EdgeInsets.only(bottom: 16), child: Wrap(spacing: 8, children: [ChoiceChip(label: const Text('전체'), selected: _searchScope == '전체', onSelected: (s) => setState(() => _searchScope = '전체'), selectedColor: primary.withOpacity(0.1), backgroundColor: Theme.of(context).cardColor, labelStyle: TextStyle(color: _searchScope == '전체' ? primary : Colors.grey.shade700))]));
        final section = sections[index - 1];
        final boards = section['boards'] as List<String>;
        if (boards.isEmpty) return const SizedBox.shrink();
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(section['title'] as String, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: primary))), Wrap(spacing: 8, runSpacing: 8, children: boards.map((board) { final selected = _searchScope == board; return ChoiceChip(label: Text(board), selected: selected, onSelected: (s) => setState(() => _searchScope = board), selectedColor: primary.withOpacity(0.1), backgroundColor: Theme.of(context).cardColor, labelStyle: TextStyle(color: selected ? primary : Colors.grey.shade700, fontSize: 12)); }).toList()), const SizedBox(height: 16)]);
      },
    );
  }
}

// =============================================================================
// [4] SettingsTab
// =============================================================================
class SettingsTab extends ConsumerWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CustomScrollView(
      slivers: [
        SliverList(
          delegate: SliverChildListDelegate([
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('설정', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 30),
                  
                  _buildSectionTitle('나의 데이터'),
                  _buildSettingsCard(context, children: [
                    _buildInfoTile(
                      icon: LucideIcons.fileText, 
                      title: '나의 지원서 관리', 
                      subtitle: '교내 프로그램 지원 정보 저장', 
                      color: Colors.green, 
                      onTap: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const ApplicationManagePage()));
                      }
                    ),
                  ]),
                  const SizedBox(height: 24),

                  _buildSectionTitle('앱 테마'),
                  _buildSettingsCard(context, children: [_buildThemeModeSelector(ref, context), _buildDivider(context), _buildColorPalette(ref)]),
                  const SizedBox(height: 24),
                  _buildSectionTitle('알림'),
                  _buildSettingsCard(context, children: [_buildSwitchTile(icon: LucideIcons.bell, title: '키워드 알림', subtitle: '등록한 키워드 포함 시 알림', value: ref.watch(alarmProvider), onChanged: (v) => ref.read(alarmProvider.notifier).state = v, color: Colors.orange)]),
                  const SizedBox(height: 24),
                  _buildSectionTitle('앱 정보'),
                  _buildSettingsCard(context, children: [_buildInfoTile(icon: LucideIcons.info, title: '버전 정보', trailing: 'v1.3.1', color: Colors.blue, onTap: () {}), _buildDivider(context), _buildInfoTile(icon: LucideIcons.user, title: '개발자 정보', subtitle: '한국교원대학교 예비교사', color: Colors.purple, onTap: () => _showDeveloperInfo(context)), _buildDivider(context), _buildInfoTile(icon: LucideIcons.github, title: '오픈소스 라이선스', color: Colors.grey, onTap: () => showLicensePage(context: context, applicationName: 'KNUE MoA', applicationVersion: '1.3.1'))]),
                  const SizedBox(height: 40),
                  Center(child: Text("© 2026 KNUE MoA", style: TextStyle(color: Colors.grey.shade400, fontSize: 12))),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) { return Padding(padding: const EdgeInsets.only(left: 4, bottom: 12), child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey))); }
  Widget _buildSettingsCard(BuildContext context, {required List<Widget> children}) { return Container(decoration: BoxDecoration(color: Theme.of(context).cardColor, borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]), child: Column(children: children)); }
  Widget _buildDivider(BuildContext context) { return Divider(height: 1, thickness: 1, color: Theme.of(context).dividerColor); }
  
  Widget _buildThemeModeSelector(WidgetRef ref, BuildContext context) {
    final currentMode = ref.watch(themeModeProvider);
    return Padding(padding: const EdgeInsets.all(8), child: Row(children: [_buildThemeModeItem(ref, context, '라이트', LucideIcons.sun, ThemeMode.light, currentMode), _buildThemeModeItem(ref, context, '다크', LucideIcons.moon, ThemeMode.dark, currentMode), _buildThemeModeItem(ref, context, '시스템', LucideIcons.smartphone, ThemeMode.system, currentMode)]));
  }
  
  Widget _buildThemeModeItem(WidgetRef ref, BuildContext context, String label, IconData icon, ThemeMode mode, ThemeMode current) {
    final isSelected = mode == current;
    final primary = Theme.of(context).primaryColor;
    return Expanded(child: GestureDetector(onTap: () => ref.read(themeModeProvider.notifier).setMode(mode), child: Container(margin: const EdgeInsets.symmetric(horizontal: 4), padding: const EdgeInsets.symmetric(vertical: 12), decoration: BoxDecoration(color: isSelected ? primary.withOpacity(0.1) : Colors.transparent, borderRadius: BorderRadius.circular(12), border: Border.all(color: isSelected ? primary : Colors.grey.withOpacity(0.2))), child: Column(children: [Icon(icon, color: isSelected ? primary : Colors.grey), const SizedBox(height: 4), Text(label, style: TextStyle(color: isSelected ? primary : Colors.grey, fontWeight: FontWeight.bold, fontSize: 12))]))));
  }

  Widget _buildColorPalette(WidgetRef ref) {
    final currentColor = ref.watch(themeColorProvider);
    return Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("테마 색상", style: TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 12), Wrap(spacing: 12, runSpacing: 12, children: AppTheme.palette.map((color) { final isSelected = color.value == currentColor.value; return GestureDetector(onTap: () => ref.read(themeColorProvider.notifier).setColor(color), child: Container(width: 32, height: 32, decoration: BoxDecoration(color: color, shape: BoxShape.circle, border: isSelected ? Border.all(color: Colors.white, width: 2) : null, boxShadow: [if (isSelected) BoxShadow(color: color.withOpacity(0.5), blurRadius: 6)]), child: isSelected ? const Icon(Icons.check, color: Colors.white, size: 18) : null)); }).toList())]));
  }

  Widget _buildSwitchTile({required IconData icon, required String title, String? subtitle, required bool value, required ValueChanged<bool> onChanged, required Color color}) { return Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500))]])), Switch(value: value, onChanged: onChanged, activeColor: Colors.white, activeTrackColor: color)])); }
  
  Widget _buildInfoTile({required IconData icon, required String title, String? subtitle, String? trailing, required Color color, required VoidCallback onTap}) { return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(20), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16), child: Row(children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)), if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade500))]])), if (trailing != null) Text(trailing, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade400)) else Icon(LucideIcons.chevronRight, size: 18, color: Colors.grey.shade300)]))); }

  void _showDeveloperInfo(BuildContext context) { showModalBottomSheet(context: context, backgroundColor: Colors.transparent, isScrollControlled: true, builder: (context) => Container(height: 400, decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))), child: Column(children: [const SizedBox(height: 8), Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))), const SizedBox(height: 40), Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withOpacity(0.1)), child: const Icon(LucideIcons.user, size: 50, color: Colors.blue)), const SizedBox(height: 20), const Text("Hwang", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text("KNUE Physics & Elementary Edu", style: TextStyle(fontSize: 16, color: Colors.grey.shade500)), const SizedBox(height: 30), _buildDevInfoRow(LucideIcons.graduationCap, "소속", "한국교원대 물리교육/초등교육"), _buildDevInfoRow(LucideIcons.code, "관심분야", "Flutter, Embedded, AI"), _buildDevInfoRow(LucideIcons.mail, "이메일", "knuemeal16486@gmail.com")]))); }
  
  Widget _buildDevInfoRow(IconData icon, String label, String value) { return Padding(padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 8), child: Row(children: [Icon(icon, size: 20, color: Colors.grey.shade400), const SizedBox(width: 20), Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)), const SizedBox(width: 20), Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500)))])); }
}