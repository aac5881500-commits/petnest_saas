// lib/features/member/pages/member_point_redemption_page.dart
// 🎁 會員實體商品頁面
// 功能：顯示會員使用點數兌換的實體商品、領取碼、領取期限與領取狀態。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/point_redemption_model.dart';
import 'package:petnest_saas/core/services/point_redemption_service.dart';
import 'package:petnest_saas/core/widgets/shop_frontend_theme_scope.dart';
import 'package:petnest_saas/features/member/pages/point_exchange_page.dart';
import 'package:petnest_saas/features/member/widgets/member_empty_state.dart';
import 'package:petnest_saas/features/member/widgets/member_filter_chips.dart';
import 'package:petnest_saas/features/member/widgets/member_page_scaffold.dart';
import 'package:petnest_saas/features/member/widgets/member_section_card.dart';
import 'package:petnest_saas/features/member/widgets/member_status_chip.dart';
import 'package:petnest_saas/features/member/widgets/member_ui_tokens.dart';

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
    final String title = shopName.trim().isEmpty
        ? '我的實體商品'
        : '${shopName.trim()}・我的實體商品';

    return ShopFrontendThemeScope(
      shopId: normalizedShopId,
      builder: (BuildContext context) => normalizedShopId.isEmpty
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
              child: StreamBuilder<List<PointRedemptionModel>>(
                stream: PointRedemptionService.instance.streamMyRedemptions(
                  shopId: normalizedShopId,
                ),
                builder: (context, snapshot) {
                  final List<PointRedemptionModel> redemptions =
                      snapshot.data ?? const <PointRedemptionModel>[];
                  final List<PointRedemptionModel> pending = redemptions
                      .where(_isPendingPickup)
                      .toList();
                  final List<PointRedemptionModel> picked = redemptions
                      .where(
                        (item) => item.status == PointRedemptionStatus.pickedUp,
                      )
                      .toList();
                  final List<PointRedemptionModel> cancelled = redemptions
                      .where(
                        (item) =>
                            item.status == PointRedemptionStatus.cancelled,
                      )
                      .toList();
                  final List<PointRedemptionModel> expired = redemptions
                      .where(_isExpired)
                      .toList();

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
                        _RedemptionList(
                          redemptions: pending,
                          emptyTitle: '目前沒有待領取商品',
                          emptyMessage: '兌換實體商品後，待領取項目會顯示在這裡。',
                          showMallButton: true,
                          shopId: normalizedShopId,
                          shopName: shopName,
                        ),
                        _RedemptionList(
                          redemptions: picked,
                          emptyTitle: '目前沒有已領取商品',
                          emptyMessage: '完成到店核銷後，紀錄會顯示在這裡。',
                        ),
                        _RedemptionList(
                          redemptions: cancelled,
                          emptyTitle: '目前沒有已取消商品',
                          emptyMessage: '被取消的兌換紀錄會顯示在這裡。',
                        ),
                        _RedemptionList(
                          redemptions: expired,
                          emptyTitle: '目前沒有已過期商品',
                          emptyMessage: '超過領取期限的兌換紀錄會顯示在這裡。',
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
                            label: '待領取',
                            count: pending.length,
                          ),
                        ),
                        Tab(
                          child: MemberCountTab(
                            label: '已領取',
                            count: picked.length,
                          ),
                        ),
                        Tab(
                          child: MemberCountTab(
                            label: '已取消',
                            count: cancelled.length,
                          ),
                        ),
                        Tab(
                          child: MemberCountTab(
                            label: '已過期',
                            count: expired.length,
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

class _RedemptionList extends StatefulWidget {
  const _RedemptionList({
    required this.redemptions,
    required this.emptyTitle,
    required this.emptyMessage,
    this.showMallButton = false,
    this.shopId = '',
    this.shopName = '',
  });

  final List<PointRedemptionModel> redemptions;
  final String emptyTitle;
  final String emptyMessage;
  final bool showMallButton;
  final String shopId;
  final String shopName;

  @override
  State<_RedemptionList> createState() => _RedemptionListState();
}

class _RedemptionListState extends State<_RedemptionList>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (widget.redemptions.isEmpty) {
      return MemberEmptyState(
        icon: Icons.inventory_2_outlined,
        title: widget.emptyTitle,
        message: widget.emptyMessage,
        actionLabel: widget.showMallButton ? '前往點數商城' : null,
        onAction: widget.showMallButton
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => PointExchangePage(
                      shopId: widget.shopId,
                      shopName: widget.shopName,
                    ),
                  ),
                );
              }
            : null,
      );
    }

    return MemberUi.constrain(
      ListView.builder(
        padding: const EdgeInsets.all(MemberUi.pagePadding),
        itemCount: widget.redemptions.length,
        itemBuilder: (context, index) {
          return _RedemptionCard(redemption: widget.redemptions[index]);
        },
      ),
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
    final bool muted =
        expired || redemption.status == PointRedemptionStatus.cancelled;
    final MemberChipTone tone;
    final String statusLabel;
    if (expired) {
      statusLabel = '已過期';
      tone = MemberChipTone.neutral;
    } else if (redemption.status == PointRedemptionStatus.pickedUp) {
      statusLabel = '已領取';
      tone = MemberChipTone.success;
    } else if (redemption.status == PointRedemptionStatus.cancelled) {
      statusLabel = '已取消';
      tone = MemberChipTone.danger;
    } else {
      statusLabel = '待領取';
      tone = MemberChipTone.warning;
    }

    return MemberSectionCard(
      muted: muted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _RewardImage(imageUrl: redemption.rewardImageUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      redemption.rewardName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: MemberUi.cardTitleSize,
                        fontWeight: FontWeight.w700,
                        color: MemberUi.of(context).text,
                      ),
                    ),
                    const SizedBox(height: 6),
                    MemberStatusChip(label: statusLabel, tone: tone),
                    if (redemption.inventoryQuantity > 0) ...<Widget>[
                      const SizedBox(height: 6),
                      Text(
                        '數量 ${redemption.inventoryQuantity}',
                        style: TextStyle(
                          fontSize: MemberUi.captionSize,
                          color: MemberUi.of(context).muted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '使用 ${redemption.pointsCost} 點兌換',
            style: TextStyle(
              fontSize: MemberUi.bodySize,
              color: MemberUi.of(context).text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '兌換時間：${_dateTimeText(redemption.createdAt)}',
            style: TextStyle(
              fontSize: MemberUi.captionSize,
              color: MemberUi.of(context).muted,
            ),
          ),
          Text(
            redemption.expireAt == null
                ? '領取期限：永久有效'
                : '領取期限：${_dateTimeText(redemption.expireAt!)}',
            style: TextStyle(
              fontSize: MemberUi.captionSize,
              color: MemberUi.of(context).muted,
            ),
          ),
          if (redemption.fulfillmentNote.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                redemption.fulfillmentNote.trim(),
                style: TextStyle(
                  fontSize: MemberUi.captionSize,
                  color: MemberUi.of(context).muted,
                ),
              ),
            ),
          if (redemption.isPendingPickup && !expired) ...<Widget>[
            const SizedBox(height: 12),
            _PickupCodeBox(pickupCode: redemption.pickupCode),
          ],
          if (redemption.pickedUpAt != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              '領取時間：${_dateTimeText(redemption.pickedUpAt!)}',
              style: TextStyle(
                fontSize: MemberUi.captionSize,
                color: MemberUi.of(context).success,
              ),
            ),
            Text(
              '核銷完成',
              style: TextStyle(
                fontSize: MemberUi.captionSize,
                fontWeight: FontWeight.w600,
                color: MemberUi.of(context).success,
              ),
            ),
          ],
          if (redemption.isCancelled &&
              redemption.cancelReason.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '取消原因：${redemption.cancelReason.trim()}',
                style: TextStyle(
                  fontSize: MemberUi.captionSize,
                  color: MemberUi.of(context).text,
                ),
              ),
            ),
          if (redemption.isCancelled)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                redemption.pointsRefunded ? '點數已退回' : '點數尚未退回',
                style: TextStyle(
                  fontSize: MemberUi.captionSize,
                  color: MemberUi.of(context).muted,
                ),
              ),
            ),
          if (expired && redemption.expireAt != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '過期時間：${_dateTimeText(redemption.expireAt!)}',
                style: TextStyle(
                  fontSize: MemberUi.captionSize,
                  color: MemberUi.of(context).muted,
                ),
              ),
            ),
        ],
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
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 80,
        height: 80,
        color: MemberUi.of(context).iconSoft,
        child: normalizedUrl.isEmpty
            ? Icon(
                Icons.inventory_2_outlined,
                size: 32,
                color: MemberUi.of(context).muted,
              )
            : Image.network(
                normalizedUrl,
                fit: BoxFit.cover,
                errorBuilder:
                    (
                      BuildContext context,
                      Object error,
                      StackTrace? stackTrace,
                    ) {
                      return Icon(
                        Icons.broken_image_outlined,
                        size: 32,
                        color: MemberUi.of(context).muted,
                      );
                    },
              ),
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: MemberUi.of(context).iconSoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: <Widget>[
          Text(
            '到店領取碼',
            style: TextStyle(
              fontSize: MemberUi.captionSize,
              color: MemberUi.of(context).muted,
            ),
          ),
          const SizedBox(height: 6),
          SelectableText(
            pickupCode.trim().isEmpty ? '尚未產生' : pickupCode.trim(),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              letterSpacing: 3,
              color: MemberUi.of(context).text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '領取商品時請向店員出示此代碼',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: MemberUi.captionSize,
              color: MemberUi.of(context).muted,
            ),
          ),
        ],
      ),
    );
  }
}
