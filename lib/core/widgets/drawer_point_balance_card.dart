// 檔案名稱：lib/core/widgets/drawer_point_balance_card.dart
// 功能說明：點數制度啟用時，顯示會員在目前店家的點數餘額。
// 🪙 左側選單會員點數卡片
// 點數制度關閉或會員未登入時完全隱藏，不刪除任何點數資料。

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/member_point_model.dart';
import '../services/member_point_service.dart';
import 'point_module_visibility.dart';

class DrawerPointBalanceCard extends StatelessWidget {
  const DrawerPointBalanceCard({
    super.key,
    required this.shopId,
    required this.primaryColor,
    required this.textColor,
    required this.cardColor,
    required this.borderColor,
    required this.onTap,
  });

  /// 店家 ID
  final String shopId;

  /// 卡片主色
  final Color primaryColor;

  /// 主要文字顏色
  final Color textColor;

  /// 卡片背景色
  final Color cardColor;

  /// 卡片邊框顏色
  final Color borderColor;

  /// 點擊卡片後執行
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;
    final String normalizedShopId = shopId.trim();

    if (user == null || normalizedShopId.isEmpty) {
      return const SizedBox.shrink();
    }

    return PointModuleVisibility(
      shopId: normalizedShopId,

      // 左側欄只依點數制度總開關顯示。
      // 關閉時不管會員有沒有歷史紀錄，整張卡都隱藏。
      enabledChild: StreamBuilder<MemberPointModel>(
        stream: MemberPointService.instance.streamMemberPoint(
          shopId: normalizedShopId,
          userId: user.uid,
        ),
        builder:
            (BuildContext context, AsyncSnapshot<MemberPointModel> snapshot) {
              final int currentPoints = snapshot.data?.currentPoints ?? 0;

              return Padding(
                padding: const EdgeInsets.only(top: 6, bottom: 2),
                child: Material(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: onTap,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: borderColor),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.stars_rounded,
                              size: 18,
                              color: primaryColor,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '目前點數',
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.72),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '$currentPoints 點',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    height: 1.15,
                                  ),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  '查看點數與紀錄',
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: textColor.withValues(alpha: 0.55),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
      ),

      historyChild: const SizedBox.shrink(),
      neverUsedChild: const SizedBox.shrink(),
    );
  }
}
