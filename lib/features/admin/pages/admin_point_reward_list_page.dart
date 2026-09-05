// 檔案名稱：lib/features/admin/pages/admin_point_reward_list_page.dart
// 功能說明：顯示點數兌換商品，並支援上下架與刪除尚未兌換的商品。
// 🎁 後台點數兌換商品管理頁

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/point_reward_model.dart';
import 'package:petnest_saas/core/services/point_reward_image_service.dart';
import 'package:petnest_saas/core/services/point_reward_service.dart';
import 'package:petnest_saas/features/admin/pages/admin_point_exchange_history_page.dart';
import 'package:petnest_saas/features/admin/pages/admin_point_redemption_list_page.dart';
import 'admin_point_reward_form_page.dart';

class AdminPointRewardListPage extends StatelessWidget {
  const AdminPointRewardListPage({super.key, required this.shopId});

  final String shopId;

  Future<void> _openRewardForm({
    required BuildContext context,
    PointRewardModel? reward,
  }) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) {
          return AdminPointRewardFormPage(shopId: shopId, reward: reward);
        },
      ),
    );
  }

  CollectionReference<Map<String, dynamic>> get _rewardCollection {
    return FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('point_rewards');
  }

  CollectionReference<Map<String, dynamic>> get _couponTemplateCollection {
    return FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId)
        .collection('coupon_templates');
  }

  Future<void> _toggleEnabled({
    required BuildContext context,
    required String rewardId,
    required bool enabled,
  }) async {
    try {
      await _rewardCollection.doc(rewardId).update({
        'enabled': enabled,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(enabled ? '商品已上架' : '商品已下架')));
    } catch (error) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('更新商品狀態失敗：$error')));
    }
  }

  Future<void> _deleteReward({
    required BuildContext context,
    required String rewardId,
    required String rewardName,
    required String imageUrl,
    required int exchangedCount,
  }) async {
    if (exchangedCount > 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已有會員兌換過的商品不能刪除，請改為下架')));
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('刪除兌換商品'),
          content: Text(
            imageUrl.trim().isEmpty
                ? '確定要刪除「$rewardName」嗎？'
                : '確定要刪除「$rewardName」嗎？\n\n商品圖片也會一起永久刪除。',
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(false);
              },
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text('刪除'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) {
      return;
    }

    try {
      await PointRewardService.instance.deleteReward(
        shopId: shopId,
        rewardId: rewardId,
      );

      bool imageDeleteFailed = false;

      if (imageUrl.trim().isNotEmpty) {
        try {
          await PointRewardImageService.instance.deleteImageByUrl(imageUrl);
        } catch (_) {
          imageDeleteFailed = true;
        }
      }

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            imageDeleteFailed ? '商品已刪除，但 Storage 圖片清理失敗，請稍後再檢查' : '兌換商品與圖片已刪除',
          ),
        ),
      );
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除商品失敗：$error')));
    }
  }

  Future<String> _getCouponTemplateName(String couponTemplateId) async {
    final String normalizedTemplateId = couponTemplateId.trim();

    if (normalizedTemplateId.isEmpty) {
      return '';
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _couponTemplateCollection.doc(normalizedTemplateId).get();

      final Map<String, dynamic>? data = snapshot.data();

      if (!snapshot.exists || data == null) {
        return '找不到優惠券模板';
      }

      final String templateName = (data['name'] ?? '').toString().trim();

      if (templateName.isEmpty) {
        return '未命名優惠券模板';
      }

      return templateName;
    } catch (_) {
      return '優惠券模板讀取失敗';
    }
  }

  String _couponTypeLabel(String couponType) {
    switch (couponType) {
      case 'fixedAmount':
        return '固定金額折價券';
      case 'percent':
        return '百分比折扣券';
      case 'freeStay':
        return '免費住宿券';
      case 'freeService':
        return '免費服務券';
      default:
        return '未設定券種';
    }
  }

  String _limitText({
    required int exchangedCount,
    required int totalExchangeLimit,
  }) {
    if (totalExchangeLimit <= 0) {
      return '已兌換 $exchangedCount 次・不限總數';
    }

    return '已兌換 $exchangedCount / $totalExchangeLimit 次';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('點數兌換商品管理'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) {
                    return AdminPointRedemptionListPage(shopId: shopId);
                  },
                ),
              );
            },
            icon: const Icon(Icons.inventory_2_outlined),
            label: const Text('核銷中心'),
          ),
          TextButton.icon(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) {
                    return AdminPointExchangeHistoryPage(shopId: shopId);
                  },
                ),
              );
            },
            icon: const Icon(Icons.history_outlined),
            label: const Text('兌換紀錄'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _rewardCollection.snapshots(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      '讀取點數商品失敗：${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              final List<QueryDocumentSnapshot<Map<String, dynamic>>>
              documents =
                  snapshot.data?.docs.toList() ??
                  <QueryDocumentSnapshot<Map<String, dynamic>>>[];

              documents.sort((
                QueryDocumentSnapshot<Map<String, dynamic>> first,
                QueryDocumentSnapshot<Map<String, dynamic>> second,
              ) {
                final int firstSortOrder =
                    (first.data()['sortOrder'] as num?)?.toInt() ?? 0;

                final int secondSortOrder =
                    (second.data()['sortOrder'] as num?)?.toInt() ?? 0;

                final int sortResult = firstSortOrder.compareTo(
                  secondSortOrder,
                );

                if (sortResult != 0) {
                  return sortResult;
                }

                final Timestamp? firstCreatedAt =
                    first.data()['createdAt'] as Timestamp?;

                final Timestamp? secondCreatedAt =
                    second.data()['createdAt'] as Timestamp?;

                return (secondCreatedAt?.millisecondsSinceEpoch ?? 0).compareTo(
                  firstCreatedAt?.millisecondsSinceEpoch ?? 0,
                );
              });

              if (documents.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          Icons.card_giftcard_outlined,
                          size: 72,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          '尚未建立點數兌換商品',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '建立商品後，會員可使用店家點數兌換優惠券或實體商品。',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                itemCount: documents.length,
                separatorBuilder: (BuildContext context, int index) {
                  return const SizedBox(height: 12);
                },
                itemBuilder: (BuildContext context, int index) {
                  final QueryDocumentSnapshot<Map<String, dynamic>> document =
                      documents[index];

                  final Map<String, dynamic> data = document.data();

                  final PointRewardModel reward = PointRewardModel.fromMap(
                    id: document.id,
                    data: data,
                  );

                  final String name = (data['name'] ?? '未命名商品').toString();

                  final String description = (data['description'] ?? '')
                      .toString();

                  final String couponType = (data['couponType'] ?? '')
                      .toString();

                  final String couponTemplateId =
                      (data['couponTemplateId'] ?? '').toString();

                  final int pointsCost =
                      (data['pointsCost'] as num?)?.toInt() ?? 0;

                  final int exchangedCount =
                      (data['exchangedCount'] as num?)?.toInt() ?? 0;

                  final int totalExchangeLimit =
                      (data['totalExchangeLimit'] as num?)?.toInt() ?? 0;

                  final int exchangeLimitPerMember =
                      (data['exchangeLimitPerMember'] as num?)?.toInt() ?? 0;

                  final int sortOrder =
                      (data['sortOrder'] as num?)?.toInt() ?? 0;

                  final bool enabled = data['enabled'] == true;

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
                                backgroundColor: enabled
                                    ? Colors.green.shade50
                                    : Colors.grey.shade200,
                                child: Icon(
                                  reward.isPhysicalProduct
                                      ? Icons.inventory_2_outlined
                                      : Icons.confirmation_number_outlined,
                                  color: enabled
                                      ? reward.isPhysicalProduct
                                            ? Colors.orange.shade700
                                            : Colors.green.shade700
                                      : Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (reward.isCouponReward)
                                      if (couponTemplateId.trim().isNotEmpty)
                                        FutureBuilder<String>(
                                          future: _getCouponTemplateName(
                                            couponTemplateId,
                                          ),
                                          builder:
                                              (
                                                BuildContext context,
                                                AsyncSnapshot<String>
                                                templateSnapshot,
                                              ) {
                                                if (templateSnapshot
                                                        .connectionState ==
                                                    ConnectionState.waiting) {
                                                  return Text(
                                                    '優惠券模板讀取中...',
                                                    style: TextStyle(
                                                      color:
                                                          Colors.grey.shade600,
                                                    ),
                                                  );
                                                }

                                                final String templateName =
                                                    templateSnapshot.data ??
                                                    '找不到優惠券模板';

                                                return Text(
                                                  '優惠券：$templateName',
                                                  style: TextStyle(
                                                    color: Colors.grey.shade700,
                                                  ),
                                                );
                                              },
                                        )
                                      else
                                        Text(
                                          _couponTypeLabel(couponType),
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                          ),
                                        )
                                    else if (reward.isPhysicalProduct)
                                      Text(
                                        '實體商品・櫃檯領取',
                                        style: TextStyle(
                                          color: Colors.orange.shade800,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      )
                                    else
                                      Text(
                                        '尚未支援的兌換類型',
                                        style: TextStyle(
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              Switch(
                                value: enabled,
                                onChanged: (bool value) {
                                  _toggleEnabled(
                                    context: context,
                                    rewardId: document.id,
                                    enabled: value,
                                  );
                                },
                              ),
                            ],
                          ),
                          if (description.isNotEmpty) ...<Widget>[
                            const SizedBox(height: 12),
                            Text(description),
                          ],
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              Chip(
                                avatar: const Icon(Icons.pets, size: 18),
                                label: Text('$pointsCost 點兌換'),
                              ),
                              if (reward.isPhysicalProduct)
                                Chip(
                                  avatar: const Icon(
                                    Icons.inventory_2_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    reward.stockQuantity <= 0
                                        ? '目前無庫存'
                                        : '庫存 ${reward.stockQuantity} 份',
                                  ),
                                ),

                              if (reward.isPhysicalProduct)
                                Chip(
                                  avatar: const Icon(
                                    Icons.verified_user_outlined,
                                    size: 18,
                                  ),
                                  label: Text(
                                    reward.requiresStaffVerification
                                        ? '需要店員核銷'
                                        : '不需店員核銷',
                                  ),
                                ),
                              Chip(
                                avatar: const Icon(Icons.sort, size: 18),
                                label: Text('排序 $sortOrder'),
                              ),
                              Chip(
                                label: Text(
                                  _limitText(
                                    exchangedCount: exchangedCount,
                                    totalExchangeLimit: totalExchangeLimit,
                                  ),
                                ),
                              ),
                              Chip(
                                label: Text(
                                  exchangeLimitPerMember <= 0
                                      ? '會員不限次數'
                                      : '每位會員限 $exchangeLimitPerMember 次',
                                ),
                              ),
                              Chip(label: Text(enabled ? '上架中' : '已下架')),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: <Widget>[
                              TextButton.icon(
                                onPressed: () {
                                  _openRewardForm(
                                    context: context,
                                    reward: reward,
                                  );
                                },
                                icon: const Icon(Icons.edit_outlined),
                                label: const Text('編輯'),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                onPressed: exchangedCount > 0
                                    ? null
                                    : () {
                                        _deleteReward(
                                          context: context,
                                          rewardId: document.id,
                                          rewardName: name,
                                          imageUrl: reward.imageUrl,
                                          exchangedCount: exchangedCount,
                                        );
                                      },
                                icon: const Icon(Icons.delete_outline),
                                label: const Text('刪除'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          _openRewardForm(context: context);
        },
        icon: const Icon(Icons.add),
        label: const Text('建立商品'),
      ),
    );
  }
}
