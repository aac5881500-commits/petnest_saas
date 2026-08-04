// lib/features/member/pages/member_point_detail_page.dart
// 🪙 會員店家點數詳細頁
// 功能：顯示會員在指定店家的點數餘額與累積統計

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/member_point_model.dart';
import 'package:petnest_saas/core/models/member_point_log_model.dart';
import 'package:petnest_saas/core/services/member_point_service.dart';
import 'package:petnest_saas/features/member/pages/point_exchange_page.dart';

class MemberPointDetailPage extends StatelessWidget {
  const MemberPointDetailPage({
    super.key,
    required this.shopId,
    required this.shopName,
  });

  final String shopId;
  final String shopName;

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

    return Scaffold(
      appBar: AppBar(title: Text(shopName.isEmpty ? '我的點數' : '$shopName點數')),
      body: userId.isEmpty
          ? const Center(child: Text('請先登入會員帳號'))
          : StreamBuilder<MemberPointModel>(
              stream: MemberPointService.instance.streamMemberPoint(
                shopId: shopId,
                userId: userId,
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting &&
                    !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '讀取點數失敗\n${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }

                final MemberPointModel point =
                    snapshot.data ??
                    MemberPointModel.empty(shopId: shopId, userId: userId);

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 28,
                        ),
                        child: Column(
                          children: [
                            Text(
                              '目前可使用點數',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${point.currentPoints}',
                              style: Theme.of(context).textTheme.displayMedium
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            const Text('點'),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute<void>(
                              builder: (_) => PointExchangePage(
                                shopId: shopId,
                                shopName: shopName,
                              ),
                            ),
                          );
                        },
                        icon: const Icon(Icons.card_giftcard_outlined),
                        label: const Text('前往點數商城'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _PointSummaryCard(
                            title: '累積獲得',
                            points: point.totalEarnedPoints,
                            icon: Icons.add_circle_outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _PointSummaryCard(
                            title: '已使用',
                            points: point.totalUsedPoints,
                            icon: Icons.remove_circle_outline,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _PointSummaryCard(
                      title: '已過期',
                      points: point.totalExpiredPoints,
                      icon: Icons.schedule_outlined,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '點數流水',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    StreamBuilder<List<MemberPointLogModel>>(
                      stream: MemberPointService.instance.streamMemberPointLogs(
                        shopId: shopId,
                        userId: userId,
                      ),
                      builder: (context, logSnapshot) {
                        if (logSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !logSnapshot.hasData) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: CircularProgressIndicator()),
                            ),
                          );
                        }

                        if (logSnapshot.hasError) {
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                '讀取點數流水失敗\n${logSnapshot.error}',
                                textAlign: TextAlign.center,
                              ),
                            ),
                          );
                        }

                        final List<MemberPointLogModel> logs =
                            logSnapshot.data ?? const <MemberPointLogModel>[];

                        if (logs.isEmpty) {
                          return const Card(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Center(child: Text('目前沒有點數紀錄')),
                            ),
                          );
                        }

                        return Card(
                          clipBehavior: Clip.antiAlias,
                          child: Column(
                            children: [
                              for (
                                int index = 0;
                                index < logs.length;
                                index++
                              ) ...[
                                _PointLogTile(log: logs[index]),
                                if (index != logs.length - 1)
                                  const Divider(height: 1),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _PointSummaryCard extends StatelessWidget {
  const _PointSummaryCard({
    required this.title,
    required this.points,
    required this.icon,
  });

  final String title;
  final int points;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title),
                  const SizedBox(height: 4),
                  Text(
                    '$points 點',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointLogTile extends StatelessWidget {
  const _PointLogTile({required this.log});

  final MemberPointLogModel log;

  @override
  Widget build(BuildContext context) {
    final bool isIncrease = log.points > 0;

    final String pointText = isIncrease
        ? '+${log.absolutePoints}'
        : '-${log.absolutePoints}';

    final DateTime createdAt = log.createdAt;

    final String dateText =
        '${createdAt.year}/${createdAt.month.toString().padLeft(2, '0')}/${createdAt.day.toString().padLeft(2, '0')} '
        '${createdAt.hour.toString().padLeft(2, '0')}:${createdAt.minute.toString().padLeft(2, '0')}';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: CircleAvatar(
        child: Icon(isIncrease ? Icons.add_rounded : Icons.remove_rounded),
      ),
      title: Text(
        log.reason.trim().isNotEmpty ? log.reason : log.type.label,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text('$dateText\n餘額 ${log.balanceAfter} 點'),
      isThreeLine: true,
      trailing: Text(
        '$pointText 點',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.bold,
          color: isIncrease ? Colors.green.shade700 : Colors.red.shade700,
        ),
      ),
    );
  }
}
