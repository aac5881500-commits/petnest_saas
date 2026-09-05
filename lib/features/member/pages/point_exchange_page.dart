// 檔案名稱：lib/features/member/pages/point_exchange_page.dart
// 功能說明：顯示目前店家的點數兌換商品，並使用 Transaction 完成兌換
// 🎁 會員點數商城

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';
import 'package:petnest_saas/core/models/member_point_model.dart';
import 'package:petnest_saas/core/models/point_reward_model.dart';
import 'package:petnest_saas/core/models/point_setting_model.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';
import 'package:petnest_saas/core/services/member_point_service.dart';
import 'package:petnest_saas/core/services/point_setting_service.dart';
import 'package:petnest_saas/core/services/point_exchange_service.dart';
import 'package:petnest_saas/core/services/point_reward_service.dart';
import 'package:petnest_saas/core/widgets/shop_frontend_theme_scope.dart';
import 'package:petnest_saas/features/member/pages/member_coupon_page.dart';
import 'package:petnest_saas/features/member/pages/point_exchange_history_page.dart';
import 'package:petnest_saas/features/member/pages/member_point_redemption_page.dart';
import 'package:petnest_saas/features/member/widgets/member_empty_state.dart';
import 'package:petnest_saas/features/member/widgets/member_page_scaffold.dart';
import 'package:petnest_saas/features/member/widgets/member_section_card.dart';
import 'package:petnest_saas/features/member/widgets/member_ui_tokens.dart';

class PointExchangePage extends StatelessWidget {
  const PointExchangePage({
    super.key,
    required this.shopId,
    this.shopName = '',
  });

  final String shopId;
  final String shopName;

  @override
  Widget build(BuildContext context) {
    return ShopFrontendThemeScope(
      shopId: shopId,
      builder: (BuildContext context) {
        return _PointExchangeBody(shopId: shopId, shopName: shopName);
      },
    );
  }
}

class _PointExchangeBody extends StatefulWidget {
  const _PointExchangeBody({required this.shopId, required this.shopName});

  final String shopId;
  final String shopName;

  @override
  State<_PointExchangeBody> createState() => _PointExchangePageState();
}

class _PointExchangePageState extends State<_PointExchangeBody> {
  String? _exchangingRewardId;

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid.trim() ?? '';
    final String shopId = widget.shopId.trim();

    if (userId.isEmpty) {
      return const MemberPageScaffold(
        title: '點數商城',
        body: MemberEmptyState(
          icon: Icons.lock_outline,
          title: '請先登入',
          message: '登入後即可使用點數兌換。',
        ),
      );
    }

    if (shopId.isEmpty) {
      return const MemberPageScaffold(
        title: '點數商城',
        body: MemberEmptyState(
          icon: Icons.storefront_outlined,
          title: '找不到店家',
          message: '目前沒有可查看的店家資料。',
        ),
      );
    }

    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    final String title = widget.shopName.trim().isEmpty
        ? '點數商城'
        : '${widget.shopName.trim()}・點數商城';

