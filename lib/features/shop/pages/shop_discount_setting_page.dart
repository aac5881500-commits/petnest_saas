// lib/features/shop/pages/shop_discount_setting_page.dart
// 🎯 店家優惠設定入口頁
// 功能：集中管理自動優惠活動與優惠券模板，
// 作為「收款與優惠設定」中的優惠設定首頁。

import 'package:flutter/material.dart';
import '../../../core/widgets/point_module_visibility.dart';
import 'package:petnest_saas/features/admin/pages/admin_coupon_template_list_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_point_exchange_history_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_point_redemption_list_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_point_reward_list_page.dart';
import 'package:petnest_saas/features/shop/pages/shop_discount_campaign_page.dart';

class ShopDiscountSettingPage extends StatelessWidget {
  const ShopDiscountSettingPage({
    super.key,
    required this.shopId,
    this.embedded = false,
  });

  final String shopId;

  /// true：嵌入「收款與優惠設定」的 Tab，不顯示自己的 AppBar。
  /// false：作為獨立頁面使用。
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final Widget content = ListView(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 40),
      children: <Widget>[
        const _PageIntroduction(),
        const SizedBox(height: 20),

        _SettingEntryCard(
          icon: Icons.local_offer_outlined,
          title: '自動優惠活動',
          description: '設定新會員、長住、特定住宿日期、指定房型、滿額及限時下單優惠。',
          tags: const <String>['自動計算', '訂單直接折抵'],
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) {
                  return ShopDiscountCampaignPage(shopId: shopId);
                },
              ),
            );
          },
        ),

        const SizedBox(height: 14),

        _SettingEntryCard(
          icon: Icons.confirmation_number_outlined,
          title: '優惠券模板',
          description: '製作固定金額券、百分比券、免費住宿券與免費服務券，供發券及點數兌換使用。',
          tags: const <String>['手動發券', '點數兌換', '自動贈券'],
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (BuildContext context) {
                  return AdminCouponTemplateListPage(shopId: shopId);
                },
              ),
            );
          },
        ),

        const SizedBox(height: 14),

        PointModuleVisibility(
          shopId: shopId,
          enabledChild: Column(
            children: <Widget>[
              _SettingEntryCard(
                icon: Icons.redeem_outlined,
                title: '點數兌換商品管理',
                description: '建立及管理會員可使用點數兌換的優惠券、住宿券與實體商品。',
                tags: const <String>['新增商品', '編輯商品', '上下架'],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return AdminPointRewardListPage(shopId: shopId);
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              _SettingEntryCard(
                icon: Icons.inventory_2_outlined,
                title: '實體商品核銷中心',
                description: '查看待領取商品、輸入領取碼搜尋、完成交付、取消兌換及退回點數。',
                tags: const <String>['待領取', '完成交付', '取消退點'],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return AdminPointRedemptionListPage(shopId: shopId);
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),

              _SettingEntryCard(
                icon: Icons.history_outlined,
                title: '點數兌換紀錄',
                description: '查看會員兌換商品、扣除點數、剩餘點數及優惠券發放結果。',
                tags: const <String>['兌換紀錄', '扣點紀錄', '發券結果'],
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) {
                        return AdminPointExchangeHistoryPage(shopId: shopId);
                      },
                    ),
                  );
                },
              ),

              const SizedBox(height: 14),
            ],
          ),
        ),

        const SizedBox(height: 14),

        const _FutureFeatureNotice(),
      ],
    );

    if (embedded) {
      return ColoredBox(color: Colors.grey.shade100, child: content);
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(title: const Text('優惠設定')),
      body: content,
    );
  }
}

class _PageIntroduction extends StatelessWidget {
  const _PageIntroduction();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(
          context,
        ).colorScheme.primaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.campaign_outlined, size: 28),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '行銷與優惠工具',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text(
                  '自動優惠會在訂單符合條件時直接折抵；'
                  '優惠券則會先發給會員，再由會員於適用流程中使用。',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingEntryCard extends StatelessWidget {
  const _SettingEntryCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.tags,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final List<String> tags;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = Theme.of(context).colorScheme.primary;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: primaryColor, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        height: 1.45,
                      ),
                    ),
                    if (tags.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: tags.map((String tag) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 9,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              tag,
                              style: TextStyle(
                                color: Colors.grey.shade700,
                                fontSize: 12,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Icon(Icons.chevron_right),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FutureFeatureNotice extends StatelessWidget {
  const _FutureFeatureNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.blueGrey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.blueGrey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, color: Colors.blueGrey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '手動發券、點數兌換及新會員自動贈券，'
              '後續都會共用這裡建立的優惠券模板。',
              style: TextStyle(color: Colors.blueGrey.shade700, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}
