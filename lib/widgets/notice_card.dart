import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:knue_moa/constants/theme_constants.dart';
import 'package:knue_moa/models/notice_model.dart';
import 'package:knue_moa/providers/providers.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

class NoticeCard extends ConsumerWidget {
  final Notice notice;
  final Map<String, dynamic> themeData;

  const NoticeCard({super.key, required this.notice, required this.themeData});

  // 카테고리별 색상 생성 (해시 기반으로 고유한 색상 부여)
  Color _getCategoryBackground(String category) {
    final hash = category.hashCode.abs();
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(0.15, hue, 0.7, 0.9).toColor();
  }

  Color _getCategoryText(String category) {
    final hash = category.hashCode.abs();
    final hue = (hash % 360).toDouble();
    return HSLColor.fromAHSL(1.0, hue, 0.8, 0.3).toColor();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keywords = ref.watch(keywordsProvider).value ?? [];
    final isMatched = keywords.any((k) => notice.title.contains(k));
    final isFav = ref.watch(favoritesNotifierProvider).contains(notice.id);

    return GestureDetector(
      onTap: () => _launchUrl(notice.link),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isMatched ? themeData['primary'] : Colors.grey.shade100,
            width: isMatched ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // 카테고리 (고유 색상 적용)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getCategoryBackground(notice.category),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    notice.category,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: _getCategoryText(notice.category),
                    ),
                  ),
                ),
                // NEW 표시: 빨간 점 (아이폰 스타일)
                if (notice.isNew)
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              notice.title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: isMatched ? themeData['primary'] : const Color(0xFF1E293B),
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(LucideIcons.calendar, size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      notice.date,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    const SizedBox(width: 12),
                    Icon(LucideIcons.user, size: 12, color: Colors.grey.shade400),
                    const SizedBox(width: 4),
                    Text(
                      notice.author,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],
                ),
                IconButton(
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    isFav ? LucideIcons.star : LucideIcons.star,
                    color: isFav ? Colors.amber : Colors.grey.shade300,
                    size: 20,
                  ),
                  onPressed: () {
                    ref.read(favoritesNotifierProvider.notifier).toggle(notice.id);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      throw 'Could not launch $url';
    }
  }
}