    return MemberPageScaffold(
      title: title,
      actions: <Widget>[
        IconButton(
          tooltip: '我的實體商品',
          icon: const Icon(Icons.inventory_2_outlined),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => MemberPointRedemptionPage(
                  shopId: shopId,
                  shopName: widget.shopName,
                ),
              ),
            );
          },
        ),
        IconButton(
          tooltip: '兌換紀錄',
          icon: const Icon(Icons.history_outlined),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => PointExchangeHistoryPage(
                  shopId: shopId,
                  shopName: widget.shopName,
                ),
              ),
            );
          },
        ),
      ],
      body: StreamBuilder<PointSettingModel>(
        stream: PointSettingService.instance.streamPointSetting(shopId),
        builder: (context, settingSnapshot) {
          if (settingSnapshot.hasError) {
            MemberUi.logError(settingSnapshot.error!);
            return MemberErrorState(
              message: MemberUi.friendlyError(settingSnapshot.error!),
            );
          }

          if (!settingSnapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final PointSettingModel setting = settingSnapshot.data!;

          if (!setting.enabled || !setting.allowPointsExchange) {
            return const _PointsExchangeClosedView();
          }

          return StreamBuilder<MemberPointModel>(
            stream: MemberPointService.instance.streamMemberPoint(
              shopId: shopId,
              userId: userId,
            ),
            builder: (context, pointSnapshot) {
              if (pointSnapshot.hasError) {
                MemberUi.logError(pointSnapshot.error!);
                return MemberErrorState(
                  message: MemberUi.friendlyError(pointSnapshot.error!),
                );
              }

              if (!pointSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final MemberPointModel point = pointSnapshot.data!;

              return StreamBuilder<List<PointRewardModel>>(
                stream: PointRewardService.instance.streamEnabledRewards(
                  shopId,
                ),
                builder: (context, rewardSnapshot) {
                  if (rewardSnapshot.hasError) {
                    MemberUi.logError(rewardSnapshot.error!);
                    return MemberErrorState(
                      message: MemberUi.friendlyError(rewardSnapshot.error!),
                    );
                  }

                  if (!rewardSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final List<PointRewardModel> rewards = rewardSnapshot.data!;

                  final List<PointRewardModel> couponRewards = rewards
                      .where(
                        (PointRewardModel reward) => !reward.isPhysicalProduct,
                      )
                      .toList();

                  final List<PointRewardModel> physicalRewards = rewards
                      .where(
                        (PointRewardModel reward) => reward.isPhysicalProduct,
                      )
                      .toList();

                  return DefaultTabController(
                    length: 2,
                    child: Column(
                      children: <Widget>[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                          child: _PointBalanceCard(points: point.currentPoints),
                        ),
                        Container(
                          margin: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: theme.borderColor),
                          ),
                          child: TabBar(
                            indicatorColor: theme.primaryColor,
                            labelColor: theme.primaryColor,
                            unselectedLabelColor: theme.subtitleColor,
                            tabs: const <Widget>[
                              Tab(
                                icon: Icon(Icons.confirmation_number_outlined),
                                text: '優惠券',
                              ),
                              Tab(
                                icon: Icon(Icons.inventory_2_outlined),
                                text: '實體商品',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: TabBarView(
                            children: <Widget>[
                              _buildRewardList(
                                rewards: couponRewards,
                                shopId: shopId,
                                userId: userId,
                                currentPoints: point.currentPoints,
                                emptyTitle: '目前沒有可兌換的優惠券',
                                emptyDescription: '店家建立點數優惠券後會顯示在這裡',
                                emptyIcon: Icons.confirmation_number_outlined,
                              ),
                              _buildRewardList(
                                rewards: physicalRewards,
                                shopId: shopId,
                                userId: userId,
                                currentPoints: point.currentPoints,
                                emptyTitle: '目前沒有可兌換的實體商品',
                                emptyDescription: '店家建立實體兌換商品後會顯示在這裡',
                                emptyIcon: Icons.inventory_2_outlined,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildRewardList({
    required List<PointRewardModel> rewards,
    required String shopId,
    required String userId,
    required int currentPoints,
    required String emptyTitle,
    required String emptyDescription,
    required IconData emptyIcon,
  }) {
    if (rewards.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _EmptyRewardCard(
            title: emptyTitle,
            description: emptyDescription,
            icon: emptyIcon,
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: rewards.length,
      separatorBuilder: (BuildContext context, int index) {
        return const SizedBox(height: 12);
      },
      itemBuilder: (BuildContext context, int index) {
        final PointRewardModel reward = rewards[index];

        return StreamBuilder<int>(
          stream: PointExchangeService.instance.streamMemberExchangedCount(
            shopId: shopId,
            rewardId: reward.id,
            userId: userId,
          ),
          builder: (BuildContext context, AsyncSnapshot<int> exchangeSnapshot) {
            final int memberExchangedCount = exchangeSnapshot.data ?? 0;

            return _RewardCard(
              reward: reward,
              currentPoints: currentPoints,
              memberExchangedCount: memberExchangedCount,
              isExchanging: _exchangingRewardId == reward.id,
              onExchange: () {
                _confirmExchange(reward: reward, currentPoints: currentPoints);
              },
            );
          },
        );
      },
    );
  }

  Future<void> _confirmExchange({
    required PointRewardModel reward,
    required int currentPoints,
  }) async {
    if (_exchangingRewardId != null) {
      return;
    }

    if (currentPoints < reward.pointsCost) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('點數不足，目前有 $currentPoints 點，需要 ${reward.pointsCost} 點'),
        ),
      );
      return;
    }

    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    final int remaining = currentPoints - reward.pointsCost;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: theme.cardColor,
          title: Text('確認兌換', style: TextStyle(color: theme.titleColor)),
          content: Text(
            '兌換前：$currentPoints 點\n'
            '本次扣除：${reward.pointsCost} 點\n'
            '兌換後剩餘：${remaining < 0 ? 0 : remaining} 點\n\n'
            '確定兌換「${reward.name}」嗎？\n\n'
            '${reward.isPhysicalProduct ? '兌換成功後，請到「我的實體商品」查看領取碼，並於兌換後 ${reward.validDays > 0 ? '${reward.validDays} 天內' : '期限內'}至店家領取。${reward.fulfillmentNote.trim().isEmpty ? '' : '\n${reward.fulfillmentNote.trim()}'}' : '兌換成功後，優惠券會放入「我的優惠券」。'}',
            style: TextStyle(color: theme.bodyTextColor, height: 1.45),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text('取消', style: TextStyle(color: theme.subtitleColor)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: FilledButton.styleFrom(
                backgroundColor: theme.buttonColor,
                foregroundColor: theme.onPrimaryColor,
              ),
              child: const Text('確認兌換'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) {
      return;
    }

    setState(() {
      _exchangingRewardId = reward.id;
    });

    try {
      await PointExchangeService.instance.exchangeReward(
        shopId: widget.shopId,
        rewardId: reward.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('已成功兌換「${reward.name}」'),
            duration: const Duration(seconds: 5),
            action: reward.isCouponReward
                ? SnackBarAction(
                    label: '查看優惠券',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MemberCouponPage(
                            shopId: widget.shopId,
                            shopName: widget.shopName,
                          ),
                        ),
                      );
                    },
                  )
                : null,
          ),
        );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorMessage(error))));
    } finally {
      if (mounted) {
        setState(() {
          _exchangingRewardId = null;
        });
      }
    }
  }

  String _errorMessage(Object error) {
    final String message = error.toString();

    return message
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }
}

class _PointsExchangeClosedView extends StatelessWidget {
  const _PointsExchangeClosedView();

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: MemberSectionCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: theme.primarySoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.storefront_outlined,
                    size: 30,
                    color: theme.primaryColor,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '點數商城目前未開放',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.titleColor,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '店家目前沒有開放會員使用點數兌換商品。',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: theme.subtitleColor),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PointBalanceCard extends StatelessWidget {
  const _PointBalanceCard({required this.points});

  final int points;

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MemberUi.radius),
        gradient: theme.heroGradient,
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.onPrimaryColor.withValues(alpha: 0.16),
            child: Icon(
              Icons.paid_outlined,
              color: theme.onPrimaryColor,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '目前可使用點數',
                  style: TextStyle(
                    color: theme.onPrimaryColor.withValues(alpha: 0.82),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$points 點',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                    color: theme.onPrimaryColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({
    required this.reward,
    required this.currentPoints,
    required this.memberExchangedCount,
    required this.isExchanging,
    required this.onExchange,
  });

  final PointRewardModel reward;
  final int currentPoints;
  final int memberExchangedCount;
  final bool isExchanging;
  final VoidCallback onExchange;

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    final bool hasEnoughPoints = currentPoints >= reward.pointsCost;
    final int pointsShort = reward.pointsCost - currentPoints;
    final bool isSoldOut = reward.isSoldOut;
    final bool hasReachedMemberLimit =
        reward.exchangeLimitPerMember > 0 &&
        memberExchangedCount >= reward.exchangeLimitPerMember;

    final bool canExchange =
        hasEnoughPoints &&
        !isSoldOut &&
        !hasReachedMemberLimit &&
        !isExchanging;

    return MemberSectionCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (reward.isPhysicalProduct) ...<Widget>[
                  _PhysicalRewardThumbnail(imageUrl: reward.imageUrl),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: _buildRewardDetails(
                    context: context,
                    memberExchangedCount: memberExchangedCount,
                  ),
                ),
                const SizedBox(width: 8),
                _RewardPointsBadge(pointsCost: reward.pointsCost),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canExchange ? onExchange : null,
                style: FilledButton.styleFrom(
                  backgroundColor: theme.buttonColor,
                  foregroundColor: theme.onPrimaryColor,
                  disabledBackgroundColor: theme.disabledColor,
                  disabledForegroundColor: ShopFrontendTheme.contrastOn(
                    theme.disabledColor,
                  ),
                ),
                child: isExchanging
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.onPrimaryColor,
                        ),
                      )
                    : Text(
                        isSoldOut
                            ? '庫存不足'
                            : hasReachedMemberLimit
                            ? '已達個人兌換上限'
                            : hasEnoughPoints
                            ? reward.isPhysicalProduct
                                  ? '使用 ${reward.pointsCost} 點兌換商品'
                                  : '使用 ${reward.pointsCost} 點兌換'
                            : '尚差 $pointsShort 點',
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardDetails({
    required BuildContext context,
    required int memberExchangedCount,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          reward.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: ShopFrontendTheme.of(context).titleColor,
          ),
        ),
        if (reward.description.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 5),
          Text(
            reward.description.trim(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              color: ShopFrontendTheme.of(context).subtitleColor,
            ),
          ),
        ],
        const SizedBox(height: 8),
        _RewardInfoRow(
          icon: reward.isPhysicalProduct
              ? Icons.inventory_2_outlined
              : Icons.confirmation_number_outlined,
          text: reward.isPhysicalProduct ? '實體商品' : _rewardContentText(reward),
        ),
        const SizedBox(height: 5),
        _RewardInfoRow(
          icon: Icons.calendar_month_outlined,
          text: reward.validDays > 0 ? '兌換後 ${reward.validDays} 天內有效' : '永久有效',
        ),
        if (reward.exchangeLimitPerMember > 0) ...<Widget>[
          const SizedBox(height: 5),
          _RewardInfoRow(
            icon: Icons.person_outline,
            text:
                '你已兌換 $memberExchangedCount / '
                '${reward.exchangeLimitPerMember} 次',
          ),
        ],
        if (reward.isPhysicalProduct) ...<Widget>[
          const SizedBox(height: 5),
          _RewardInfoRow(
            icon: Icons.inventory_outlined,
            text: reward.hasStockLimit
                ? reward.isSoldOut
                      ? '目前無庫存'
                      : '剩餘庫存 ${reward.remainingStock ?? 0} 份'
                : reward.usesCentralInventory
                ? '使用店家中央庫存'
                : '庫存不限',
          ),
        ],
        if (reward.isPhysicalProduct &&
            reward.fulfillmentNote.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 5),
          _RewardInfoRow(
            icon: Icons.storefront_outlined,
            text: reward.fulfillmentNote.trim(),
          ),
        ],
        if (reward.totalExchangeLimit > 0) ...<Widget>[
          const SizedBox(height: 5),
          _RewardInfoRow(
            icon: Icons.inventory_2_outlined,
            text: reward.isSoldOut
                ? '已兌換完畢'
                : '剩餘 ${reward.totalExchangeLimit - reward.exchangedCount} 份',
          ),
        ],
      ],
    );
  }

  String _rewardContentText(PointRewardModel reward) {
    switch (reward.couponType) {
      case MemberCouponType.fixedAmount:
        return '折抵 NT\$ ${reward.discountValue.toInt()}';

      case MemberCouponType.percent:
        return '折抵 ${_numberText(reward.discountValue)}%';

      case MemberCouponType.freeStay:
        return '免費住宿 ${reward.freeStayNights} 晚';

      case MemberCouponType.freeService:
        return reward.serviceName.trim().isEmpty
            ? '免費指定服務'
            : '免費 ${reward.serviceName.trim()}';
    }
  }

  String _numberText(num value) {
    if (value == value.toInt()) {
      return value.toInt().toString();
    }

    return value.toString();
  }
}

class _PhysicalRewardThumbnail extends StatelessWidget {
  const _PhysicalRewardThumbnail({required this.imageUrl});

  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    final String normalizedImageUrl = imageUrl.trim();

    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    return Container(
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: theme.primarySoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: normalizedImageUrl.isEmpty
          ? Icon(
              Icons.inventory_2_outlined,
              size: 36,
              color: theme.primaryColor,
            )
          : Image.network(
              normalizedImageUrl,
              fit: BoxFit.cover,
              loadingBuilder:
                  (
                    BuildContext context,
                    Widget child,
                    ImageChunkEvent? loadingProgress,
                  ) {
                    if (loadingProgress == null) {
                      return child;
                    }

                    return const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
              errorBuilder:
                  (BuildContext context, Object error, StackTrace? stackTrace) {
                    return Icon(
                      Icons.broken_image_outlined,
                      size: 36,
                      color: ShopFrontendTheme.of(context).subtitleColor,
                    );
                  },
            ),
    );
  }
}

class _RewardPointsBadge extends StatelessWidget {
  const _RewardPointsBadge({required this.pointsCost});

  final int pointsCost;

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme theme = ShopFrontendTheme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: theme.primarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        '$pointsCost 點',
        style: TextStyle(
          fontSize: 13,
          color: theme.primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _RewardInfoRow extends StatelessWidget {
  const _RewardInfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 18,
          color: ShopFrontendTheme.of(context).subtitleColor,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: ShopFrontendTheme.of(context).bodyTextColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _EmptyRewardCard extends StatelessWidget {
  const _EmptyRewardCard({
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return MemberEmptyState(icon: icon, title: title, message: description);
  }
}
