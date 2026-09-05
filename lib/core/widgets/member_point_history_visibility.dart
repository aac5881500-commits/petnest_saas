// 檔案名稱：lib/core/widgets/member_point_history_visibility.dart
// 功能說明：依店家點數總開關及指定會員是否有點數、流水或兌換紀錄
// 🪙 會員點數歷史顯示判斷元件
// 決定顯示完整功能、唯讀內容或完全隱藏。
// 關閉點數制度不會刪除任何 Firestore 資料。

import 'package:flutter/material.dart';

import '../models/member_point_log_model.dart';
import '../models/member_point_model.dart';
import '../models/point_redemption_model.dart';
import '../models/point_setting_model.dart';
import '../services/member_point_service.dart';
import '../services/point_redemption_service.dart';
import '../services/point_setting_service.dart';

class MemberPointHistoryVisibility extends StatelessWidget {
  const MemberPointHistoryVisibility({
    super.key,
    required this.shopId,
    required this.userId,
    required this.enabledChild,
    required this.historyChild,
    this.emptyChild = const SizedBox.shrink(),
    this.loadingChild = const SizedBox.shrink(),
    this.errorChild = const SizedBox.shrink(),
  });

  /// 店家 ID
  final String shopId;

  /// 會員 UID
  final String userId;

  /// 店家目前啟用點數制度時顯示的完整功能
  final Widget enabledChild;

  /// 店家目前關閉，但會員有點數歷史時顯示的唯讀內容
  final Widget historyChild;

  /// 店家關閉，而且會員完全沒有點數資料時顯示的內容
  ///
  /// 預設完全隱藏。
  final Widget emptyChild;

  /// 資料載入期間顯示的內容
  final Widget loadingChild;

  /// 資料讀取失敗時顯示的內容
  final Widget errorChild;

  @override
  Widget build(BuildContext context) {
    final String normalizedShopId = shopId.trim();
    final String normalizedUserId = userId.trim();

    if (normalizedShopId.isEmpty || normalizedUserId.isEmpty) {
      return emptyChild;
    }

    return StreamBuilder<PointSettingModel>(
      stream: PointSettingService.instance.streamPointSetting(normalizedShopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<PointSettingModel> settingSnapshot,
          ) {
            if (settingSnapshot.hasError) {
              return errorChild;
            }

            if (!settingSnapshot.hasData) {
              return loadingChild;
            }

            final PointSettingModel setting = settingSnapshot.data!;

            // 點數制度目前啟用，直接顯示完整功能。
            if (setting.enabled) {
              return enabledChild;
            }

            return StreamBuilder<MemberPointModel>(
              stream: MemberPointService.instance.streamMemberPoint(
                shopId: normalizedShopId,
                userId: normalizedUserId,
              ),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<MemberPointModel> pointSnapshot,
                  ) {
                    if (pointSnapshot.hasError) {
                      return errorChild;
                    }

                    if (!pointSnapshot.hasData) {
                      return loadingChild;
                    }

                    final MemberPointModel memberPoint = pointSnapshot.data!;

                    final bool hasPointSummary =
                        memberPoint.currentPoints != 0 ||
                        memberPoint.totalEarnedPoints != 0 ||
                        memberPoint.totalUsedPoints != 0 ||
                        memberPoint.totalExpiredPoints != 0;

                    if (hasPointSummary) {
                      return historyChild;
                    }

                    return StreamBuilder<List<MemberPointLogModel>>(
                      stream: MemberPointService.instance.streamMemberPointLogs(
                        shopId: normalizedShopId,
                        userId: normalizedUserId,
                      ),
                      builder:
                          (
                            BuildContext context,
                            AsyncSnapshot<List<MemberPointLogModel>>
                            logSnapshot,
                          ) {
                            if (logSnapshot.hasError) {
                              return errorChild;
                            }

                            if (!logSnapshot.hasData) {
                              return loadingChild;
                            }

                            if (logSnapshot.data!.isNotEmpty) {
                              return historyChild;
                            }

                            return StreamBuilder<List<PointRedemptionModel>>(
                              stream: PointRedemptionService.instance
                                  .streamMemberRedemptions(
                                    shopId: normalizedShopId,
                                    userId: normalizedUserId,
                                  ),
                              builder:
                                  (
                                    BuildContext context,
                                    AsyncSnapshot<List<PointRedemptionModel>>
                                    redemptionSnapshot,
                                  ) {
                                    if (redemptionSnapshot.hasError) {
                                      return errorChild;
                                    }

                                    if (!redemptionSnapshot.hasData) {
                                      return loadingChild;
                                    }

                                    if (redemptionSnapshot.data!.isNotEmpty) {
                                      return historyChild;
                                    }

                                    return emptyChild;
                                  },
                            );
                          },
                    );
                  },
            );
          },
    );
  }
}
