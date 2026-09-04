// lib/features/auth/widgets/platform_section_title.dart
// 🧩 平台首頁區塊標題
// 功能：顯示首頁各區塊標題

import 'package:flutter/material.dart';

class PlatformSectionTitle extends StatelessWidget {
  const PlatformSectionTitle({super.key, required this.title, this.trailing});

  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
        ),

        if (trailing != null) trailing!,
      ],
    );
  }
}
