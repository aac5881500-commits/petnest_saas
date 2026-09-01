// lib/features/shop/pages/shop_report_page.dart
// 📊 營運報表中心

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/shop/pages/shop_addon_report_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_daily_report_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_export_report_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_member_report_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_overview_report_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_revenue_report_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_room_type_report_page.dart';
import 'package:petnest_saas/features/shop/widgets/shop_report_widgets.dart';

class ShopReportPage extends StatelessWidget {
  const ShopReportPage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('營運報表中心'),
        actions: <Widget>[ShopTaskCenterButton(shopId: shopId)],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const ReportSectionLabel('營運概況'),
          _ReportCard(
            title: '營運總覽',
            subtitle: '本月訂單、營收、熱門房型與加購',
            icon: Icons.dashboard_outlined,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ShopOverviewReportPage(shopId: shopId),
                ),
              );
            },
          ),
          const ReportSectionLabel('住宿'),
          _ReportCard(
            title: '日期統計',
            subtitle: '每天訂單、入住退房與住宿晚數',
            icon: Icons.calendar_month,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ShopDailyReportPage(shopId: shopId),
                ),
              );
            },
          ),
          _ReportCard(
            title: '營收統計',
            subtitle: '住宿、加購、商城與實際已付款',
            icon: Icons.attach_money,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ShopRevenueReportPage(shopId: shopId),
                ),
              );
            },
          ),
          _ReportCard(
            title: '房型統計',
            subtitle: '各房型訂單、晚數與房費收入',
            icon: Icons.home_work,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ShopRoomTypeReportPage(shopId: shopId),
                ),
              );
            },
          ),
          _ReportCard(
            title: '加購統計',
            subtitle: '時間、客製、每日分時段等加購',
            icon: Icons.add_box,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ShopAddonReportPage(shopId: shopId),
                ),
              );
            },
          ),
          const ReportSectionLabel('會員'),
          _ReportCard(
            title: '會員統計',
            subtitle: '新增、消費、回訪與 VIP',
            icon: Icons.people,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ShopMemberReportPage(shopId: shopId),
                ),
              );
            },
          ),
          const ReportSectionLabel('資料'),
          _ReportCard(
            title: 'Excel 匯出',
            subtitle: '依目前日期範圍下載報表',
            icon: Icons.download,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
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
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
