// lib/features/shop/pages/shop_report_page.dart
// 📊 營運報表中心
// 功能：統計報表入口頁（第一版）

import 'package:flutter/material.dart';

class ShopReportPage extends StatelessWidget {
  const ShopReportPage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('營運報表中心')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _ReportCard(
            title: '日期統計報表',
            subtitle: '每日訂單、入住、退房、營收統計',
            icon: Icons.calendar_month,
          ),

          _ReportCard(
            title: '營收統計報表',
            subtitle: '月營收、客單價、成長率分析',
            icon: Icons.attach_money,
          ),

          _ReportCard(
            title: '房型統計報表',
            subtitle: '房型銷售排行與住房率',
            icon: Icons.home_work,
          ),

          _ReportCard(
            title: '加購服務統計',
            subtitle: '加購服務銷售次數與營收',
            icon: Icons.add_box,
          ),

          _ReportCard(
            title: '會員統計報表',
            subtitle: '會員數、新會員、回訪率',
            icon: Icons.people,
          ),

          _ReportCard(
            title: 'Excel 匯出',
            subtitle: '下載完整營運統計資料',
            icon: Icons.download,
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
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Chip(label: Text('開發中')),
      ),
    );
  }
}
