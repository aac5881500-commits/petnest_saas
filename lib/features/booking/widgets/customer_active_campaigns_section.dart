// 檔案名稱：lib/features/booking/widgets/customer_active_campaigns_section.dart
// 功能說明：客戶端公開優惠活動列表與預約第一步提示卡，只展示不重算折扣。

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/discount_campaign_model.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/discount_campaign_calculator.dart';
import 'package:petnest_saas/core/services/discount_campaign_customer_copy.dart';
import 'package:petnest_saas/core/services/discount_campaign_service.dart';

class CustomerCampaignBookingSnapshot {
  const CustomerCampaignBookingSnapshot({
    required this.selectionComplete,
    this.appliedCampaignId = '',
    this.appliedDiscountAmount = 0,
    this.eligibleCampaignIds = const <String>{},
  });

  final bool selectionComplete;
  final String appliedCampaignId;
  final int appliedDiscountAmount;
  final Set<String> eligibleCampaignIds;

  bool get hasApplied =>
      appliedCampaignId.isNotEmpty && appliedDiscountAmount > 0;
}

class CustomerBookingCampaignTeaser extends StatelessWidget {
  const CustomerBookingCampaignTeaser({
    super.key,
    required this.theme,
    required this.loading,
    required this.hasError,
    required this.campaigns,
    required this.snapshot,
    required this.onOpen,
    required this.onRetry,
  });

  final HomeThemeModel theme;
  final bool loading;
  final bool hasError;
  final List<DiscountCampaignModel> campaigns;
  final CustomerCampaignBookingSnapshot snapshot;
  final VoidCallback onOpen;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    if (hasError) {
      return _errorCard(theme: theme, onRetry: onRetry);
    }
    if (loading) {
      return _skeletonCard(theme);
    }
    if (campaigns.isEmpty) {
      return const SizedBox.shrink();
    }

    final String title;
    final String subtitle;
    if (!snapshot.selectionComplete) {
      title = '本店目前有 ${campaigns.length} 個優惠活動';
      subtitle = '選擇日期與房型後，系統會自動套用符合資格的優惠';
    } else if (snapshot.hasApplied) {
      DiscountCampaignModel? applied;
      for (final DiscountCampaignModel item in campaigns) {
        if (item.id == snapshot.appliedCampaignId) {
          applied = item;
          break;
        }
      }
      final String name = (applied?.name ?? '').trim().isEmpty
          ? '優惠活動'
          : applied!.name.trim();
      title = '已套用：$name';
      subtitle =
          '本次預估省 ${DiscountCampaignCustomerCopy.money(snapshot.appliedDiscountAmount)}';
    } else {
      title = '本店目前有優惠活動';
      subtitle = '目前選擇的日期、房型或金額尚無可套用優惠';
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: theme.cardBorderColor),
            ),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: theme.textColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: theme.textColor.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.local_offer_outlined,
                  color: theme.primaryColor,
                  size: 22,
                ),
                Icon(
                  Icons.chevron_right,
                  color: theme.textColor.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CustomerActiveCampaignsSection extends StatefulWidget {
  const CustomerActiveCampaignsSection({
    super.key,
    required this.shopId,
    required this.theme,
    this.showBookButton = false,
    this.onBookNow,
    this.bookingSnapshot,
    this.memberJoinedAt,
    this.isFirstBooking = false,
    this.memberCampaignUsedNights = const <String, int>{},
  });

  final String shopId;
  final HomeThemeModel theme;
  final bool showBookButton;
  final VoidCallback? onBookNow;
  final CustomerCampaignBookingSnapshot? bookingSnapshot;
  final DateTime? memberJoinedAt;
  final bool isFirstBooking;
  final Map<String, int> memberCampaignUsedNights;

  @override
  State<CustomerActiveCampaignsSection> createState() =>
      _CustomerActiveCampaignsSectionState();
}

class _CustomerActiveCampaignsSectionState
    extends State<CustomerActiveCampaignsSection> {
  int _retry = 0;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<DiscountCampaignModel>>(
      key: ValueKey<int>(_retry),
      stream: DiscountCampaignService.instance.streamPublicCampaigns(
        widget.shopId,
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<DiscountCampaignModel>> snapshot,
          ) {
            if (snapshot.hasError) {
              return Center(
                child: _errorCard(
                  theme: widget.theme,
                  onRetry: () {
                    setState(() {
                      _retry += 1;
                    });
                  },
                ),
              );
            }
            if (!snapshot.hasData) {
              return _skeletonList(widget.theme);
            }
            final List<DiscountCampaignModel> campaigns =
                snapshot.data ?? const <DiscountCampaignModel>[];
            if (campaigns.isEmpty) {
              return _emptyState(widget.theme);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              itemCount: campaigns.length,
              separatorBuilder: (BuildContext context, int index) =>
                  const SizedBox(height: 12),
              itemBuilder: (BuildContext context, int index) {
                return CustomerActiveCampaignCard(
                  campaign: campaigns[index],
                  theme: widget.theme,
                  showBookButton: widget.showBookButton,
                  onBookNow: widget.onBookNow,
                  bookingSnapshot: widget.bookingSnapshot,
                  isLoggedIn: FirebaseAuth.instance.currentUser != null,
                  memberJoinedAt: widget.memberJoinedAt,
                  isFirstBooking: widget.isFirstBooking,
                  usedNights:
                      widget.memberCampaignUsedNights[campaigns[index].id] ?? 0,
                );
              },
            );
          },
    );
  }
}

