// lib/features/member/pages/member_coupon_page.dart
// 🎟️ 會員中心：我的優惠券
// 功能：顯示會員在目前店家持有的優惠券與使用狀態

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/services/member_coupon_service.dart';
import 'package:petnest_saas/core/services/shop_room_service.dart';
import 'package:petnest_saas/core/widgets/shop_frontend_theme_scope.dart';
import 'package:petnest_saas/features/booking/pages/booking_detail_page.dart';
import 'package:petnest_saas/features/member/widgets/member_empty_state.dart';
import 'package:petnest_saas/features/member/widgets/member_filter_chips.dart';
import 'package:petnest_saas/features/member/widgets/member_list_helpers.dart';
import 'package:petnest_saas/features/member/widgets/member_page_scaffold.dart';
import 'package:petnest_saas/features/member/widgets/member_section_card.dart';
import 'package:petnest_saas/features/member/widgets/member_status_chip.dart';
import 'package:petnest_saas/features/member/widgets/member_ui_tokens.dart';

class MemberCouponPage extends StatelessWidget {
  const MemberCouponPage({super.key, required this.shopId, this.shopName = ''});

  final String shopId;
  final String shopName;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final normalizedShopId = shopId.trim();
    final String title = shopName.trim().isEmpty
        ? '我的優惠券'
        : '${shopName.trim()}・我的優惠券';

    return ShopFrontendThemeScope(
      shopId: normalizedShopId,
      builder: (BuildContext context) => user == null
          ? MemberPageScaffold(
              title: title,
              body: const MemberEmptyState(
                icon: Icons.lock_outline,
                title: '請先登入',
                message: '登入後即可查看優惠券。',
              ),
            )
          : normalizedShopId.isEmpty
          ? MemberPageScaffold(
              title: title,
              body: const MemberEmptyState(
                icon: Icons.storefront_outlined,
                title: '找不到店家',
                message: '目前沒有可查看的店家資料。',
              ),
            )
          : DefaultTabController(
              length: 4,
              child: StreamBuilder<List<MemberCouponModel>>(
                stream: MemberCouponService.instance.streamMemberCoupons(
                  shopId: normalizedShopId,
                  userId: user.uid,
                ),
                builder: (context, snapshot) {
                  final MemberCouponGroups groups = snapshot.hasData
                      ? MemberCouponGroups.fromList(snapshot.data!)
                      : const MemberCouponGroups(
                          available: <MemberCouponModel>[],
                          reserved: <MemberCouponModel>[],
                          used: <MemberCouponModel>[],
                          other: <MemberCouponModel>[],
                        );

                  Widget body;
                  if (snapshot.hasError) {
                    MemberUi.logError(snapshot.error!);
                    body = MemberErrorState(
                      message: MemberUi.friendlyError(snapshot.error!),
                    );
                  } else if (!snapshot.hasData) {
                    body = const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  } else {
                    body = TabBarView(
                      children: <Widget>[
                        _CouponTabList(
                          coupons: groups.available,
                          emptyTitle: '目前沒有可使用的優惠券',
                          emptyMessage: '店家發放或點數兌換後，可用優惠券會顯示在這裡。',
                        ),
                        _CouponTabList(
                          coupons: groups.reserved,
                          emptyTitle: '目前沒有使用中的優惠券',
                          emptyMessage: '套用到進行中訂單的優惠券會顯示在這裡。',
                        ),
                        _CouponTabList(
                          coupons: groups.used,
                          emptyTitle: '目前沒有已使用的優惠券',
                          emptyMessage: '使用完成的優惠券會顯示在這裡。',
                        ),
                        _CouponTabList(
                          coupons: groups.other,
                          emptyTitle: '目前沒有其他優惠券',
                          emptyMessage: '已過期、已撤銷或尚未開始的優惠券會顯示在這裡。',
                        ),
                      ],
                    );
                  }

                  return MemberPageScaffold(
                    title: title,
                    bottom: TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelColor: MemberUi.of(context).primary,
                      unselectedLabelColor: MemberUi.of(context).muted,
                      indicatorColor: MemberUi.of(context).primary,
                      tabs: <Widget>[
                        Tab(
                          child: MemberCountTab(
                            label: '可使用',
                            count: groups.available.length,
                          ),
                        ),
                        Tab(
                          child: MemberCountTab(
                            label: '使用中',
                            count: groups.reserved.length,
                          ),
                        ),
                        Tab(
                          child: MemberCountTab(
                            label: '已使用',
                            count: groups.used.length,
                          ),
                        ),
                        Tab(
                          child: MemberCountTab(
                            label: '其他',
                            count: groups.other.length,
                          ),
                        ),
                      ],
                    ),
                    body: body,
                  );
                },
              ),
            ),
    );
  }
}

class _CouponTabList extends StatefulWidget {
  const _CouponTabList({
    required this.coupons,
    required this.emptyTitle,
    required this.emptyMessage,
  });

  final List<MemberCouponModel> coupons;
  final String emptyTitle;
  final String emptyMessage;

  @override
  State<_CouponTabList> createState() => _CouponTabListState();
}

