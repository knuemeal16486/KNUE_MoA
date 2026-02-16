import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knue_moa/models/notice_model.dart';
import 'package:knue_moa/providers/providers.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class NoticeCard extends ConsumerWidget {
  final Notice notice;
  final Map<String, dynamic>? themeData; // 호환성을 위해 유지

  const NoticeCard({super.key, required this.notice, this.themeData});

  Color _getCategoryColor(String category) {
    final hash = category.hashCode.abs();
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.6).toColor();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keywords = ref.watch(keywordsProvider).value ?? [];
    
    // [수정] 제목에서 '새글' 관련 텍스트 제거
    final cleanTitle = notice.title
        .replaceAll('새글', '')
        .replaceAll('[새글]', '')
        .replaceAll('(새글)', '')
        .trim();

    final isMatched = keywords.any((k) => cleanTitle.contains(k));
    final favorites = ref.watch(favoritesNotifierProvider);
    final isFav = favorites.contains(notice.id);
    
    final readList = ref.watch(readNoticesProvider);
    final isRead = readList.contains(notice.id);
    
    // [수정] 새 글이고 읽지 않았을 때만 Red Dot 표시
    final showRedDot = notice.isNew && !isRead;

    // 현재 테마 색상 가져오기
    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        ref.read(readNoticesProvider.notifier).markAsRead(notice.id);
        _launchUrl(notice.link);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isMatched ? primaryColor : Colors.transparent,
            width: isMatched ? 1.5 : 0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // [수정] 왼쪽 사이드 컬러 바
              Container(
                width: 6,
                color: _getCategoryColor(notice.category),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: _getCategoryColor(notice.category).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              notice.category,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: _getCategoryColor(notice.category),
                              ),
                            ),
                          ),
                          // [수정] Red Dot
                          if (showRedDot)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        cleanTitle, // 정제된 제목 사용
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: isMatched || !isRead ? FontWeight.w600 : FontWeight.normal,
                          color: isMatched 
                              ? primaryColor 
                              : (isDark ? Colors.white : const Color(0xFF1E293B)),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                notice.date,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                              const SizedBox(width: 8),
                              Container(width: 1, height: 10, color: Colors.grey.shade300),
                              const SizedBox(width: 8),
                              Text(
                                notice.author,
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                          GestureDetector(
                            onTap: () {
                              ref.read(favoritesNotifierProvider.notifier).toggle(notice.id);
                            },
                            child: Icon(
                              isFav ? LucideIcons.star : LucideIcons.star,
                              color: isFav ? Colors.amber : Colors.grey.shade300,
                              size: 20,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}