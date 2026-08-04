// lib/features/member/pages/point_exchange_history_page.dart
// 🎁 會員點數兌換紀錄頁
// 功能：顯示會員在目前店家使用點數兌換商品的歷史紀錄

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/member_point_log_model.dart';
import 'package:petnest_saas/core/services/member_point_service.dart';
import 'package:petnest_saas/features/member/pages/member_coupon_page.dart';

class PointExchangeHistoryPage extends StatelessWidget {
  const PointExchangeHistoryPage({
    super.key,
    required this.shopId,
    this.shopName = '',
  });

  final String shopId;
  final String shopName;

  @override
  Widget build(BuildContext context) {
    final String normalizedShopId = shopId.trim();
    final String userId = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';

    if (normalizedShopId.isEmpty) {
      return const Scaffold(body: Center(child: Text('找不到目前店家資料')));
    }

    if (userId.isEmpty) {
      return const Scaffold(body: Center(child: Text('請先登入會員帳號')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          shopName.trim().isEmpty ? '兌換紀錄' : '${shopName.trim()}・兌換紀錄',
        ),
      ),
      body: StreamBuilder<List<MemberPointLogModel>>(
        stream: MemberPointService.instance.streamMemberPointLogs(
          shopId: normalizedShopId,
          userId: userId,
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
                      '讀取兌換紀錄失敗\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final List<MemberPointLogModel> exchangeLogs =
                  (snapshot.data ?? const <MemberPointLogModel>[])
                      .where(
                        (MemberPointLogModel log) =>
                            log.type == MemberPointLogType.rewardExchange,
                      )
                      .toList();

              if (exchangeLogs.isEmpty) {
                return const _EmptyExchangeHistoryView();
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: exchangeLogs.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (BuildContext context, int index) {
                  return _ExchangeHistoryCard(
                    log: exchangeLogs[index],
                    shopId: normalizedShopId,
                    shopName: shopName,
                  );
                },
              );
            },
      ),
    );
  }
}

class _ExchangeHistoryCard extends StatelessWidget {
  const _ExchangeHistoryCard({
    required this.log,
    required this.shopId,
    required this.shopName,
  });

  final MemberPointLogModel log;
  final String shopId;
  final String shopName;
  @override
  Widget build(BuildContext context) {
    final String title = _rewardNameFromReason(log.reason);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    children: [
                      Text(
                        title,
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
            _HistoryInfoRow(label: '兌換前點數', value: '${log.balanceBefore} 點'),
            const SizedBox(height: 8),
            _HistoryInfoRow(label: '兌換後點數', value: '${log.balanceAfter} 點'),
            if (log.couponId.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              const _HistoryInfoRow(label: '兌換結果', value: '優惠券已發送'),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.confirmation_number_outlined),
                  label: const Text('查看我的優惠券'),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => MemberCouponPage(
                          shopId: shopId,
                          shopName: shopName,
                        ),
                      ),
                    );
                  },
                ),
              ),
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
  const _HistoryInfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label, style: TextStyle(color: Colors.grey.shade600)),
        const Spacer(),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
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
          children: [
            Icon(Icons.history_outlined, size: 72, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              '目前沒有兌換紀錄',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '使用點數兌換商品後，紀錄會顯示在這裡。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
