import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knue_moa/models/notice_model.dart';
import 'package:knue_moa/providers/providers.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class NoticeCard extends ConsumerWidget {
  final Notice notice;
  final Map<String, dynamic>? themeData;

  const NoticeCard({super.key, required this.notice, this.themeData});

  Color _getCategoryColor(String category) {
    final hash = category.hashCode.abs();
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.6, 0.6).toColor();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keywords = ref.watch(keywordsProvider).value ?? [];
    
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
    
    // [Red Dot] 새 글이고, 아직 읽지 않았을 때 표시
    final showRedDot = notice.isNew && !isRead;

    final primaryColor = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        // [클릭 시 읽음 처리]
        ref.read(readNoticesProvider.notifier).markAsRead(notice.id);
        _launchUrl(notice.link);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(16),
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
              Container(width: 6, color: _getCategoryColor(notice.category)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
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
                          const SizedBox(width: 8),
                          // [노란색 딱지] 나의 키워드
                          if (isMatched)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF9C4), 
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFFBC02D), width: 1),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.star, size: 10, color: Color(0xFFF57F17)),
                                  SizedBox(width: 4),
                                  Text("나의 키워드", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFFF57F17))),
                                ],
                              ),
                            ),
                          const Spacer(),
                          // [Red Dot] 우측 상단 표시
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
                        cleanTitle,
                        style: TextStyle(
                          fontSize: 15,
                          // 읽지 않은 글은 굵게, 읽은 글은 회색으로
                          fontWeight: !isRead ? FontWeight.w600 : FontWeight.normal,
                          color: isRead ? Colors.grey : (isDark ? Colors.white : const Color(0xFF1E293B)),
                          height: 1.3,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(notice.date, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                              const SizedBox(width: 8),
                              Container(width: 1, height: 10, color: Colors.grey.shade300),
                              const SizedBox(width: 8),
                              Text(notice.author, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                            ],
                          ),
                          GestureDetector(
                            onTap: () => ref.read(favoritesNotifierProvider.notifier).toggle(notice.id),
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