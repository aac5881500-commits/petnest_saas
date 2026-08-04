// lib/features/member/pages/member_point_redemption_page.dart
// 🎁 會員實體商品頁面
// 功能：顯示會員使用點數兌換的實體商品、領取碼、領取期限與領取狀態。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/point_redemption_model.dart';
import 'package:petnest_saas/core/services/point_redemption_service.dart';

class MemberPointRedemptionPage extends StatelessWidget {
  const MemberPointRedemptionPage({
    super.key,
    required this.shopId,
    this.shopName = '',
  });

  final String shopId;
  final String shopName;

  @override
  Widget build(BuildContext context) {
    final String normalizedShopId = shopId.trim();

    if (normalizedShopId.isEmpty) {
      return const Scaffold(body: Center(child: Text('找不到目前店家資料')));
    }

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            shopName.trim().isEmpty ? '我的實體商品' : '${shopName.trim()}・我的實體商品',
          ),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: '待領取'),
              Tab(text: '已領取'),
              Tab(text: '已取消'),
              Tab(text: '已過期'),
            ],
          ),
        ),
        body: StreamBuilder<List<PointRedemptionModel>>(
          stream: PointRedemptionService.instance.streamMyRedemptions(
            shopId: normalizedShopId,
          ),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    '讀取實體商品紀錄失敗\n${snapshot.error}',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<PointRedemptionModel> redemptions = snapshot.data!;

            return TabBarView(
              children: [
                _RedemptionList(
                  redemptions: redemptions.where(_isPendingPickup).toList(),
                  emptyText: '目前沒有待領取商品',
                ),
                _RedemptionList(
                  redemptions: redemptions
                      .where(
                        (item) => item.status == PointRedemptionStatus.pickedUp,
                      )
                      .toList(),
                  emptyText: '目前沒有已領取商品',
                ),
                _RedemptionList(
                  redemptions: redemptions
                      .where(
                        (item) =>
                            item.status == PointRedemptionStatus.cancelled,
                      )
                      .toList(),
                  emptyText: '目前沒有已取消商品',
                ),
                _RedemptionList(
                  redemptions: redemptions.where(_isExpired).toList(),
                  emptyText: '目前沒有已過期商品',
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  static bool _isPendingPickup(PointRedemptionModel redemption) {
    return redemption.status == PointRedemptionStatus.pendingPickup &&
        !redemption.hasExpired;
  }

  static bool _isExpired(PointRedemptionModel redemption) {
    return redemption.status == PointRedemptionStatus.expired ||
        (redemption.status == PointRedemptionStatus.pendingPickup &&
            redemption.hasExpired);
  }
}

class _RedemptionList extends StatelessWidget {
  const _RedemptionList({required this.redemptions, required this.emptyText});

  final List<PointRedemptionModel> redemptions;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    if (redemptions.isEmpty) {
      return _EmptyView(text: emptyText);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: redemptions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _RedemptionCard(redemption: redemptions[index]);
      },
    );
  }
}

class _RedemptionCard extends StatelessWidget {
  const _RedemptionCard({required this.redemption});

  final PointRedemptionModel redemption;

  @override
  Widget build(BuildContext context) {
    final bool expired =
        redemption.status == PointRedemptionStatus.expired ||
        (redemption.isPendingPickup && redemption.hasExpired);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _RewardImage(imageUrl: redemption.rewardImageUrl),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        redemption.rewardName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (redemption.rewardDescription.trim().isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          redemption.rewardDescription.trim(),
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                      const SizedBox(height: 8),
                      _StatusChip(status: redemption.status, expired: expired),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _InfoRow(
              icon: Icons.paid_outlined,
              text: '使用 ${redemption.pointsCost} 點兌換',
            ),
            const SizedBox(height: 7),
            _InfoRow(
              icon: Icons.schedule_outlined,
              text: '兌換時間：${_dateTimeText(redemption.createdAt)}',
            ),
            if (redemption.expireAt != null) ...[
              const SizedBox(height: 7),
              _InfoRow(
                icon: Icons.event_busy_outlined,
                text: '領取期限：${_dateTimeText(redemption.expireAt!)}',
              ),
            ] else ...[
              const SizedBox(height: 7),
              const _InfoRow(
                icon: Icons.all_inclusive_outlined,
                text: '領取期限：永久有效',
              ),
            ],
            if (redemption.isPendingPickup && !expired) ...[
              const SizedBox(height: 16),
              _PickupCodeBox(pickupCode: redemption.pickupCode),
            ],
            if (redemption.fulfillmentNote.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.storefront_outlined,
                text: redemption.fulfillmentNote.trim(),
              ),
            ],
            if (redemption.pickedUpAt != null) ...[
              const SizedBox(height: 7),
              _InfoRow(
                icon: Icons.check_circle_outline,
                text: '領取時間：${_dateTimeText(redemption.pickedUpAt!)}',
              ),
            ],
            if (redemption.isCancelled &&
                redemption.cancelReason.trim().isNotEmpty) ...[
              const SizedBox(height: 7),
              _InfoRow(
                icon: Icons.info_outline,
                text: '取消原因：${redemption.cancelReason.trim()}',
              ),
            ],
            if (redemption.isCancelled) ...[
              const SizedBox(height: 7),
              _InfoRow(
                icon: Icons.currency_exchange_outlined,
                text: redemption.pointsRefunded ? '點數已退回' : '點數尚未退回',
              ),
            ],
          ],
        ),
      ),
    );
  }

  static String _dateTimeText(DateTime dateTime) {
    final DateTime local = dateTime.toLocal();

    String twoDigits(int value) {
      return value.toString().padLeft(2, '0');
    }

    return '${local.year}/${twoDigits(local.month)}/${twoDigits(local.day)} '
        '${twoDigits(local.hour)}:${twoDigits(local.minute)}';
  }
}

