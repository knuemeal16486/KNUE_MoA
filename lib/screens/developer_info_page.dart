import 'package:flutter/material.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'dart:io';

class DeveloperInfoPage extends StatelessWidget {
  const DeveloperInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: primary,
        centerTitle: Platform.isIOS ? false : null,
        title: Text(
          "개발자 정보",
          style: TextStyle(
            fontWeight: Platform.isIOS ? FontWeight.w800 : FontWeight.bold,
            color: Colors.white,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 40),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: primary.withOpacity(0.1),
                border: Border.all(color: primary, width: 3),
              ),
              child: Icon(LucideIcons.user, size: 60, color: primary),
            ),
            const SizedBox(height: 20),
            const Text(
              "Hwang",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "KNUE Physics & Elementary Education 23",
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
            const SizedBox(height: 30),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      context: context,
                      icon: LucideIcons.school,
                      label: "소속",
                      content: "한국교원대학교 물리교육과",
                      color: Colors.blue,
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      context: context,
                      icon: LucideIcons.code,
                      label: "관심 분야",
                      content: "Physical Computing, Embedded System, AI",
                      color: Colors.orange,
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      context: context,
                      icon: LucideIcons.mail,
                      label: "이메일",
                      content: "knuemeal16486@gmail.com",
                      color: Colors.green,
                    ),
                    const Divider(height: 24),
                    _buildInfoRow(
                      context: context,
                      icon: LucideIcons.coffee,
                      label: "후원",
                      content: "고생한 개발자를 위해 커피 사주기\n신한 110-334-965296",
                      color: Colors.pink,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 20,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: _buildInfoRow(
                  context: context,
                  icon: LucideIcons.award,
                  label: "Special Help",
                  content: "Hyunsu, Oh\nSNU Nuclear Engineering",
                  color: Colors.deepPurple,
                ),
              ),
            ),
            const SizedBox(height: 40),
            Text(
              "© 2026 KNUE MoA",
              style: TextStyle(color: isDark ? Colors.grey : Colors.black54),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required BuildContext context,
    required IconData icon,
    required String label,
    required String content,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
