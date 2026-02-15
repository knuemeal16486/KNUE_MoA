import 'dart:async';
import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:knue_moa/models/notice_model.dart';
import 'package:knue_moa/services/scraper_service.dart';

class HomePage extends StatefulWidget {
  final Map<String, dynamic> currentTheme;
  final String themeKey;
  final Function(String) onThemeChange;

  const HomePage({super.key, required this.currentTheme, required this.themeKey, required this.onThemeChange});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _activeTab = 0;
  String _selectedGroup = 'MAIN';
  String _selectedBoard = 'ALL';
  String _searchScope = '전체';
  String _searchQuery = '';
  
  final KnueScraper _scraper = KnueScraper();
  List<Notice> _allNotices = [];
  List<String> _keywords = [];
  List<int> _favorites = [];
  bool _isAlarmOn = true;
  bool _isInputVisible = false;
  
  final TextEditingController _keywordController = TextEditingController();
  int _aiBannerIndex = 0;
  Timer? _bannerTimer;

  // React NOTICE_GROUPS를 사용자 데이터에 맞게 100% 반영
  final Map<String, Map<String, dynamic>> _noticeGroups = {
    'MY': {'label': 'MY', 'icon': LucideIcons.star},
    'MAIN': {'label': '본부 공지', 'icon': LucideIcons.building2},
    'ANNEX': {'label': '부속 기관', 'icon': LucideIcons.library},
    'DEPT1': {'label': '제1대학', 'icon': LucideIcons.graduationCap},
    'DEPT2': {'label': '제2대학', 'icon': LucideIcons.graduationCap},
    'DEPT3': {'label': '제3대학', 'icon': LucideIcons.graduationCap},
    'DEPT4': {'label': '제4대학', 'icon': LucideIcons.graduationCap},
    'GRAD': {'label': '대학원', 'icon': LucideIcons.school},
  };

  @override
  void initState() {
    super.initState();
    _loadStoredData();
    _refreshData();
    _startAiBanner();
  }