class CustomerActiveCampaignCard extends StatelessWidget {
  const CustomerActiveCampaignCard({
    super.key,
    required this.campaign,
    required this.theme,
    required this.isLoggedIn,
    this.showBookButton = false,
    this.onBookNow,
    this.bookingSnapshot,
    this.memberJoinedAt,
    this.isFirstBooking = false,
    this.usedNights = 0,
  });

  final DiscountCampaignModel campaign;
  final HomeThemeModel theme;
  final bool showBookButton;
  final VoidCallback? onBookNow;
  final CustomerCampaignBookingSnapshot? bookingSnapshot;
  final bool isLoggedIn;
  final DateTime? memberJoinedAt;
  final bool isFirstBooking;
  final int usedNights;

  @override
  Widget build(BuildContext context) {
    final bool newMemberOk =
        DiscountCampaignCalculator.isNewMemberEligibleForDisplay(
          campaign: campaign,
          isLoggedIn: isLoggedIn,
          memberJoinedAt: memberJoinedAt,
          isFirstBooking: isFirstBooking,
          usedNights: usedNights,
        );
    final List<String> chips = DiscountCampaignCustomerCopy.restrictionChips(
      campaign,
    );
    final CustomerCampaignBookingSnapshot? fit = bookingSnapshot;
    final String statusLine;
    if (campaign.type == DiscountCampaignType.newMember && !newMemberOk) {
      statusLine = '此優惠限新會員使用';
    } else if (fit == null || !fit.selectionComplete) {
      statusLine = '選擇日期與房型後，系統會自動判斷是否符合優惠';
    } else if (fit.appliedCampaignId == campaign.id && fit.hasApplied) {
      statusLine = '已套用';
    } else if (fit.eligibleCampaignIds.contains(campaign.id)) {
      statusLine = '符合資格，本次將套用折抵較高的活動';
    } else {
      statusLine = '目前不符合';
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cardBorderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            campaign.name.trim().isEmpty ? '優惠活動' : campaign.name.trim(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            DiscountCampaignCustomerCopy.benefitLine(campaign),
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              fontWeight: FontWeight.w700,
              color: theme.primaryColor,
            ),
          ),
          if (campaign.description.trim().isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              campaign.description.trim(),
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: theme.textColor.withValues(alpha: 0.72),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[for (final String chip in chips) _chip(chip)],
          ),
          const SizedBox(height: 10),
          Text(
            statusLine,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: statusLine == '已套用'
                  ? const Color(0xFF2E7D32)
                  : theme.textColor.withValues(alpha: 0.6),
              fontWeight: statusLine == '已套用'
                  ? FontWeight.w800
                  : FontWeight.w500,
            ),
          ),
          if (showBookButton && onBookNow != null) ...<Widget>[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onBookNow,
                child: const Text('立即預約'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.primaryColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: theme.textColor.withValues(alpha: 0.78),
        ),
      ),
    );
  }
}

Widget _skeletonCard(HomeThemeModel theme) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
    decoration: BoxDecoration(
      color: theme.cardColor,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: theme.cardBorderColor),
    ),
    child: const SizedBox(
      height: 42,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    ),
  );
}

Widget _skeletonList(HomeThemeModel theme) {
  return ListView(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
    children: <Widget>[
      _skeletonCard(theme),
      const SizedBox(height: 12),
      _skeletonCard(theme),
    ],
  );
}

Widget _emptyState(HomeThemeModel theme) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.local_offer_outlined,
            size: 42,
            color: theme.textColor.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          Text(
            '目前沒有進行中的優惠活動',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '店家推出新優惠時，會顯示在這裡。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: theme.textColor.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _errorCard({
  required HomeThemeModel theme,
  required VoidCallback onRetry,
}) {
  return Padding(
    padding: const EdgeInsets.all(24),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          '優惠活動暫時無法載入，請稍後再試',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: theme.textColor.withValues(alpha: 0.75),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('重試')),
      ],
    ),
  );
}
