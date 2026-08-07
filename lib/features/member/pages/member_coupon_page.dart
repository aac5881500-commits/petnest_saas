// lib/features/member/pages/member_coupon_page.dart
// 🎟️ 會員中心：我的優惠券
// 功能：顯示會員在目前店家持有的優惠券與使用狀態

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/services/member_coupon_service.dart';
import 'package:petnest_saas/core/services/shop_room_service.dart';

class MemberCouponPage extends StatelessWidget {
  const MemberCouponPage({super.key, required this.shopId, this.shopName = ''});

  final String shopId;
  final String shopName;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final normalizedShopId = shopId.trim();

    if (user == null) {
      return const Scaffold(body: Center(child: Text('請先登入')));
    }

    if (normalizedShopId.isEmpty) {
      return const Scaffold(body: Center(child: Text('找不到目前店家資料')));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(shopName.trim().isEmpty ? '我的優惠券' : '$shopName・我的優惠券'),
      ),
      body: StreamBuilder<List<MemberCouponModel>>(
        stream: MemberCouponService.instance.streamMemberCoupons(
          shopId: normalizedShopId,
          userId: user.uid,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text('讀取優惠券失敗：${snapshot.error}'),
              ),
            );
          }

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final coupons = snapshot.data!;

          if (coupons.isEmpty) {
            return const _EmptyCouponView();
          }
          final availableCoupons = coupons
              .where((coupon) => coupon.canUseNow)
              .toList();

          final reservedCoupons = coupons
              .where((coupon) => coupon.status == MemberCouponStatus.reserved)
              .toList();

          final unavailableCoupons = coupons
              .where(
                (coupon) =>
                    !coupon.canUseNow &&
                    coupon.status != MemberCouponStatus.reserved,
              )
              .toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SectionHeader(title: '可使用', count: availableCoupons.length),
              const SizedBox(height: 10),

              if (availableCoupons.isEmpty)
                const _EmptySectionCard(text: '目前沒有可使用的優惠券')
              else
                ...availableCoupons.map(
                  (coupon) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CouponCard(coupon: coupon),
                  ),
                ),

              const SizedBox(height: 16),

              _SectionHeader(title: '使用中', count: reservedCoupons.length),
              const SizedBox(height: 10),

              if (reservedCoupons.isEmpty)
                const _EmptySectionCard(text: '目前沒有使用中的優惠券')
              else
                ...reservedCoupons.map(
                  (coupon) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CouponCard(coupon: coupon),
                  ),
                ),

              const SizedBox(height: 16),

              _SectionHeader(title: '其他優惠券', count: unavailableCoupons.length),
              const SizedBox(height: 10),

              if (unavailableCoupons.isEmpty)
                const _EmptySectionCard(text: '目前沒有其他優惠券')
              else
                ...unavailableCoupons.map(
                  (coupon) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _CouponCard(coupon: coupon),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon});

  final MemberCouponModel coupon;

  @override
  Widget build(BuildContext context) {
    final status = _statusData(coupon);

    return Container(
      decoration: BoxDecoration(
        color: coupon.canUseNow ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: coupon.canUseNow
              ? Theme.of(context).colorScheme.primary.withOpacity(0.25)
              : Colors.grey.shade300,
        ),
        boxShadow: coupon.canUseNow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 8, color: status.color),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            coupon.name,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _StatusChip(text: status.text, color: status.color),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _benefitText(coupon),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (coupon.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        coupon.description.trim(),
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                    if (coupon.status == MemberCouponStatus.reserved) ...[
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Colors.blue,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '此優惠券已保留於目前預約\n取消訂單後會自動退回',
                                style: TextStyle(
                                  color: Colors.blue.shade800,
                                  fontSize: 13,
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.calendar_month_outlined,
                      text: _dateRangeText(coupon),
                    ),
                    const SizedBox(height: 6),
                    _InfoRow(
                      icon: Icons.storefront_outlined,
                      text: _applyTargetText(coupon),
                    ),
                    const SizedBox(height: 6),
                    _InfoRow(
                      icon: Icons.card_giftcard_outlined,
                      text: coupon.isPointsExchange
                          ? '點數兌換${coupon.pointsCost > 0 ? '・${coupon.pointsCost} 點' : ''}'
                          : '店家贈送',
                    ),
                    if (coupon.minimumAmount > 0) ...[
                      const SizedBox(height: 6),
                      _InfoRow(
                        icon: Icons.payments_outlined,
                        text: '最低消費 NT\$ ${coupon.minimumAmount}',
                      ),
                    ],
                    const SizedBox(height: 14),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () {
                          _showCouponDetail(context, coupon);
                        },
                        icon: const Icon(Icons.info_outline, size: 18),
                        label: const Text('查看詳情'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCouponDetail(
    BuildContext context,
    MemberCouponModel coupon,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: FractionallySizedBox(
            heightFactor: 0.82,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coupon.name,
                    style: Theme.of(bottomSheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _benefitText(coupon),
                    style: TextStyle(
                      color: Theme.of(bottomSheetContext).colorScheme.primary,
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          _CouponDetailRow(
                            title: '目前狀態',
                            value: _statusData(coupon).text,
                          ),
                          if (coupon.status == MemberCouponStatus.reserved)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.info_outline,
                                    size: 18,
                                    color: Colors.blue,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '此優惠券目前已保留給預約使用。\n'
                                      '若該筆訂單取消，優惠券會依系統流程退回。',
                                      style: TextStyle(
                                        color: Colors.blue.shade800,
                                        fontSize: 13,
                                        height: 1.5,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          _CouponDetailRow(
                            title: '適用範圍',
                            value: _applyTargetText(coupon),
                          ),
                          _CouponDetailRow(
                            title: '有效期限',
                            value: _dateRangeText(coupon),
                          ),
                          _CouponDetailRow(
                            title: '最低消費',
                            value: coupon.minimumAmount > 0
                                ? 'NT\$ ${coupon.minimumAmount}'
                                : '無最低消費限制',
                          ),
                          _CouponDetailRow(
                            title: '最高折抵',
                            value: coupon.maximumDiscountAmount > 0
                                ? 'NT\$ ${coupon.maximumDiscountAmount}'
                                : '未限制最高折抵金額',
                          ),
                          _CouponRoomTypeDetail(
                            shopId: coupon.shopId,
                            roomTypeIds: coupon.roomTypeIds,
                          ),
                          _CouponDetailRow(
                            title: '使用次數',
                            value: coupon.usageLimit > 0
                                ? '可使用 ${coupon.usageLimit} 次，已使用 ${coupon.usedCount} 次'
                                : '未限制使用次數',
                          ),
                          _CouponDetailRow(
                            title: '取得方式',
                            value: coupon.isPointsExchange
                                ? '使用 ${coupon.pointsCost} 點兌換'
                                : '店家贈送',
                          ),
                          if (coupon.issuedReason.trim().isNotEmpty)
                            _CouponDetailRow(
                              title: '發放原因',
                              value: coupon.issuedReason.trim(),
                            ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  '特殊說明',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                SelectableText(
                                  coupon.description.trim().isEmpty
                                      ? '店家目前沒有填寫其他特殊說明。'
                                      : coupon.description.trim(),
                                  style: TextStyle(
                                    color: Colors.grey.shade800,
                                    height: 1.6,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            '優惠券實際是否能套用，仍會依預約日期、房型、訂單金額與使用狀態重新判斷。',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                      },
                      child: const Text('關閉'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _benefitText(MemberCouponModel coupon) {
    switch (coupon.type) {
      case MemberCouponType.fixedAmount:
        return '折抵 NT\$ ${coupon.discountValue.toInt()}';

      case MemberCouponType.percent:
        final discount = coupon.discountValue;
        final displayValue = discount == discount.toInt()
            ? discount.toInt().toString()
            : discount.toString();

        return '折抵 $displayValue%';

      case MemberCouponType.freeStay:
        return '免費住宿 ${coupon.freeStayNights} 晚';

      case MemberCouponType.freeService:
        return coupon.serviceName.trim().isEmpty
            ? '免費服務券'
            : '免費 ${coupon.serviceName.trim()}';
    }
  }

  String _applyTargetText(MemberCouponModel coupon) {
    switch (coupon.applyTarget) {
      case MemberCouponApplyTarget.room:
        return '適用房價';

      case MemberCouponApplyTarget.roomAndPet:
        return '適用房價與寵物費';

      case MemberCouponApplyTarget.total:
        return '適用整張訂單';

      case MemberCouponApplyTarget.service:
        return coupon.serviceName.trim().isEmpty
            ? '適用指定服務'
            : '適用服務：${coupon.serviceName.trim()}';
    }
  }

  String _dateRangeText(MemberCouponModel coupon) {
    final start = coupon.startAt;
    final end = coupon.expireAt;

    if (start == null && end == null) {
      return '永久有效';
    }

    if (start != null && end != null) {
      return '${_formatDate(start)} ～ ${_formatDate(end)}';
    }

    if (start != null) {
      return '${_formatDate(start)} 起可使用';
    }

    return '有效期限至 ${_formatDate(end!)}';
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '$year/$month/$day';
  }

  _CouponStatusData _statusData(MemberCouponModel coupon) {
    if (coupon.status == MemberCouponStatus.reserved) {
      return const _CouponStatusData(text: '使用中', color: Colors.blue);
    }

    if (coupon.status == MemberCouponStatus.revoked) {
      return const _CouponStatusData(text: '已撤銷', color: Colors.grey);
    }

    if (coupon.status == MemberCouponStatus.used ||
        coupon.isUsageLimitReached) {
      return const _CouponStatusData(text: '已使用', color: Colors.blueGrey);
    }

    if (coupon.isExpired) {
      return const _CouponStatusData(text: '已過期', color: Colors.red);
    }

    if (coupon.isNotStarted) {
      return const _CouponStatusData(text: '尚未開始', color: Colors.orange);
    }

    return const _CouponStatusData(text: '可使用', color: Colors.green);
  }
}

class _CouponRoomTypeDetail extends StatelessWidget {
  const _CouponRoomTypeDetail({
    required this.shopId,
    required this.roomTypeIds,
  });

  final String shopId;
  final List<String> roomTypeIds;

  @override
  Widget build(BuildContext context) {
    if (roomTypeIds.isEmpty) {
      return const _CouponDetailRow(title: '適用房型', value: '所有房型');
    }

    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ShopRoomService.instance.streamRoomTypes(shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.hasError) {
              return const _CouponDetailRow(
                title: '適用房型',
                value: '指定房型，暫時無法讀取房型名稱',
              );
            }

            if (!snapshot.hasData) {
              return const _CouponDetailRow(title: '適用房型', value: '房型資料讀取中…');
            }

            final Map<String, String> roomTypeNameMap = <String, String>{
              for (final Map<String, dynamic> roomType in snapshot.data!)
                (roomType['id'] ?? '').toString(): (roomType['name'] ?? '未命名房型')
                    .toString(),
            };

            final List<String> roomTypeNames = roomTypeIds.map((String id) {
              final String? name = roomTypeNameMap[id];

              if (name == null || name.trim().isEmpty) {
                return '已刪除房型';
              }

              return name.trim();
            }).toList();

            return _CouponDetailRow(
              title: '適用房型',
              value: roomTypeNames.join('、'),
            );
          },
    );
  }
}

class _CouponDetailRow extends StatelessWidget {
  const _CouponDetailRow({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 88,
            child: Text(
              title,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _CouponStatusData {
  const _CouponStatusData({required this.text, required this.color});

  final String text;
  final Color color;
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
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
        Icon(icon, size: 17, color: Colors.grey.shade600),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
          ),
        ),
      ],
    );
  }
}

class _EmptyCouponView extends StatelessWidget {
  const _EmptyCouponView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.confirmation_number_outlined,
              size: 72,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            const Text(
              '目前沒有優惠券',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '之後可透過店家贈送或點數兌換取得優惠券',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySectionCard extends StatelessWidget {
  const _EmptySectionCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey.shade600),
      ),
    );
  }
}