  Future<void> _loadStoredData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _keywords = prefs.getStringList('keywords') ?? ['장학', '수강', '졸업'];
      _favorites = (prefs.getStringList('favorites') ?? []).map(int.parse).toList();
      _isAlarmOn = prefs.getBool('isAlarmOn') ?? true;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('keywords', _keywords);
    await prefs.setStringList('favorites', _favorites.map((e) => e.toString()).toList());
    await prefs.setBool('isAlarmOn', _isAlarmOn);
  }

  void _refreshData() async {
    final data = await _scraper.fetchAllNotices();
    setState(() => _allNotices = data);
  }

  void _startAiBanner() {
    _bannerTimer = Timer.periodic(const Duration(seconds: 3), (t) {
      if (_allNotices.isNotEmpty) setState(() => _aiBannerIndex = (_aiBannerIndex + 1) % 5);
    });
  }

  Future<void> _launchURL(String url) async {
    if (!await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication)) {
      throw 'Could not launch $url';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: SafeArea(
        child: Column(
          children: [
            if (_activeTab != 1) _buildHeader(),
            Expanded(child: IndexedStack(index: _activeTab, children: [_buildHomeTab(), _buildSearchTab(), _buildSettingsTab()])),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          RichText(text: TextSpan(style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)), children: [
            const TextSpan(text: 'KNUE '),
            TextSpan(text: 'MoA', style: TextStyle(color: widget.currentTheme['primary'])),
          ])),
          IconButton(
            onPressed: () { setState(() => _isAlarmOn = !_isAlarmOn); _saveData(); },
            icon: Icon(_isAlarmOn ? LucideIcons.bell : LucideIcons.bellOff, color: const Color(0xFF334155)),
          )
        ],
      ),
    );
  }

  Widget _buildHomeTab() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 40),
      children: [_buildKeywordCard(), _buildAiBanner(), _buildFolderSystem(), _buildNoticeList()],
    );
  }

  Widget _buildKeywordCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(gradient: widget.currentTheme['gradient'], borderRadius: BorderRadius.circular(24)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Row(children: [Icon(LucideIcons.star, color: Colors.yellow, size: 20), SizedBox(width: 8), Text('나의 키워드', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))]),
            IconButton(onPressed: () => setState(() => _isInputVisible = !_isInputVisible), icon: Icon(_isInputVisible ? LucideIcons.x : LucideIcons.plus, color: Colors.white)),
          ]),
          if (_isInputVisible) _buildKeywordInput(),
          const SizedBox(height: 12),
          Wrap(spacing: 8, runSpacing: 8, children: _keywords.map((k) => Chip(label: Text('#$k', style: const TextStyle(color: Colors.white, fontSize: 11)), backgroundColor: Colors.white.withOpacity(0.2), onDeleted: () { setState(() => _keywords.remove(k)); _saveData(); }, deleteIconColor: Colors.white70)).toList()),
        ],
      ),
    );
  }

  Widget _buildKeywordInput() {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        Expanded(child: TextField(controller: _keywordController, decoration: InputDecoration(hintText: '키워드 입력', fillColor: Colors.white, filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)), onSubmitted: (v) => _addKeyword())),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: _addKeyword, style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: widget.currentTheme['primary']), child: const Text("추가")),
      ]),
    );
  }

  void _addKeyword() {
    if (_keywordController.text.isNotEmpty) {
      setState(() { _keywords.add(_keywordController.text); _keywordController.clear(); _isInputVisible = false; });
      _saveData();
    }
  }

  Widget _buildAiBanner() {
    if (_allNotices.isEmpty) return const SizedBox.shrink();
    final n = _allNotices[_aiBannerIndex % 5];
    return Container(
      margin: const EdgeInsets.all(20), height: 48,
      decoration: BoxDecoration(color: widget.currentTheme['bannerBg'], borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        const SizedBox(width: 15), const Icon(LucideIcons.sparkles, color: Colors.yellow, size: 18), const SizedBox(width: 15),
        Expanded(child: Text("[${n.category}] ${n.title}", style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
        const Icon(LucideIcons.chevronRight, color: Colors.white54, size: 18),
      ]),
    );
  }

  Widget _buildFolderSystem() {
    return Column(children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(children: _noticeGroups.entries.map((e) {
          bool active = _selectedGroup == e.key;
          return GestureDetector(
            onTap: () => setState(() { _selectedGroup = e.key; _selectedBoard = 'ALL'; }),
            child: Container(width: 75, padding: const EdgeInsets.only(bottom: 12), child: Column(children: [
              Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: active ? widget.currentTheme['bgLight'] : Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: active ? widget.currentTheme['primary'] : Colors.grey.shade100)), child: Icon(e.value['icon'], color: active ? widget.currentTheme['primary'] : Colors.grey.shade400)),
              const SizedBox(height: 6), Text(e.value['label'], style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: active ? widget.currentTheme['primary'] : Colors.grey)),
            ])),
          );
        }).toList()),
      ),
      if (_selectedGroup != 'MY') _buildBoardSelector(),
    ]);
  }

  Widget _buildBoardSelector() {
    final boards = ['ALL', ...(_scraper.boardGroups[_selectedGroup]?.keys ?? [])];
    return Container(
      height: 50, padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ListView(scrollDirection: Axis.horizontal, children: boards.map((b) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(b == 'ALL' ? '전체보기' : b), selected: _selectedBoard == b, onSelected: (s) => setState(() => _selectedBoard = b), selectedColor: widget.currentTheme['bgLight']))).toList()),
    );
  }

  Widget _buildNoticeList() {
    final filtered = _allNotices.where((n) {
      if (_selectedGroup == 'MY') return _favorites.contains(n.id);
      if (_selectedBoard != 'ALL') return n.category == _selectedBoard;
      if (_selectedGroup != 'MAIN') return n.group == _selectedGroup;
      return true;
    }).toList();

    return ListView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), padding: const EdgeInsets.symmetric(horizontal: 20), itemCount: filtered.length, itemBuilder: (c, i) => _buildNoticeCard(filtered[i]));
  }

  Widget _buildNoticeCard(Notice n) {
    bool isMatched = _keywords.any((k) => n.title.contains(k));
    bool isFav = _favorites.contains(n.id);
    final theme = widget.currentTheme;

    return GestureDetector(
      onTap: () => _launchURL(n.link), // 링크 연동 기능 복구
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: isMatched ? theme['primary'] : Colors.grey.shade100, width: isMatched ? 1.5 : 1)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), decoration: BoxDecoration(color: theme['categoryColor'], borderRadius: BorderRadius.circular(4)), child: Text(n.category, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme['categoryText']))),
            Text(n.date, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ]),
          const SizedBox(height: 8),
          Text(n.title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: isMatched ? theme['primary'] : const Color(0xFF1E293B))),
          const SizedBox(height: 12),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(n.author, style: const TextStyle(fontSize: 11, color: Colors.grey)),
            IconButton(constraints: const BoxConstraints(), padding: EdgeInsets.zero, icon: Icon(LucideIcons.star, color: isFav ? Colors.amber : Colors.grey.shade200, size: 18), onPressed: () { setState(() => isFav ? _favorites.remove(n.id) : _favorites.add(n.id)); _saveData(); }),
          ])
        ]),
      ),
    );
  }

  // --- 3. 검색 탭 (그리드 필터 복구) ---
  Widget _buildSearchTab() {
    final results = _allNotices.where((n) => n.title.toLowerCase().contains(_searchQuery.toLowerCase()) && (_searchScope == '전체' || n.category == _searchScope)).toList();
    return Padding(padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('검색', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 16),
      TextField(onChanged: (v) => setState(() => _searchQuery = v), decoration: InputDecoration(hintText: '제목 검색', prefixIcon: const Icon(LucideIcons.search), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
      const SizedBox(height: 24),
      const Text('검색 범위 선택', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
      const SizedBox(height: 12),
      Expanded(child: ListView(children: [
        _buildSearchScopeGrid(),
        if (_searchQuery.isNotEmpty) ...results.map((n) => _buildNoticeCard(n)).toList(),
      ])),
    ]));
  }

  Widget _buildSearchScopeGrid() {
    // 모든 링크 제목을 그리드에 포함
    List<String> allBoards = ['전체'];
    _scraper.boardGroups.values.forEach((group) => allBoards.addAll(group.keys));
    return Wrap(spacing: 8, runSpacing: 8, children: allBoards.take(15).map((s) => ChoiceChip(label: Text(s), selected: _searchScope == s, onSelected: (v) => setState(() => _searchScope = s))).toList());
  }

  // --- 4. 설정 탭 (KNUE Mate 고도화 복구) ---
  Widget _buildSettingsTab() {
    return ListView(padding: const EdgeInsets.all(24), children: [
      const Text('설정', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 30),
      _buildSettingsGroup("알림 및 개인화", [
        ListTile(leading: const Icon(LucideIcons.bell), title: const Text("키워드 알림"), trailing: Switch(value: _isAlarmOn, activeColor: widget.currentTheme['primary'], onChanged: (v) { setState(() => _isAlarmOn = v); _saveData(); })),
        ListTile(leading: const Icon(LucideIcons.palette), title: const Text("테마 색상"), trailing: _buildThemeSelector()),
      ]),
      const SizedBox(height: 20),
      _buildSettingsGroup("앱 정보", [
        const ListTile(leading: Icon(LucideIcons.info), title: Text("버전 정보"), trailing: Text("v1.0.4")),
        const ListTile(leading: Icon(LucideIcons.user), title: Text("개발자"), subtitle: Text("한국교원대 예비교사")),
      ]),
    ]);
  }

  Widget _buildSettingsGroup(String title, List<Widget> children) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: widget.currentTheme['primary'])),
      const SizedBox(height: 10),
      Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade100)), child: Column(children: children)),
    ]);
  }

  Widget _buildThemeSelector() {
    return Row(mainAxisSize: MainAxisSize.min, children: ['blue', 'green', 'orange'].map((k) => GestureDetector(onTap: () => widget.onThemeChange(k), child: Container(width: 20, height: 20, margin: const EdgeInsets.only(left: 8), decoration: BoxDecoration(color: k == 'blue' ? Colors.blue : k == 'green' ? Colors.green : Colors.orange, shape: BoxShape.circle, border: widget.themeKey == k ? Border.all(color: Colors.black, width: 2) : null)))).toList());
  }

  Widget _buildBottomNav() {
    return Container(padding: const EdgeInsets.only(bottom: 25, top: 10), decoration: const BoxDecoration(color: Colors.white, border: Border(top: BorderSide(color: Color(0xFFF1F5F9)))), child: Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      _navItem(LucideIcons.home, "홈", 0),
      _navCenterBtn(),
      _navItem(LucideIcons.settings, "설정", 2),
    ]));
  }

  Widget _navItem(IconData icon, String label, int index) {
    bool active = _activeTab == index;
    return GestureDetector(onTap: () => setState(() => _activeTab = index), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: active ? widget.currentTheme['primary'] : Colors.grey, size: 24), const SizedBox(height: 4), Text(label, style: TextStyle(color: active ? widget.currentTheme['primary'] : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold))]));
  }

  Widget _navCenterBtn() {
    return GestureDetector(onTap: () => setState(() => _activeTab = 1), child: Container(width: 52, height: 52, decoration: BoxDecoration(gradient: widget.currentTheme['gradient'], shape: BoxShape.circle, boxShadow: [BoxShadow(color: widget.currentTheme['primary'].withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))]), child: const Icon(LucideIcons.search, color: Colors.white, size: 24)));
  }
}