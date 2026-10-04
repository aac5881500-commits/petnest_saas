// 檔案名稱：lib/features/auth/widgets/my_shop_stat_row.dart
// 功能說明：今天店裡要留意的數字。沿用既有統計，不另算會員以外的待辦。
// 📊 我的店家統計列

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_home_stats_service.dart';

/// 待確認與已轉帳回傳加總。會員數不算待處理。
String shopTodayHeadline(int pending, int transfers) {
  final int tasks = pending + transfers;
  if (tasks <= 0) {
    return '今天店裡一切順利';
  }
  return '今天店裡有 $tasks 件事情等你處理';
}

String shopTodaySubline(int pending, int transfers) {
  if (pending + transfers <= 0) {
    return '可以安心開始今天的工作。';
  }
  return '看看有哪些事情需要留意。';
}

class MyShopStatRow extends StatelessWidget {
  const MyShopStatRow({super.key, required this.shopId, this.statsFuture});

  final String shopId;
  final Future<Map<String, int>>? statsFuture;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future:
          statsFuture ?? ShopHomeStatsService.instance.getShopHomeStats(shopId),
      builder:
          (BuildContext context, AsyncSnapshot<Map<String, int>> snapshot) {
            final bool waiting =
                snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData;
            final Map<String, int> stats =
                snapshot.data ??
                <String, int>{
                  'pendingOrders': 0,
                  'transferUploadedOrders': 0,
                  'memberCount': 0,
                };
            if (snapshot.hasError) {
              return Text(
                '店務數字暫時無法讀取',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              );
            }
            final bool dark = Theme.of(context).brightness == Brightness.dark;
            Color wash(Color light) =>
                dark ? light.withValues(alpha: 0.18) : light;
            return Row(
              children: <Widget>[
                Expanded(
                  child: _BoardCell(
                    label: '待確認',
                    value: stats['pendingOrders'] ?? 0,
                    loading: waiting,
                    accent: (stats['pendingOrders'] ?? 0) > 0,
                    wash: wash(const Color(0xFFFFF1EA)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _BoardCell(
                    label: '轉帳回傳',
                    value: stats['transferUploadedOrders'] ?? 0,
                    loading: waiting,
                    accent: (stats['transferUploadedOrders'] ?? 0) > 0,
                    wash: wash(const Color(0xFFF2F6FB)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _BoardCell(
                    label: '店內會員',
                    value: stats['memberCount'] ?? 0,
                    loading: waiting,
                    wash: wash(const Color(0xFFF1F7F1)),
                  ),
                ),
              ],
            );
          },
    );
  }
}

class _BoardCell extends StatelessWidget {
  const _BoardCell({
    required this.label,
    required this.value,
    required this.loading,
    required this.wash,
    this.accent = false,
  });

  final String label;
  final int value;
  final bool loading;
  final Color wash;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;
    final Color number = accent ? const Color(0xFFC47A3A) : colors.onSurface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: wash,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Column(
          children: <Widget>[
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: text.labelSmall?.copyWith(color: colors.onSurfaceVariant),
            ),
            const SizedBox(height: 2),
            loading
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: number,
                    ),
                  )
                : Text(
                    '$value',
                    style: text.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                      color: number,
                    ),
                  ),
          ],
        ),
      ),
    );
  }
}
