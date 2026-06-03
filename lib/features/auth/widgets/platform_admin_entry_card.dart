// lib/features/auth/widgets/platform_admin_entry_card.dart
// 🔐 平台後台入口卡片
// 功能：Root Admin UID 永遠可進平台後台

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/platform/pages/platform_admin_page.dart';

class PlatformAdminEntryCard extends StatelessWidget {
  const PlatformAdminEntryCard({super.key, required this.uid});

  final String? uid;

  static const Set<String> rootAdminUids = {
    'LTk2AdDOAIVGhlkt97fnbD5TXIf1', // aac5881500@gmail.com
    '7FNrECQeqAca9Vu8lBBzTSdcJcg1', // zliu5036@gmail.com
  };

  @override
  Widget build(BuildContext context) {
    final isRootAdmin = uid != null && rootAdminUids.contains(uid);

    if (!isRootAdmin) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        const SizedBox(height: 12),
        Card(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.grey.shade200),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFFEAF3FF),
              child: Icon(Icons.admin_panel_settings, color: Color(0xFF1565C0)),
            ),
            title: const Text(
              '平台後台',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            subtitle: const Text('管理店家、方案、付款期限與平台紀錄'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PlatformAdminPage()),
              );
            },
          ),
        ),
      ],
    );
  }
}
