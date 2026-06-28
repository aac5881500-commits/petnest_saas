// lib/features/shop/pages/shop_report_page.dart
// 📊 營運報表中心
// 功能：統計報表入口頁（第一版）

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/pages/shop_daily_report_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_revenue_report_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_room_type_report_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_addon_report_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_member_report_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_export_report_page.dart';

class ShopReportPage extends StatelessWidget {
  const ShopReportPage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('營運報表中心')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReportCard(
            title: '日期統計報表',
            subtitle: '每日訂單、取消、營收統計',
            icon: Icons.calendar_month,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopDailyReportPage(shopId: shopId),
                ),
              );
            },
          ),

          _ReportCard(
            title: '營收統計報表',
            subtitle: '月營收、客單價、成長率分析',
            icon: Icons.attach_money,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopRevenueReportPage(shopId: shopId),
                ),
              );
            },
          ),

          _ReportCard(
            title: '房型統計報表',
            subtitle: '房型銷售排行與營收',
            icon: Icons.home_work,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopRoomTypeReportPage(shopId: shopId),
                ),
              );
            },
          ),

          _ReportCard(
            title: '加購服務統計',
            subtitle: '加購服務銷售次數與營收',
            icon: Icons.add_box,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopAddonReportPage(shopId: shopId),
                ),
              );
            },
          ),

          _ReportCard(
            title: '會員統計報表',
            subtitle: '會員數、新會員、回訪率',
            icon: Icons.people,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopMemberReportPage(shopId: shopId),
                ),
              );
            },
          ),

          _ReportCard(
            title: 'Excel 匯出',
            subtitle: '下載完整營運統計資料',
            icon: Icons.download,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopExportReportPage(shopId: shopId),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends StatelessWidget {
  const _ReportCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: onTap == null
            ? const Chip(label: Text('此功能將於後續版本提供'))
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
