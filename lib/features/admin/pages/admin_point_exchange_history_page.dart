// lib/features/admin/pages/admin_point_exchange_history_page.dart
// 🎁 後台點數兌換紀錄頁
// 功能：顯示店家全部會員的點數商品兌換紀錄，
// 包含會員 UID、商品名稱、扣除點數、兌換後餘額與優惠券發放狀態。

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/models/member_point_log_model.dart';
import 'package:petnest_saas/core/services/member_point_service.dart';

class AdminPointExchangeHistoryPage extends StatelessWidget {
  const AdminPointExchangeHistoryPage({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return const Scaffold(body: Center(child: Text('找不到目前店家資料')));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(title: const Text('點數兌換紀錄')),
      body: StreamBuilder<List<MemberPointLogModel>>(
        stream: MemberPointService.instance.streamShopRewardExchangeLogs(
          shopId: normalizedShopId,
        ),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<MemberPointLogModel>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '讀取點數兌換紀錄失敗\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final List<MemberPointLogModel> logs =
                  snapshot.data ?? const <MemberPointLogModel>[];

              if (logs.isEmpty) {
                return const _EmptyExchangeHistoryView();
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: logs.length,
                separatorBuilder: (BuildContext context, int index) {
                  return const SizedBox(height: 12);
                },
                itemBuilder: (BuildContext context, int index) {
                  return _ExchangeHistoryCard(
                    shopId: normalizedShopId,
                    log: logs[index],
                  );
                },
              );
            },
      ),
    );
  }
}

class _ExchangeHistoryCard extends StatelessWidget {
  const _ExchangeHistoryCard({required this.shopId, required this.log});

  final String shopId;
  final MemberPointLogModel log;
  Future<String> _loadMemberName() async {
    final String normalizedShopId = shopId.trim();
    final String normalizedUserId = log.userId.trim();

    if (normalizedShopId.isEmpty || normalizedUserId.isEmpty) {
      return '未知會員';
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance
              .collection('shops')
              .doc(normalizedShopId)
              .collection('members')
              .doc(normalizedUserId)
              .get();

      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return '未知會員';
      }

      final String displayName = (data['displayName'] ?? '').toString().trim();

      if (displayName.isNotEmpty) {
        return displayName;
      }

      final String name = (data['name'] ?? '').toString().trim();

      if (name.isNotEmpty) {
        return name;
      }

      final String email = (data['email'] ?? '').toString().trim();

      if (email.isNotEmpty) {
        return email;
      }

      return '未命名會員';
    } catch (_) {
      return '會員資料讀取失敗';
    }
  }

  @override
  Widget build(BuildContext context) {
    final String rewardName = _rewardNameFromReason(log.reason);
    final bool couponCreated = log.couponId.trim().isNotEmpty;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                CircleAvatar(
                  backgroundColor: Colors.amber.shade50,
                  child: Icon(
                    Icons.redeem_outlined,
                    color: Colors.amber.shade800,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        rewardName,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatDateTime(log.createdAt),
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '-${log.absolutePoints} 點',
                  style: TextStyle(
                    color: Colors.red.shade700,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),
            FutureBuilder<String>(
              future: _loadMemberName(),
              builder:
                  (BuildContext context, AsyncSnapshot<String> memberSnapshot) {
                    final bool isLoading =
                        memberSnapshot.connectionState ==
                        ConnectionState.waiting;

                    final String memberName = isLoading
                        ? '會員資料讀取中...'
                        : memberSnapshot.data ?? '未知會員';

                    return Column(
                      children: <Widget>[
                        _HistoryInfoRow(label: '會員', value: memberName),
                        const SizedBox(height: 8),
                        _HistoryInfoRow(
                          label: '會員 UID',
                          value: log.userId.trim().isEmpty
                              ? '未知會員'
                              : log.userId,
                        ),
                        const SizedBox(height: 8),
                      ],
                    );
                  },
            ),
            _HistoryInfoRow(label: '兌換前點數', value: '${log.balanceBefore} 點'),
            const SizedBox(height: 8),
            _HistoryInfoRow(label: '兌換後點數', value: '${log.balanceAfter} 點'),
            const SizedBox(height: 8),
            _HistoryInfoRow(
              label: '優惠券狀態',
              value: couponCreated ? '已成功發送' : '沒有優惠券',
              valueColor: couponCreated
                  ? Colors.green.shade700
                  : Colors.grey.shade700,
            ),
            if (log.rewardId.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              _HistoryInfoRow(label: '商品 ID', value: log.rewardId),
            ],
            if (log.couponId.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              _HistoryInfoRow(label: '優惠券 ID', value: log.couponId),
            ],
          ],
        ),
      ),
    );
  }

  String _rewardNameFromReason(String reason) {
    final String normalizedReason = reason.trim();

    if (normalizedReason.isEmpty) {
      return '點數兌換商品';
    }

    return normalizedReason.replaceFirst('兌換「', '').replaceFirst('」', '');
  }

  String _formatDateTime(DateTime dateTime) {
    final String year = dateTime.year.toString();
    final String month = dateTime.month.toString().padLeft(2, '0');
    final String day = dateTime.day.toString().padLeft(2, '0');
    final String hour = dateTime.hour.toString().padLeft(2, '0');
    final String minute = dateTime.minute.toString().padLeft(2, '0');

    return '$year/$month/$day $hour:$minute';
  }
}

class _HistoryInfoRow extends StatelessWidget {
  const _HistoryInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 90,
          child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SelectableText(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(color: valueColor, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _EmptyExchangeHistoryView extends StatelessWidget {
  const _EmptyExchangeHistoryView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.history_outlined, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              '目前沒有點數兌換紀錄',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '會員使用點數兌換商品後，紀錄會顯示在這裡。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
