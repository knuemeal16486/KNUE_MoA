import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:knue_moa/constants/theme_constants.dart';
import 'package:knue_moa/models/personal_schedule_model.dart';
import 'package:knue_moa/models/dday_model.dart';
import 'package:knue_moa/providers/providers.dart';
import 'package:knue_moa/services/scraper_service.dart';
import 'package:knue_moa/widgets/notice_card.dart';
import 'package:knue_moa/widgets/keyword_chip.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:knue_moa/screens/application_manage_page.dart';
import 'package:knue_moa/screens/developer_info_page.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:uuid/uuid.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
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
            if (_activeTab != 1 && _activeTab != 2)
              _buildHeader(primaryColor, isDark),
            Expanded(
              child: IndexedStack(
                index: _activeTab,
                children: const [HomeTab(), SearchTab(), SettingsTab()],
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
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
              children: [
                const TextSpan(text: 'KNUE '),
                TextSpan(
                  text: 'MoA',
                  style: TextStyle(color: primaryColor),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ref.read(alarmProvider.notifier).setAlarm(!isAlarmOn);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    !isAlarmOn ? '키워드 알림이 설정되었습니다.' : '알림이 해제되었습니다.',
                  ),
                ),
              );
            },
            icon: Icon(
              isAlarmOn ? LucideIcons.bell : LucideIcons.bellOff,
              color: isAlarmOn
                  ? primaryColor
                  : (isDark ? Colors.grey : const Color(0xFF334155)),
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
        border: Border(
          top: BorderSide(
            color: Theme.of(context).dividerColor.withValues(alpha: 0.1),
          ),
        ),
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
          gradient: LinearGradient(
            colors: [primaryColor, primaryColor.withValues(alpha: 0.7)],
          ),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: primaryColor.withValues(alpha: 0.4),
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
  String _selectedAnnexGroup = '도서관';
  String _selectedBoard = 'ALL';
  int _noticeDisplayLimit = 10;
  bool _isInputVisible = false;
  final TextEditingController _keywordController = TextEditingController();

  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  Color _getEventColor(String title) {
    if (title.contains('시험') || title.contains('중간') || title.contains('기말')) {
      return const Color(0xFFF87171); // Red
    } else if (title.contains('방학') || title.contains('휴업')) {
      return const Color(0xFF60A5FA); // Blue
    } else if (title.contains('수강') || title.contains('등록')) {
      return const Color(0xFF34D399); // Green
    } else if (title.contains('신청') || title.contains('변경')) {
      return const Color(0xFFFBBF24); // Amber
    } else if (title.contains('발표') || title.contains('통보')) {
      return const Color(0xFFA78BFA); // Violet
    } else {
      final h = title.hashCode.abs();
      return HSLColor.fromAHSL(1.0, (h % 360).toDouble(), 0.7, 0.6).toColor();
    }
  }

  // [수정] 각 그룹별 아이콘과 고유 색상 정의
  final Map<String, Map<String, dynamic>> _noticeGroups = {
    'MY': {'label': 'MY', 'icon': LucideIcons.star, 'color': Colors.amber},
    'MAIN': {
      'label': '본부 공지',
      'icon': LucideIcons.building2,
      'color': Colors.blue,
    },
    'ANNEX': {
      'label': '부속 기관',
      'icon': LucideIcons.library,
      'color': Colors.green,
    },
    'DEPT': {
      'label': '학과 홈페이지',
      'icon': LucideIcons.graduationCap,
      'color': Colors.purple,
    },
    'LIFE': {
      'label': '대학생활',
      'icon': LucideIcons.coffee,
      'color': Colors.deepOrange,
    },
    'GRAD': {
      'label': '대학원',
      'icon': LucideIcons.school,
      'color': Colors.orange,
    },
  };

  @override
  Widget build(BuildContext context) {
    final primaryColor = ref.watch(themeColorProvider);
    final themeData = {
      'primary': primaryColor,
      'gradient': LinearGradient(
        colors: [primaryColor, primaryColor.withOpacity(0.7)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    };

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(aiRecommendationProvider);
        await ref.read(noticesProvider.notifier).refresh();
      },
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildKeywordCard(themeData)),
          const SliverToBoxAdapter(child: AiBanner()),
          SliverToBoxAdapter(child: _buildFolderSystem(themeData)),
          _buildNoticeListSliver(themeData),
          SliverToBoxAdapter(child: _buildRecentNoticesHighlight(themeData)),
          SliverToBoxAdapter(child: _buildCalendar(themeData)),
          const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
        ],
      ),
    );
  }

  Widget _buildCalendar(Map<String, dynamic> theme) {
    final primary = theme['primary'] as Color;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final asyncEvents = ref.watch(
      calendarProvider(DateTime(_focusedDay.year, _focusedDay.month)),
    );
    final personalSchedules = ref.watch(personalScheduleProvider);
    final ddays = ref.watch(ddayProvider);

    // 날짜별 이벤트 로더 (학사일정 + 개인일정 통합)
    List<dynamic> _eventsForDay(DateTime day) {
      final qDay = DateTime(day.year, day.month, day.day);
      final academic = (asyncEvents.value ?? []).where((e) {
        final s = DateTime(
          e.startDate.year,
          e.startDate.month,
          e.startDate.day,
        );
        final end = DateTime(e.endDate.year, e.endDate.month, e.endDate.day);
        return qDay.isAtSameMomentAs(s) ||
            (qDay.isAfter(s) &&
                (qDay.isBefore(end) || qDay.isAtSameMomentAs(end)));
      }).toList();

      // 학사일정 중복 제목(이름) 제거
      final uniqueAcademic = <String, dynamic>{};
      for (final e in academic) {
        uniqueAcademic[e.title] = e;
      }

      final personal = personalSchedules.where((p) {
        final s = DateTime(
          p.startDate.year,
          p.startDate.month,
          p.startDate.day,
        );
        final end = DateTime(p.endDate.year, p.endDate.month, p.endDate.day);
        return qDay.isAtSameMomentAs(s) ||
            (qDay.isAfter(s) &&
                (qDay.isBefore(end) || qDay.isAtSameMomentAs(end)));
      }).toList();

      return [...uniqueAcademic.values, ...personal];
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 헤더 ──
          Row(
            children: [
              Icon(LucideIcons.calendar, color: primary, size: 22),
              const SizedBox(width: 8),
              Text(
                '학사일정',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const Spacer(),
              // ─ 디데이 추가 버튼 ─
              GestureDetector(
                onTap: () => _showAddDDayDialog(context, primary, isDark),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.flag,
                        color: Colors.orange.shade600,
                        size: 13,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'D-Day',
                        style: TextStyle(
                          color: Colors.orange.shade600,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // ─ 알림 설정 버튼 ─
              if (Platform.isAndroid || Platform.isIOS)
                IconButton(
                  onPressed: () =>
                      _showCalendarAlarmSettings(context, primary, isDark),
                  icon: Icon(LucideIcons.bellRing, color: primary, size: 20),
                  tooltip: '알림 설정',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              const SizedBox(width: 8),
              // ─ 개인일정 추가 버튼 ─
              GestureDetector(
                onTap: () => _showAddScheduleDialog(context, primary, isDark),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.plus, color: primary, size: 14),
                      const SizedBox(width: 4),
                      Text(
                        '개인일정',
                        style: TextStyle(
                          color: primary,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // ── D-Day 섹션 ──
          if (ddays.isNotEmpty) ...[
            const SizedBox(height: 14),
            _buildDDaySection(ddays, primary, isDark),
          ],
          // ── 범례 설명 ──
          const SizedBox(height: 16),
          Row(
            children: [
              _legendDot(Colors.blue.shade300),
              const SizedBox(width: 4),
              Text(
                '학사일정',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
              const SizedBox(width: 12),
              _legendDot(const Color(0xFF6366F1)),
              const SizedBox(width: 4),
              Text(
                '개인일정',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // ── 달력 ──
          TableCalendar(
            firstDay: DateTime.utc(DateTime.now().year - 2, 1, 1),
            lastDay: DateTime.utc(DateTime.now().year + 2, 12, 31),
            focusedDay: _focusedDay,
            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
            calendarFormat: CalendarFormat.month,
            startingDayOfWeek: StartingDayOfWeek.sunday,
            calendarBuilders: CalendarBuilders(
              dowBuilder: (context, day) {
                final days = ['월', '화', '수', '목', '금', '토', '일'];
                final text = days[day.weekday - 1];
                return Center(
                  child: Text(
                    text,
                    style: TextStyle(
                      color: day.weekday == DateTime.sunday
                          ? Colors.red
                          : day.weekday == DateTime.saturday
                          ? Colors.blue
                          : Colors.grey,
                    ),
                  ),
                );
              },
              headerTitleBuilder: (context, day) {
                return Center(
                  child: Text(
                    '${day.year}.${day.month.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                );
              },
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return null;
                return Positioned(
                  bottom: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: events.take(4).map((event) {
                      final isPersonal = event is PersonalSchedule;
                      final color = isPersonal
                          ? Color(event.colorValue)
                          : _getEventColor((event as CalendarEvent).title);
                      return Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 0.5),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      );
                    }).toList(),
                  ),
                );
              },
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false,
              titleCentered: true,
            ),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: primary, width: 1.5),
              ),
              todayTextStyle: TextStyle(
                color: Theme.of(context).textTheme.bodyLarge?.color,
                fontWeight: FontWeight.bold,
              ),
              selectedDecoration: BoxDecoration(
                color: primary,
                shape: BoxShape.circle,
              ),
            ),
            onDaySelected: (selectedDay, focusedDay) {
              setState(() {
                _selectedDay = selectedDay;
                _focusedDay = focusedDay;
              });
            },
            onPageChanged: (focusedDay) {
              setState(() {
                _focusedDay = focusedDay;
              });
            },
            eventLoader: _eventsForDay,
          ),
          const SizedBox(height: 12),
          // ── 선택된 날짜의 일정 표시 ──
          if (_selectedDay != null)
            ..._buildSelectedDayEvents(
              _eventsForDay(_selectedDay!),
              asyncEvents,
              personalSchedules,
              primary,
              isDark,
            ),
        ],
      ),
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  List<Widget> _buildSelectedDayEvents(
    List<dynamic> events,
    AsyncValue asyncAcademic,
    List<PersonalSchedule> personalSchedules,
    Color primary,
    bool isDark,
  ) {
    if (events.isEmpty) {
      return [
        const Padding(
          padding: EdgeInsets.only(top: 4.0),
          child: Text('일정이 없습니다.', style: TextStyle(color: Colors.grey)),
        ),
      ];
    }
    return events.map((event) {
      if (event is PersonalSchedule) {
        final color = Color(event.colorValue);
        return Container(
          margin: const EdgeInsets.only(top: 6),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 36,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '개인',
                            style: TextStyle(
                              fontSize: 9,
                              color: color,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    if (event.memo != null && event.memo!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          event.memo!,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              // 수정 / 삭제 버튼
              IconButton(
                icon: Icon(LucideIcons.pencil, size: 14, color: color),
                onPressed: () => _showAddScheduleDialog(
                  context,
                  primary,
                  isDark,
                  existing: event,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  LucideIcons.trash2,
                  size: 14,
                  color: Colors.red.shade300,
                ),
                onPressed: () => _deleteSchedule(event),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        );
      } else {
        // 학사일정
        final e = event as CalendarEvent;
        final color = _getEventColor(e.title);
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(LucideIcons.checkCircle2, size: 16, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(e.title, style: const TextStyle(fontSize: 13)),
              ),
            ],
          ),
        );
      }
    }).toList();
  }

  void _deleteSchedule(PersonalSchedule schedule) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('일정 삭제'),
        content: Text('“${schedule.title}”을(를) 삭제하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () {
              ref.read(personalScheduleProvider.notifier).delete(schedule.id);
              Navigator.pop(ctx);
            },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // ── 개인일정 저장/수정 다이얼로그 ──
  void _showAddScheduleDialog(
    BuildContext context,
    Color primary,
    bool isDark, {
    PersonalSchedule? existing,
  }) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final memoCtrl = TextEditingController(text: existing?.memo ?? '');
    DateTime startDate =
        existing?.startDate ?? (_selectedDay ?? DateTime.now());
    DateTime endDate = existing?.endDate ?? startDate;
    int colorValue = existing?.colorValue ?? 0xFF6366F1;
    bool notifyBefore = existing?.notifyBefore ?? false;
    int notifyMinutes = existing?.notifyMinutesBefore ?? 60;

    final colorPalette = [
      0xFF6366F1,
      0xFF10B981,
      0xFFF59E0B,
      0xFFEF4444,
      0xFF3B82F6,
      0xFF8B5CF6,
      0xFFEC4899,
      0xFF14B8A6,
    ];
    final notifyOptions = [
      (30, '30분 전'),
      (60, '1시간 전'),
      (120, '2시간 전'),
      (1440, '1일 전'),
      (2880, '2일 전'),
      (10080, '1주일 전'),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 핸들 바
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    existing != null ? '일정 수정' : '개인 일정 추가',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ─ 제목 ─
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: '일정 제목 *',
                      labelStyle: TextStyle(color: primary),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2D2D3F)
                          : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // ─ 담린 ─
                  TextField(
                    controller: memoCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: '메모 (선택)',
                      labelStyle: TextStyle(color: primary),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2D2D3F)
                          : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ─ 날짜 선택 ─
                  Row(
                    children: [
                      Expanded(
                        child: _datePickerButton(
                          '시작일',
                          startDate,
                          primary,
                          isDark,
                          () async {
                            final picked = await showDatePicker(
                              context: context,
                              useRootNavigator: true,
                              initialDate: startDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              locale: const Locale('ko', 'KR'),
                            );
                            if (picked != null) {
                              setModalState(() {
                                startDate = picked;
                                if (endDate.isBefore(startDate)) {
                                  endDate = startDate;
                                }
                              });
                            }
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '→',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _datePickerButton(
                          '종료일',
                          endDate,
                          primary,
                          isDark,
                          () async {
                            final picked = await showDatePicker(
                              context: context,
                              useRootNavigator: true,
                              initialDate: endDate,
                              firstDate: startDate,
                              lastDate: DateTime(2030),
                              locale: const Locale('ko', 'KR'),
                            );
                            if (picked != null)
                              setModalState(() => endDate = picked);
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // ─ 색상 선택 ─
                  Text(
                    '색상',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: colorPalette.map((c) {
                      final isSelected = colorValue == c;
                      return GestureDetector(
                        onTap: () => setModalState(() => colorValue = c),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Color(c).withOpacity(0.5),
                                      blurRadius: 6,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  if (Platform.isAndroid || Platform.isIOS) ...[
                    const SizedBox(height: 16),
                    // ─ 알림 설정 ─
                    Row(
                      children: [
                        Text(
                          '일정 알림',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const Spacer(),
                        Switch(
                          value: notifyBefore,
                          activeColor: primary,
                          onChanged: (v) =>
                              setModalState(() => notifyBefore = v),
                        ),
                      ],
                    ),
                    if (notifyBefore) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: notifyOptions.map((opt) {
                          final isSelected = notifyMinutes == opt.$1;
                          return GestureDetector(
                            onTap: () =>
                                setModalState(() => notifyMinutes = opt.$1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primary
                                    : (isDark
                                          ? const Color(0xFF2D2D3F)
                                          : const Color(0xFFF1F5F9)),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                opt.$2,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade600,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  // ─ 저장 버튼 ─
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (titleCtrl.text.trim().isEmpty) return;
                        final schedule = PersonalSchedule(
                          id: existing?.id ?? const Uuid().v4(),
                          title: titleCtrl.text.trim(),
                          startDate: startDate,
                          endDate: endDate,
                          memo: memoCtrl.text.trim().isEmpty
                              ? null
                              : memoCtrl.text.trim(),
                          colorValue: colorValue,
                          notifyBefore: notifyBefore,
                          notifyMinutesBefore: notifyMinutes,
                        );
                        if (existing != null) {
                          ref
                              .read(personalScheduleProvider.notifier)
                              .update(schedule);
                        } else {
                          ref
                              .read(personalScheduleProvider.notifier)
                              .add(schedule);
                        }
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        existing != null ? '수정 완료' : '일정 저장',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _datePickerButton(
    String label,
    DateTime date,
    Color primary,
    bool isDark,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2D2D3F) : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: primary.withOpacity(0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
            ),
            const SizedBox(height: 2),
            Text(
              '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── D-Day 섹션 위젯 ──
  Widget _buildDDaySection(List<DDay> ddays, Color primary, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(LucideIcons.flag, color: Colors.orange.shade600, size: 15),
            const SizedBox(width: 6),
            Text(
              'D-Day',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.orange.shade600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 86,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: ddays.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final dday = ddays[index];
              final color = Color(dday.colorValue);
              final d = dday.daysLeft;
              final label = dday.ddayLabel;
              final isToday = d == 0;
              final isPast = d < 0;
              return GestureDetector(
                onLongPress: () =>
                    _showDDayOptions(context, dday, primary, isDark),
                child: Container(
                  width: 110,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [color, color.withOpacity(0.75)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        dday.title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isToday ? 20 : 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                        ),
                      ),
                      Text(
                        isPast
                            ? '${dday.targetDate.month}/${dday.targetDate.day} 지낙'
                            : isToday
                            ? '오늘!'
                            : '${dday.targetDate.month}/${dday.targetDate.day}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '길게 누르면 수정/삭제할 수 있어요',
          style: TextStyle(fontSize: 10, color: Colors.grey.shade400),
        ),
        const SizedBox(height: 14),
      ],
    );
  }

  // ── D-Day 수정/삭제 옵션 ──
  void _showDDayOptions(
    BuildContext context,
    DDay dday,
    Color primary,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 36),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              dday.title,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF1E293B),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              dday.ddayLabel,
              style: TextStyle(
                fontSize: 14,
                color: Color(dday.colorValue),
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              leading: Icon(LucideIcons.pencil, color: primary),
              title: const Text('수정'),
              onTap: () {
                Navigator.pop(ctx);
                _showAddDDayDialog(context, primary, isDark, existing: dday);
              },
            ),
            ListTile(
              leading: Icon(LucideIcons.trash2, color: Colors.red.shade400),
              title: Text('삭제', style: TextStyle(color: Colors.red.shade400)),
              onTap: () {
                ref.read(ddayProvider.notifier).delete(dday.id);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }

  // ── D-Day 추가/수정 다이얼로그 ──
  void _showAddDDayDialog(
    BuildContext context,
    Color primary,
    bool isDark, {
    DDay? existing,
  }) {
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    DateTime targetDate = existing?.targetDate ?? DateTime.now();
    int colorValue = existing?.colorValue ?? 0xFFEF4444;

    final colorPalette = [
      0xFFEF4444,
      0xFFF97316,
      0xFFEAB308,
      0xFF22C55E,
      0xFF3B82F6,
      0xFF8B5CF6,
      0xFFEC4899,
      0xFF14B8A6,
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final now = DateTime.now();
          final today = DateTime(now.year, now.month, now.day);
          final target = DateTime(
            targetDate.year,
            targetDate.month,
            targetDate.day,
          );
          final diff = target.difference(today).inDays;
          final previewLabel = diff == 0
              ? 'D-Day'
              : diff > 0
              ? 'D-$diff'
              : 'D+${diff.abs()}';

          return Container(
            padding: EdgeInsets.only(
              left: 24,
              right: 24,
              top: 24,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 32,
            ),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Text(
                        existing != null ? 'D-Day 수정' : 'D-Day 추가',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      // 미리보기
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Color(colorValue),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          previewLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // ─ 이름 입력 ─
                  TextField(
                    controller: titleCtrl,
                    onChanged: (_) => setModalState(() {}),
                    decoration: InputDecoration(
                      labelText: 'D-Day 이름 *',
                      labelStyle: TextStyle(color: Colors.orange.shade600),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2D2D3F)
                          : const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(color: Colors.orange.shade400),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  // ─ 날짜 선택 ─
                  Text(
                    '목표 날짜',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      // Bottom sheet의 ctx가 아닌 외부 context 사용
                      // — Root Navigator를 강제 사용 → Bottom sheet와의 Navigator 충돌 방지
                      final picked = await showDatePicker(
                        context: context,
                        useRootNavigator: true,
                        initialDate: targetDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035),
                        locale: const Locale('ko', 'KR'),
                      );
                      if (picked != null) {
                        setModalState(() => targetDate = picked);
                      }
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF2D2D3F)
                            : const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            LucideIcons.calendarDays,
                            color: Colors.orange.shade500,
                            size: 18,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            '${targetDate.year}.${targetDate.month.toString().padLeft(2, '0')}.${targetDate.day.toString().padLeft(2, '0')}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // ─ 색상 선택 ─
                  Text(
                    '색상',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: colorPalette.map((c) {
                      final isSelected = colorValue == c;
                      return GestureDetector(
                        onTap: () => setModalState(() => colorValue = c),
                        child: Container(
                          width: 34,
                          height: 34,
                          decoration: BoxDecoration(
                            color: Color(c),
                            shape: BoxShape.circle,
                            border: isSelected
                                ? Border.all(color: Colors.white, width: 3)
                                : null,
                            boxShadow: isSelected
                                ? [
                                    BoxShadow(
                                      color: Color(c).withOpacity(0.5),
                                      blurRadius: 8,
                                    ),
                                  ]
                                : null,
                          ),
                          child: isSelected
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 16,
                                )
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 28),
                  // ─ 저장 버튼 ─
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        if (titleCtrl.text.trim().isEmpty) return;
                        final newDDay = DDay(
                          id: existing?.id ?? const Uuid().v4(),
                          title: titleCtrl.text.trim(),
                          targetDate: targetDate,
                          colorValue: colorValue,
                        );
                        if (existing != null) {
                          ref.read(ddayProvider.notifier).update(newDDay);
                        } else {
                          ref.read(ddayProvider.notifier).add(newDDay);
                        }
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(colorValue),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        existing != null ? '수정 완료' : 'D-Day 저장',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── 달력 알림 설정 다이얼로그 ──
  void _showCalendarAlarmSettings(
    BuildContext context,
    Color primary,
    bool isDark,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final academicAlarm = ref.read(academicAlarmProvider);
          final academicDays = ref.read(academicAlarmDaysProvider);
          final personalAlarm = ref.read(personalAlarmProvider);

          return Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2E) : Colors.white,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(28),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  '달력 알림 설정',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 24),
                // 학사일정 알림
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2D2D3F)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            LucideIcons.calendarDays,
                            color: primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '학사일정 알림',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                          const Spacer(),
                          Switch(
                            value: academicAlarm,
                            activeColor: primary,
                            onChanged: (v) {
                              ref
                                  .read(academicAlarmProvider.notifier)
                                  .toggle(v);
                              setModalState(() {});
                            },
                          ),
                        ],
                      ),
                      if (academicAlarm) ...[
                        const SizedBox(height: 12),
                        Text(
                          '며칠 전 알림',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [1, 2, 3, 5, 7].map((d) {
                            final isSelected = academicDays == d;
                            return GestureDetector(
                              onTap: () {
                                ref
                                    .read(academicAlarmDaysProvider.notifier)
                                    .set(d);
                                setModalState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 6,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? primary
                                      : (isDark
                                            ? const Color(0xFF1E1E2E)
                                            : Colors.white),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? primary
                                        : Colors.grey.shade300,
                                  ),
                                ),
                                child: Text(
                                  '$d일 전',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isSelected
                                        ? Colors.white
                                        : Colors.grey.shade600,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                // 개인일정 알림
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2D2D3F)
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        LucideIcons.calendarHeart,
                        color: const Color(0xFF6366F1),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '개인일정 알림',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF1E293B),
                        ),
                      ),
                      const Spacer(),
                      Switch(
                        value: personalAlarm,
                        activeColor: const Color(0xFF6366F1),
                        onChanged: (v) {
                          ref.read(personalAlarmProvider.notifier).toggle(v);
                          setModalState(() {});
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '개인일정의 알림 시간은 각 일정 추가 시 설정할 수 있습니다.',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildKeywordCard(Map<String, dynamic> theme) {
    final keywords = ref.watch(keywordsNotifierProvider);
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
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () =>
                    setState(() => _isInputVisible = !_isInputVisible),
                icon: Icon(
                  _isInputVisible ? LucideIcons.x : LucideIcons.plus,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          if (_isInputVisible)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _keywordController,
                      decoration: InputDecoration(
                        hintText: '예: 장학금',
                        fillColor: Colors.white,
                        filled: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('추가'),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: keywords
                .map(
                  (k) => KeywordChip(
                    label: k,
                    onDeleted: () =>
                        ref.read(keywordsNotifierProvider.notifier).remove(k),
                  ),
                )
                .toList(),
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

  Widget _buildRecentNoticesHighlight(Map<String, dynamic> theme) {
    final noticesAsync = ref.watch(noticesProvider);
    return noticesAsync.when(
      data: (notices) {
        if (notices.isEmpty) return const SizedBox.shrink();

        // 상단 최신 5개 추출
        final recent = notices.take(5).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  Icon(LucideIcons.zap, color: theme['primary'], size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    '방금 올라온 소식',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 130, // 적절한 높이
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: recent.length,
                itemBuilder: (context, index) {
                  final notice = recent[index];
                  return GestureDetector(
                    onTap: () async {
                      ref
                          .read(clickHistoryProvider.notifier)
                          .logClick(notice.title);
                      if (!await launchUrl(Uri.parse(notice.link))) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('링크를 열 수 없습니다.')),
                        );
                      }
                    },
                    child: Container(
                      width: 260,
                      margin: const EdgeInsets.only(right: 12, bottom: 8),
                      padding: const EdgeInsets.all(16),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: theme['primary'].withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  notice.category,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: theme['primary'],
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Text(
                                notice.date,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            notice.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildFolderSystem(Map<String, dynamic> theme) {
    return Column(
      children: [
        SizedBox(
          height: 100,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: _noticeGroups.keys.map((groupKey) {
                final active = _selectedGroup == groupKey;
                final groupData = _noticeGroups[groupKey]!;
                final groupColor = groupData['color'] as Color;
                final effectiveColor = active
                    ? groupColor
                    : Colors.grey.shade400;

                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedGroup = groupKey;
                    _selectedBoard = 'ALL';
                    _noticeDisplayLimit = 10;
                    if (groupKey == 'DEPT') {
                      _selectedCollege = '제1대학';
                      _selectedDept = 'ALL';
                    }
                    if (groupKey == 'ANNEX') {
                      _selectedAnnexGroup = '도서관';
                      _selectedBoard = 'ALL';
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
                          decoration: BoxDecoration(
                            color: active
                                ? groupColor.withOpacity(0.15)
                                : Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: active ? groupColor : Colors.grey.shade200,
                              width: active ? 2 : 1,
                            ),
                          ),
                          child: Icon(
                            groupData['icon'],
                            color: effectiveColor,
                            size: 24,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          groupData['label'],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: active ? groupColor : Colors.grey,
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
        ),
        _buildBoardSelector(theme),
      ],
    );
  }

  Widget _buildBoardSelector(Map<String, dynamic> theme) {
    final primary = theme['primary'] as Color;
    final scraper = ref.read(scraperProvider);

    if (_selectedGroup == 'MY') return const SizedBox(height: 12);

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
                    label: Text(college),
                    selected: selected,
                    onSelected: (s) => setState(() {
                      _selectedCollege = college;
                      _selectedDept = 'ALL';
                      _noticeDisplayLimit = 10;
                    }),
                    selectedColor: primary.withOpacity(0.2),
                    backgroundColor: Theme.of(context).cardColor,
                    labelStyle: TextStyle(
                      color: selected ? primary : Colors.grey.shade700,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide.none,
                    ),
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
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: const Text('전체'),
                    selected: _selectedDept == 'ALL',
                    onSelected: (s) => setState(() {
                      _selectedDept = 'ALL';
                      _noticeDisplayLimit = 10;
                    }),
                    selectedColor: primary.withOpacity(0.1),
                    backgroundColor: Theme.of(context).cardColor,
                    labelStyle: TextStyle(
                      color: _selectedDept == 'ALL'
                          ? primary
                          : Colors.grey.shade700,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: const BorderSide(color: Colors.transparent),
                    ),
                  ),
                ),
                ...(KnueScraper.collegeStructure[_selectedCollege] ?? []).map((
                  dept,
                ) {
                  final selected = _selectedDept == dept;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildBoardChip(
                      dept,
                      selected,
                      primary,
                      onSelected: () => setState(() {
                        _selectedDept = dept;
                        _noticeDisplayLimit = 10;
                      }),
                    ),
                  );
                }),
              ],
            ),
          ),
        ],
      );
    } else {
      List<String> defaultBoards = [];
      if (_selectedGroup == 'MAIN')
        defaultBoards = scraper.boardGroups['MAIN']?.keys.toList() ?? [];
      else if (_selectedGroup == 'LIFE')
        defaultBoards = scraper.boardGroups['LIFE']?.keys.toList() ?? [];
      else if (_selectedGroup == 'ANNEX') {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 40,
              margin: const EdgeInsets.only(bottom: 8),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: KnueScraper.annexStructure.keys.map((annex) {
                  final selected = _selectedAnnexGroup == annex;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(annex),
                      selected: selected,
                      onSelected: (s) => setState(() {
                        _selectedAnnexGroup = annex;
                        _selectedBoard = 'ALL';
                        _noticeDisplayLimit = 10;
                      }),
                      selectedColor: primary.withOpacity(0.2),
                      backgroundColor: Theme.of(context).cardColor,
                      labelStyle: TextStyle(
                        color: selected ? primary : Colors.grey.shade700,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide.none,
                      ),
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
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _buildBoardChip(
                      'ALL',
                      _selectedBoard == 'ALL',
                      primary,
                      onSelected: () => setState(() {
                        _selectedBoard = 'ALL';
                        _noticeDisplayLimit = 10;
                      }),
                    ),
                  ),
                  ...(KnueScraper.annexStructure[_selectedAnnexGroup] ?? [])
                      .map((board) {
                        final selected = _selectedBoard == board;
                        final displayName = board.contains('_')
                            ? board.split('_')[1]
                            : board;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _buildBoardChip(
                            board,
                            selected,
                            primary,
                            label: displayName,
                            onSelected: () => setState(() {
                              _selectedBoard = board;
                              _noticeDisplayLimit = 10;
                            }),
                          ),
                        );
                      }),
                ],
              ),
            ),
          ],
        );
      } else if (_selectedGroup == 'GRAD')
        defaultBoards = scraper.boardGroups['GRAD']?.keys.toList() ?? [];

      if (defaultBoards.isEmpty) return const SizedBox(height: 12);

      ref.watch(boardOrderProvider); // 게시판 순서 변경 시 리빌드
      final currentOrder = ref
          .read(boardOrderProvider.notifier)
          .getOrder(_selectedGroup, defaultBoards);

      return Container(
        height: 50,
        margin: const EdgeInsets.only(bottom: 12),
        child: ReorderableListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          proxyDecorator: (child, index, animation) {
            return Material(
              color: Colors.transparent,
              child: Transform.scale(
                scale: 1.05,
                child: Container(
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: child,
                ),
              ),
            );
          },
          onReorder: (oldIndex, newIndex) {
            if (oldIndex == 0) return; // Cannot reorder 'ALL'
            if (newIndex == 0) newIndex = 1; // Cannot place before 'ALL'
            final actualOld = oldIndex - 1;
            final actualNew = newIndex - 1;
            ref
                .read(boardOrderProvider.notifier)
                .reorder(_selectedGroup, actualOld, actualNew, currentOrder);
            setState(() {});
          },
          children: [
            Padding(
              key: const ValueKey('ALL'),
              padding: const EdgeInsets.only(right: 8),
              child: _buildBoardChip('ALL', _selectedBoard == 'ALL', primary),
            ),
            ...currentOrder.asMap().entries.map((entry) {
              final idx = entry.key;
              final board = entry.value;
              final selected = _selectedBoard == board;
              return ReorderableDelayedDragStartListener(
                key: ValueKey(board),
                index: idx + 1,
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _buildBoardChip(
                    board,
                    selected,
                    primary,
                    showDragHint: true,
                  ),
                ),
              );
            }),
          ],
        ),
      );
    }
  }

  Widget _buildBoardChip(
    String boardName,
    bool selected,
    Color primary, {
    String? label,
    bool isRemovable = false,
    bool showDragHint = false,
    VoidCallback? onSelected,
  }) {
    final isFav = ref.watch(
      boardFavoritesProvider.select((list) => list.contains(boardName)),
    );
    final isAll = boardName == 'ALL' || boardName == '전체';
    final displayText = label ?? (isAll ? '전체보기' : boardName);

    return GestureDetector(
      onTap: () {
        if (onSelected != null) {
          onSelected();
        } else {
          setState(() {
            _selectedBoard = boardName;
            _noticeDisplayLimit = 10;
          });
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? primary.withOpacity(0.1)
              : Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: selected ? primary : Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (!isAll && !isRemovable)
              GestureDetector(
                onTap: () {
                  ref.read(boardFavoritesProvider.notifier).toggle(boardName);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isFav ? '$displayText 즐겨찾기 해제' : '$displayText 즐겨찾기 추가',
                      ),
                      duration: const Duration(milliseconds: 1000),
                    ),
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    isFav ? Icons.star : LucideIcons.star,
                    size: 16,
                    color: isFav ? primary : Colors.grey.shade400,
                  ),
                ),
              ),
            Text(
              displayText,
              style: TextStyle(
                color: selected ? primary : Colors.grey.shade700,
                fontWeight: selected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
            if (showDragHint) ...[
              const SizedBox(width: 6),
              Icon(
                LucideIcons.gripVertical,
                size: 14,
                color: Colors.grey.shade400,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeListSliver(Map<String, dynamic> theme) {
    final primary = theme['primary'] as Color;
    final noticesAsync = ref.watch(noticesProvider);
    final favorites = ref.watch(favoritesNotifierProvider);
    final favBoards = ref.watch(boardFavoritesProvider);

    return noticesAsync.when(
      data: (notices) {
        if (notices.isEmpty) {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(
                      LucideIcons.inbox,
                      size: 48,
                      color: Colors.grey.shade400,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      '공지사항이 없습니다.\n(새로고침을 당겨주세요)',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        // 초등교육과 버튼 처리
        if (_selectedGroup == 'DEPT' && _selectedDept == '초등교육과') {
          return SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: Column(
                  children: [
                    Icon(LucideIcons.messageCircle, size: 64, color: primary),
                    const SizedBox(height: 24),
                    const Text(
                      '초등교육과 공지사항은\n다음 카페에서 확인 가능합니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: () async {
                        const url = 'https://m.cafe.daum.net/knue-primary/_rec';
                        launchUrl(
                          Uri.parse(url),
                          mode: LaunchMode.externalApplication,
                        );
                      },
                      icon: const Icon(
                        LucideIcons.externalLink,
                        color: Colors.white,
                      ),
                      label: const Text(
                        '초등교육과 카페 바로가기',
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(backgroundColor: primary),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final filtered = notices.where((n) {
          if (_selectedGroup == 'MY') {
            return favorites.contains(n.id) || favBoards.contains(n.category);
          }
          if (_selectedGroup == 'DEPT') {
            final targetDepts =
                KnueScraper.collegeStructure[_selectedCollege] ?? [];
            if (!targetDepts.contains(n.category)) return false;
            return _selectedDept == 'ALL' || n.category == _selectedDept;
          } else if (_selectedGroup == 'ANNEX') {
            if (n.group != 'ANNEX') return false;
            final targetBoards =
                KnueScraper.annexStructure[_selectedAnnexGroup] ?? [];
            if (!targetBoards.contains(n.category)) return false;
            return _selectedBoard == 'ALL' || n.category == _selectedBoard;
          } else {
            if (n.group != _selectedGroup) return false;
            return _selectedBoard == 'ALL' || n.category == _selectedBoard;
          }
        }).toList();

        if (filtered.isEmpty) {
          return const SliverToBoxAdapter(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text(
                  '해당하는 게시글이 없습니다.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),
          );
        }

        final displayList = filtered.take(_noticeDisplayLimit).toList();
        final hasMore = filtered.length > displayList.length;

        // SliverList 내부에 공지사항 카드들과 '더보기' 버튼을 모두 포함시킴
        return SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate((context, i) {
              if (i < displayList.length) {
                final notice = displayList[i];
                return NoticeCard(notice: notice, themeData: theme);
              } else {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: TextButton.icon(
                      onPressed: () =>
                          setState(() => _noticeDisplayLimit += 10),
                      icon: const Icon(LucideIcons.plus),
                      label: const Text('더보기'),
                      style: TextButton.styleFrom(
                        foregroundColor: primary,
                        backgroundColor: primary.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                );
              }
            }, childCount: displayList.length + (hasMore ? 1 : 0)),
          ),
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(40),
            child: CircularProgressIndicator(),
          ),
        ),
      ),
      error: (e, s) => SliverToBoxAdapter(child: Center(child: Text('오류: $e'))),
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
            if (await canLaunchUrl(uri))
              await launchUrl(uri, mode: LaunchMode.externalApplication);
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
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    LucideIcons.sparkles,
                    color: Colors.yellowAccent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI 추천 공지 ✨',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '[${notice.category}] ${notice.title}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const Icon(
                  LucideIcons.chevronRight,
                  color: Colors.white54,
                  size: 20,
                ),
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
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final primary = ref.watch(themeColorProvider);
    final themeData = {'primary': primary};

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Search Header
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    offset: const Offset(0, 4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '무엇을 찾으시나요?',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Hero(
                    tag: 'search_bar',
                    child: Material(
                      color: Colors.transparent,
                      child: TextField(
                        controller: _controller,
                        onChanged: (v) => setState(() => _searchQuery = v),
                        autofocus: false,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          hintText: '장학금, 봉사활동 등 검색',
                          hintStyle: TextStyle(color: Colors.grey.shade400),
                          prefixIcon: Icon(LucideIcons.search, color: primary),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(
                                    LucideIcons.xCircle,
                                    color: Colors.grey,
                                  ),
                                  onPressed: () {
                                    _controller.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Theme.of(context).cardColor,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 16,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Body Content
            Expanded(
              child: _searchQuery.isEmpty
                  ? _buildCategorySelection(primary)
                  : _buildSearchResults(themeData),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategorySelection(Color primary) {
    final scraper = KnueScraper();
    final sections = [
      {
        'title': '빠른 필터',
        'icon': LucideIcons.flame,
        'boards': ['전체', '학사공지', '장학금', '취업정보'],
      },
      {
        'title': '본부 공지',
        'icon': LucideIcons.building2,
        'boards': scraper.boardGroups['MAIN']?.keys.toList() ?? [],
      },
      {
        'title': '부속 기관',
        'icon': LucideIcons.library,
        'boards': scraper.boardGroups['ANNEX']?.keys.toList() ?? [],
      },
      {
        'title': '대학원',
        'icon': LucideIcons.school,
        'boards': scraper.boardGroups['GRAD']?.keys.toList() ?? [],
      },
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: sections.length,
      itemBuilder: (ctx, index) {
        final section = sections[index];
        final title = section['title'] as String;
        final icon = section['icon'] as IconData;
        final boards = section['boards'] as List<String>;

        if (boards.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: Colors.grey.shade600),
                  const SizedBox(width: 8),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: boards.map((board) {
                  final selected = _searchScope == board;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: ChoiceChip(
                      label: Text(board),
                      selected: selected,
                      onSelected: (s) => setState(() => _searchScope = board),
                      selectedColor: primary.withOpacity(0.15),
                      backgroundColor: Theme.of(context).cardColor,
                      labelStyle: TextStyle(
                        color: selected ? primary : Colors.grey.shade600,
                        fontWeight: selected
                            ? FontWeight.bold
                            : FontWeight.normal,
                        fontSize: 14,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: selected
                              ? primary.withOpacity(0.5)
                              : Colors.transparent,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchResults(Map<String, dynamic> theme) {
    final noticesAsync = ref.watch(noticesProvider);
    final notices = noticesAsync.valueOrNull ?? [];
    final primary = theme['primary'] as Color;

    final results = notices.where((n) {
      final cleanTitle = n.title
          .replaceAll('새글', '')
          .replaceAll('[새글]', '')
          .trim();
      final matchesQuery = cleanTitle.toLowerCase().contains(
        _searchQuery.toLowerCase(),
      );
      final matchesScope = _searchScope == '전체' || n.category == _searchScope;
      return matchesQuery && matchesScope;
    }).toList();

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          alignment: Alignment.centerLeft,
          child: Row(
            children: [
              Text(
                '$_searchScope ',
                style: TextStyle(fontWeight: FontWeight.bold, color: primary),
              ),
              const Text('검색 결과', style: TextStyle(color: Colors.grey)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${results.length}건',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primary,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: results.isEmpty
              ? _buildEmptyState(primary)
              : AnimationLimiter(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: results.length,
                    itemBuilder: (ctx, i) =>
                        AnimationConfiguration.staggeredList(
                          position: i,
                          duration: const Duration(milliseconds: 375),
                          child: SlideAnimation(
                            verticalOffset: 50.0,
                            child: FadeInAnimation(
                              child: GestureDetector(
                                onTap: () => ref
                                    .read(clickHistoryProvider.notifier)
                                    .logClick(results[i].title),
                                child: NoticeCard(
                                  notice: results[i],
                                  themeData: theme,
                                ),
                              ),
                            ),
                          ),
                        ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(Color primary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(LucideIcons.searchX, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            '"$_searchQuery"',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '해당하는 공지사항이 없습니다.\n다른 키워드로 검색해보세요.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
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
                  const Text(
                    '설정',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 30),

                  _buildSectionTitle('나의 데이터'),
                  _buildSettingsCard(
                    context,
                    children: [
                      _buildInfoTile(
                        icon: LucideIcons.fileText,
                        title: '나의 지원서 관리',
                        subtitle: '교내 프로그램 지원 정보 저장',
                        color: Colors.green,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  const ApplicationManagePage(),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  _buildSectionTitle('앱 테마'),
                  _buildSettingsCard(
                    context,
                    children: [
                      _buildThemeModeSelector(ref, context),
                      _buildDivider(context),
                      _buildColorPalette(ref),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('알림'),
                  _buildSettingsCard(
                    context,
                    children: [
                      _buildSwitchTile(
                        icon: LucideIcons.bell,
                        title: '키워드 알림',
                        subtitle: '등록한 키워드 포함 시 알림',
                        value: ref.watch(alarmProvider),
                        onChanged: (v) =>
                            ref.read(alarmProvider.notifier).setAlarm(v),
                        color: Colors.orange,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('위젯 설정'),
                  _buildSettingsCard(
                    context,
                    children: [
                      _buildInfoTile(
                        icon: LucideIcons.layoutGrid,
                        title: '홈 화면 위젯 설정',
                        subtitle: '위젯에 표시될 게시판 선택 및 미리보기',
                        color: Colors.blueAccent,
                        onTap: () => _showWidgetSettings(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSectionTitle('앱 정보'),
                  _buildSettingsCard(
                    context,
                    children: [
                      _buildInfoTile(
                        icon: LucideIcons.info,
                        title: '버전 정보',
                        trailing: 'v1.3.1',
                        color: Colors.blue,
                        onTap: () {},
                      ),
                      _buildDivider(context),
                      _buildInfoTile(
                        icon: LucideIcons.user,
                        title: '개발자 정보',
                        subtitle: 'knuemeal16486@gmail.com',
                        color: Colors.purple,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const DeveloperInfoPage(),
                            ),
                          );
                        },
                      ),
                      _buildDivider(context),
                      _buildInfoTile(
                        icon: LucideIcons.send,
                        title: '사용자 의견 보내기',
                        subtitle: '오류 제보 및 기능 제안',
                        color: Colors.green,
                        onTap: () => _sendFeedback(context),
                      ),
                      _buildDivider(context),
                      _buildInfoTile(
                        icon: LucideIcons.refreshCcw,
                        title: '설정 초기화',
                        subtitle: '모든 데이터 및 설정 초기화',
                        color: Colors.redAccent,
                        onTap: () => _showResetDialog(context),
                      ),
                      _buildDivider(context),
                      _buildInfoTile(
                        icon: LucideIcons.github,
                        title: '오픈소스 라이선스',
                        color: Colors.grey,
                        onTap: () => showLicensePage(
                          context: context,
                          applicationName: 'KNUE MoA',
                          applicationVersion: '1.3.1',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  Center(
                    child: Text(
                      "© 2026 KNUE MoA",
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
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
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _buildSettingsCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
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

  Widget _buildDivider(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: Theme.of(context).dividerColor,
    );
  }

  Widget _buildThemeModeSelector(WidgetRef ref, BuildContext context) {
    final currentMode = ref.watch(themeModeProvider);
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Row(
        children: [
          _buildThemeModeItem(
            ref,
            context,
            '라이트',
            LucideIcons.sun,
            ThemeMode.light,
            currentMode,
          ),
          _buildThemeModeItem(
            ref,
            context,
            '다크',
            LucideIcons.moon,
            ThemeMode.dark,
            currentMode,
          ),
          _buildThemeModeItem(
            ref,
            context,
            '시스템',
            LucideIcons.smartphone,
            ThemeMode.system,
            currentMode,
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeItem(
    WidgetRef ref,
    BuildContext context,
    String label,
    IconData icon,
    ThemeMode mode,
    ThemeMode current,
  ) {
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

  Widget _buildColorPalette(WidgetRef ref) {
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
                onTap: () =>
                    ref.read(themeColorProvider.notifier).setColor(color),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 2)
                        : null,
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              Text(
                trailing,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade400,
                ),
              )
            else
              Icon(
                LucideIcons.chevronRight,
                size: 18,
                color: Colors.grey.shade300,
              ),
          ],
        ),
      ),
    );
  }

  void _showWidgetSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const WidgetSettingsSheet(),
    );
  }

  void _sendFeedback(BuildContext context) {
    showDialog(context: context, builder: (context) => const FeedbackDialog());
  }

  void _showResetDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('설정 초기화'),
        content: const Text('모든 공지사항 스크랩 데이터와 설정이 삭제됩니다. 계속하시겠습니까?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              await resetAllSettings();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('설정이 초기화되었습니다. 앱을 재발생해주세요.')),
                );
              }
            },
            child: const Text('초기화', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class WidgetSettingsSheet extends ConsumerWidget {
  const WidgetSettingsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedBoards = ref.watch(widgetBoardsProvider);
    final primary = Theme.of(context).primaryColor;
    final scraper = KnueScraper();

    // 모든 게시판 목록 가져오기
    final List<String> allBoards = [];
    scraper.boardGroups.forEach((group, boards) {
      allBoards.addAll(boards.keys);
    });

    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '홈 위젯 설정',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '위젯에 표시될 게시판을 선택하세요.',
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 20),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primary.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.layoutGrid, size: 16, color: primary),
                    const SizedBox(width: 8),
                    const Text(
                      '위젯 미리보기',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (selectedBoards.isEmpty)
                  const Text(
                    '선택된 게시판이 없습니다.',
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  )
                else
                  Wrap(
                    spacing: 8,
                    children: selectedBoards
                        .map(
                          (b) => Chip(
                            label: Text(
                              b,
                              style: const TextStyle(fontSize: 10),
                            ),
                            backgroundColor: primary.withOpacity(0.1),
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: allBoards.toSet().map((board) {
                final isSelected = selectedBoards.contains(board);
                return CheckboxListTile(
                  title: Text(board, style: const TextStyle(fontSize: 15)),
                  value: isSelected,
                  activeColor: primary,
                  onChanged: (v) =>
                      ref.read(widgetBoardsProvider.notifier).toggle(board),
                );
              }).toList(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: primary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                '저장 완료',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FeedbackDialog extends StatefulWidget {
  const FeedbackDialog({super.key});

  @override
  State<FeedbackDialog> createState() => _FeedbackDialogState();
}

class _FeedbackDialogState extends State<FeedbackDialog> {
  final TextEditingController _feedbackController = TextEditingController();
  bool _isAgreed = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map(
          (e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}',
        )
        .join('&');
  }

  Future<void> _sendFeedback() async {
    if (_feedbackController.text.isEmpty || !_isAgreed) return;

    const String developerEmail = 'knuemeal16486@gmail.com';
    const String subject = '[KNUE MoA] 사용자 의견 및 제보';
    final String body = _feedbackController.text;

    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: developerEmail,
      query: _encodeQueryParameters(<String, String>{
        'subject': subject,
        'body': '내용:\n$body\n\n----------------------------\n(  )',
      }),
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(emailUri, mode: LaunchMode.externalApplication);
        if (mounted) Navigator.pop(context);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("기본 이메일 앱을 실행할 수 없습니다.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("오류가 발생했습니다: $e")));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isButtonEnabled =
        _feedbackController.text.isNotEmpty && _isAgreed;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "사용자 의견 보내기",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.grey),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                "KNUE MoA를 더 나은 앱으로 만들기 위해\n여러분의 소중한 의견을 들려주세요.",
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: isDark ? Colors.grey.shade300 : Colors.black87,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? Colors.grey.shade700 : Colors.grey.shade300,
                  ),
                ),
                child: TextField(
                  controller: _feedbackController,
                  maxLines: 6,
                  onChanged: (text) => setState(() {}),
                  style: TextStyle(color: isDark ? Colors.white : Colors.black),
                  decoration: InputDecoration(
                    hintText: "불편했던 점, 개선할 점, 칭찬하고 싶은 점 등을 자유롭게 적어주세요.",
                    hintStyle: TextStyle(
                      color: isDark
                          ? Colors.grey.shade500
                          : Colors.grey.shade500,
                      fontSize: 14,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                onTap: () => setState(() => _isAgreed = !_isAgreed),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      height: 24,
                      child: Checkbox(
                        value: _isAgreed,
                        activeColor: primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        onChanged: (value) =>
                            setState(() => _isAgreed = value ?? false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: "개인정보 수집 및 이용에 동의합니다. ",
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark
                                ? Colors.grey.shade400
                                : Colors.black87,
                          ),
                          children: [
                            TextSpan(
                              text: "(필수)",
                              style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: isButtonEnabled ? _sendFeedback : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    disabledBackgroundColor: isDark
                        ? Colors.grey.shade800
                        : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    disabledForegroundColor: Colors.grey.shade500,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    "이메일로 보내기",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