class _RewardImage extends StatelessWidget {
  const _RewardImage({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final String normalizedUrl = imageUrl.trim();

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: 76,
        height: 76,
        color: Colors.grey.shade100,
        child: normalizedUrl.isEmpty
            ? Icon(
                Icons.inventory_2_outlined,
                size: 36,
                color: Colors.grey.shade500,
              )
            : Image.network(
                normalizedUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) {
                  return Icon(
                    Icons.broken_image_outlined,
                    size: 34,
                    color: Colors.grey.shade500,
                  );
                },
              ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status, required this.expired});

  final PointRedemptionStatus status;
  final bool expired;

  @override
  Widget build(BuildContext context) {
    final String text;
    final IconData icon;
    final Color backgroundColor;
    final Color foregroundColor;

    if (expired) {
      text = '已過期';
      icon = Icons.event_busy_outlined;
      backgroundColor = Colors.grey.shade200;
      foregroundColor = Colors.grey.shade700;
    } else {
      switch (status) {
        case PointRedemptionStatus.pendingPickup:
          text = '待領取';
          icon = Icons.schedule_outlined;
          backgroundColor = Colors.orange.shade50;
          foregroundColor = Colors.orange.shade800;

        case PointRedemptionStatus.pickedUp:
          text = '已領取';
          icon = Icons.check_circle_outline;
          backgroundColor = Colors.green.shade50;
          foregroundColor = Colors.green.shade800;

        case PointRedemptionStatus.cancelled:
          text = '已取消';
          icon = Icons.cancel_outlined;
          backgroundColor = Colors.red.shade50;
          foregroundColor = Colors.red.shade700;

        case PointRedemptionStatus.expired:
          text = '已過期';
          icon = Icons.event_busy_outlined;
          backgroundColor = Colors.grey.shade200;
          foregroundColor = Colors.grey.shade700;
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: foregroundColor),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: foregroundColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

class _PickupCodeBox extends StatelessWidget {
  const _PickupCodeBox({required this.pickupCode});

  final String pickupCode;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            '到店領取碼',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 7),
          SelectableText(
            pickupCode.trim().isEmpty ? '尚未產生' : pickupCode.trim(),
            style: TextStyle(
              fontSize: 25,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '領取商品時請向店員出示此代碼',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onPrimaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.grey.shade600),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: TextStyle(color: Colors.grey.shade700)),
        ),
      ],
    );
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 14),
            Text(
              text,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