class _CouponTabListState extends State<_CouponTabList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.coupons.isEmpty) {
      return MemberEmptyState(
        icon: Icons.confirmation_number_outlined,
        title: widget.emptyTitle,
        message: widget.emptyMessage,
      );
    }
    return MemberUi.constrain(
      ListView.builder(
        padding: const EdgeInsets.all(MemberUi.pagePadding),
        itemCount: widget.coupons.length,
        itemBuilder: (BuildContext context, int index) {
          return _CouponCard(coupon: widget.coupons[index]);
        },
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  const _CouponCard({required this.coupon});

  final MemberCouponModel coupon;

  @override
  Widget build(BuildContext context) {
    final _CouponStatusData status = _statusData(context, coupon);
    final bool muted = !coupon.canUseNow;

    return MemberSectionCard(
      muted: muted,
      onTap: () => _showCouponDetail(context, coupon),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 4,
            height: 88,
            decoration: BoxDecoration(
              color: status.color,
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        coupon.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: MemberUi.cardTitleSize,
                          fontWeight: FontWeight.w700,
                          color: MemberUi.of(context).text,
                        ),
                      ),
                    ),
                    MemberStatusChip(label: status.text, tone: status.tone),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _benefitText(coupon),
                  style: TextStyle(
                    color: muted
                        ? MemberUi.of(context).muted
                        : MemberUi.of(context).primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _dateRangeText(coupon),
                  style: TextStyle(
                    fontSize: MemberUi.captionSize,
                    color: MemberUi.of(context).muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _applyTargetText(coupon),
                  style: TextStyle(
                    fontSize: MemberUi.captionSize,
                    color: MemberUi.of(context).muted,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  coupon.isPointsExchange
                      ? '點數兌換${coupon.pointsCost > 0 ? '・${coupon.pointsCost} 點' : ''}'
                      : '店家贈送',
                  style: TextStyle(
                    fontSize: MemberUi.captionSize,
                    color: MemberUi.of(context).muted,
                  ),
                ),
                if (coupon.status == MemberCouponStatus.reserved &&
                    coupon.usedBookingId.trim().isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    '已綁定訂單 #${coupon.usedBookingId.length > 8 ? coupon.usedBookingId.substring(0, 8) : coupon.usedBookingId}',
                    style: TextStyle(
                      fontSize: MemberUi.captionSize,
                      fontWeight: FontWeight.w600,
                      color: MemberUi.of(context).primary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: MemberUi.of(context).muted),
        ],
      ),
    );
  }

  Future<void> _openBoundBooking(BuildContext context, String bookingId) async {
    final String id = bookingId.trim();
    if (id.isEmpty) {
      return;
    }
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await FirebaseFirestore.instance.collection('bookings').doc(id).get();
      if (!context.mounted) {
        return;
      }
      final Map<String, dynamic>? data = snapshot.data();
      if (!snapshot.exists || data == null) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('目前找不到這筆訂單。')));
        return;
      }
      await Navigator.push<void>(
        context,
        MaterialPageRoute<void>(
          builder: (_) => BookingDetailPage(data: data, docId: snapshot.id),
        ),
      );
    } catch (error) {
      MemberUi.logError(error);
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(MemberUi.friendlyError(error))));
    }
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
                            value: _statusData(context, coupon).text,
                          ),
                          if (coupon.status == MemberCouponStatus.reserved)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 14),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton(
                                  onPressed: coupon.usedBookingId.trim().isEmpty
                                      ? null
                                      : () {
                                          Navigator.pop(bottomSheetContext);
                                          _openBoundBooking(
                                            context,
                                            coupon.usedBookingId,
                                          );
                                        },
                                  child: const Text('查看綁定訂單'),
                                ),
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
                          if (coupon.usedBookingId.trim().isNotEmpty)
                            _CouponDetailRow(
                              title: '綁定訂單',
                              value: coupon.usedBookingId.trim(),
                            ),
                          if (coupon.usedAt != null)
                            _CouponDetailRow(
                              title: '使用時間',
                              value: _formatDate(coupon.usedAt!),
                            ),
                          if (coupon.revokedReason.trim().isNotEmpty)
                            _CouponDetailRow(
                              title: '撤銷原因',
                              value: coupon.revokedReason.trim(),
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

  _CouponStatusData _statusData(
    BuildContext context,
    MemberCouponModel coupon,
  ) {
    if (coupon.status == MemberCouponStatus.reserved) {
      return const _CouponStatusData(
        text: '使用中',
        color: Color(0xFF6B8FAF),
        tone: MemberChipTone.neutral,
      );
    }

    if (coupon.status == MemberCouponStatus.revoked) {
      return _CouponStatusData(
        text: '已撤銷',
        color: MemberUi.of(context).muted,
        tone: MemberChipTone.neutral,
      );
    }

    if (coupon.status == MemberCouponStatus.used ||
        coupon.isUsageLimitReached) {
      return _CouponStatusData(
        text: '已使用',
        color: MemberUi.of(context).muted,
        tone: MemberChipTone.neutral,
      );
    }

    if (coupon.isExpired) {
      return _CouponStatusData(
        text: '已過期',
        color: MemberUi.of(context).danger,
        tone: MemberChipTone.danger,
      );
    }

    if (coupon.isNotStarted) {
      return _CouponStatusData(
        text: '尚未開始',
        color: MemberUi.of(context).warning,
        tone: MemberChipTone.warning,
      );
    }

    return _CouponStatusData(
      text: '可使用',
      color: MemberUi.of(context).success,
      tone: MemberChipTone.success,
    );
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
  const _CouponStatusData({
    required this.text,
    required this.color,
    required this.tone,
  });

  final String text;
  final Color color;
  final MemberChipTone tone;
}
