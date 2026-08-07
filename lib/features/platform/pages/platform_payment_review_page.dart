// lib/features/platform/pages/platform_payment_review_page.dart
// 💳 平台綠界金流審核列表頁
// 功能：平台最高權限查看所有店家的綠界金流申請、
// 審核狀態、付款方式與公開的 MerchantID。
// 注意：HashKey 與 HashIV 不會在此頁面直接讀取或顯示。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/platform_permission_keys.dart';
import '../../../core/services/platform_admin_service.dart';

class PlatformPaymentReviewPage extends StatelessWidget {
  const PlatformPaymentReviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: PlatformAdminService.instance.hasPermission(
        PlatformPermissionKeys.reviewPaymentApplications,
      ),
      builder: (context, permissionSnapshot) {
        if (permissionSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF6F7FB),
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (permissionSnapshot.hasError) {
          return Scaffold(
            backgroundColor: const Color(0xFFF6F7FB),
            appBar: AppBar(title: const Text('綠界金流審核中心')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  '讀取平台權限失敗：${permissionSnapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ),
          );
        }

        final canReviewPayments = permissionSnapshot.data ?? false;

        if (!canReviewPayments) {
          return Scaffold(
            backgroundColor: const Color(0xFFF6F7FB),
            appBar: AppBar(title: const Text('綠界金流審核中心')),
            body: const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.lock_outline, size: 56, color: Colors.orange),
                    SizedBox(height: 16),
                    Text(
                      '你沒有審核金流申請的權限',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '請由根管理員或其他授權人員分配「審核金流申請」權限。',
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        return Scaffold(
          backgroundColor: const Color(0xFFF6F7FB),
          appBar: AppBar(title: const Text('綠界金流審核中心')),
          body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance.collection('shops').snapshots(),
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
                          '讀取金流申請失敗：${snapshot.error}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                  shops =
                      snapshot.data?.docs.where((document) {
                        final Map<String, dynamic> shop = document.data();
                        final dynamic rawPaymentSetting =
                            shop['paymentSetting'];

                        if (rawPaymentSetting is! Map) {
                          return false;
                        }

                        final Map<String, dynamic> paymentSetting =
                            Map<String, dynamic>.from(rawPaymentSetting);

                        final String reviewStatus =
                            (paymentSetting['reviewStatus'] ?? '')
                                .toString()
                                .trim();

                        return reviewStatus.isNotEmpty &&
                            reviewStatus != 'notSubmitted';
                      }).toList() ??
                      <QueryDocumentSnapshot<Map<String, dynamic>>>[];

                  shops.sort((
                    QueryDocumentSnapshot<Map<String, dynamic>> first,
                    QueryDocumentSnapshot<Map<String, dynamic>> second,
                  ) {
                    final int firstOrder = _statusSortOrder(first.data());
                    final int secondOrder = _statusSortOrder(second.data());

                    return firstOrder.compareTo(secondOrder);
                  });

                  if (shops.isEmpty) {
                    return const _EmptyPaymentReviewView();
                  }

                  final int pendingCount = shops.where((document) {
                    final Map<String, dynamic> paymentSetting =
                        _paymentSettingFromShop(document.data());

                    return paymentSetting['reviewStatus'] == 'pending';
                  }).length;

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: <Widget>[
                      _SummaryCard(
                        totalCount: shops.length,
                        pendingCount: pendingCount,
                      ),
                      const SizedBox(height: 16),
                      ...shops.map((document) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _PaymentReviewCard(
                            shopId: document.id,
                            shop: document.data(),
                          ),
                        );
                      }),
                    ],
                  );
                },
          ),
        );
      },
    );
  }

  /// 📋 將店家資料中的 paymentSetting 安全轉換成 Map
  static Map<String, dynamic> _paymentSettingFromShop(
    Map<String, dynamic> shop,
  ) {
    final dynamic rawPaymentSetting = shop['paymentSetting'];

    return rawPaymentSetting is Map
        ? Map<String, dynamic>.from(rawPaymentSetting)
        : <String, dynamic>{};
  }

  /// 🔢 待審核優先顯示，其次退件、核准、停用
  static int _statusSortOrder(Map<String, dynamic> shop) {
    final Map<String, dynamic> paymentSetting = _paymentSettingFromShop(shop);

    final String reviewStatus = (paymentSetting['reviewStatus'] ?? '')
        .toString();

    switch (reviewStatus) {
      case 'pending':
        return 0;
      case 'rejected':
        return 1;
      case 'approved':
        return 2;
      case 'disabled':
        return 3;
      default:
        return 4;
    }
  }
}

/// 📊 金流申請統計卡片
class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.totalCount, required this.pendingCount});

  final int totalCount;
  final int pendingCount;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: <Widget>[
            const CircleAvatar(
              radius: 24,
              backgroundColor: Color(0xFFE8F5E9),
              child: Icon(Icons.payments_outlined, color: Colors.green),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '綠界金流申請',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '共 $totalCount 間店家，待審核 $pendingCount 件',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
            if (pendingCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$pendingCount',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 💳 單一店家的金流審核資料卡片
class _PaymentReviewCard extends StatelessWidget {
  const _PaymentReviewCard({required this.shopId, required this.shop});

  final String shopId;
  final Map<String, dynamic> shop;

  /// ✅ 平台核准店家的綠界金流申請
  ///
  /// 功能：
  /// - 顯示二次確認視窗
  /// - 呼叫 approveEcpayPaymentSetting Cloud Function
  /// - 成功後顯示操作結果
  Future<void> _approvePaymentSetting(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('確認核准金流申請'),
          content: const Text(
            '核准後，店家的綠界金流將正式啟用，'
            '會員付款頁之後可顯示已核准的付款方式。',
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
              child: const Text('確認核准'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !context.mounted) {
      return;
    }

    try {
      final FirebaseFunctions functions = FirebaseFunctions.instanceFor(
        region: 'asia-east1',
      );

      final HttpsCallable callable = functions.httpsCallable(
        'approveEcpayPaymentSetting',
        options: HttpsCallableOptions(timeout: const Duration(seconds: 60)),
      );

      await callable.call<dynamic>(<String, dynamic>{'shopId': shopId});

      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('店家綠界金流已核准')));
    } on FirebaseFunctionsException catch (error) {
      if (!context.mounted) {
        return;
      }

      final String message = error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : '核准金流申請失敗，請稍後再試。';

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!context.mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('核准金流申請時發生錯誤，請稍後再試。')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic> paymentSetting = _paymentSettingFromShop(shop);

    final Map<String, dynamic> enabledMethods =
        _enabledMethodsFromPaymentSetting(paymentSetting);

    final String shopName = _resolveShopName(shop);
    final String merchantName = (paymentSetting['merchantName'] ?? '')
        .toString();
    final String merchantId = (paymentSetting['merchantId'] ?? '').toString();
    final String environment = (paymentSetting['environment'] ?? 'test')
        .toString();
    final String reviewStatus =
        (paymentSetting['reviewStatus'] ?? 'notSubmitted').toString();

    final _ReviewStatusView statusView = _ReviewStatusView.fromStatus(
      reviewStatus,
    );

    final List<String> enabledMethodNames = <String>[
      if (enabledMethods['creditCard'] == true) '信用卡',
      if (enabledMethods['atm'] == true) 'ATM',
      if (enabledMethods['cvsCode'] == true) '超商代碼',
    ];

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const CircleAvatar(
                  backgroundColor: Color(0xFFEAF3FF),
                  child: Icon(
                    Icons.storefront_outlined,
                    color: Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        shopName,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Shop ID：$shopId',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: statusView.backgroundColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    statusView.text,
                    style: TextStyle(
                      color: statusView.foregroundColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 28),
            _InformationRow(
              label: '綠界商店名稱',
              value: merchantName.isEmpty ? '未填寫' : merchantName,
            ),
            _InformationRow(
              label: 'MerchantID',
              value: merchantId.isEmpty ? '未填寫' : merchantId,
            ),
            _InformationRow(
              label: '環境',
              value: environment == 'production' ? '正式環境' : '測試環境',
            ),
            _InformationRow(
              label: '付款方式',
              value: enabledMethodNames.isEmpty
                  ? '未選擇'
                  : enabledMethodNames.join('、'),
            ),
            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // 下一步做查看詳情
                    },
                    icon: const Icon(Icons.visibility_outlined),
                    label: const Text('查看'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: reviewStatus == 'pending'
                        ? () {
                            _approvePaymentSetting(context);
                          }
                        : null,
                    icon: const Icon(Icons.check_circle_outline),
                    label: const Text('核准'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: reviewStatus == 'pending'
                        ? () {
                            // 下一步做退件
                          }
                        : null,
                    icon: const Icon(Icons.close),
                    label: const Text('退件'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton.tonalIcon(
                    onPressed: reviewStatus == 'approved'
                        ? () {
                            // 下一步做停用
                          }
                        : null,
                    icon: const Icon(Icons.block),
                    label: const Text('停用'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Map<String, dynamic> _paymentSettingFromShop(
    Map<String, dynamic> shop,
  ) {
    final dynamic rawPaymentSetting = shop['paymentSetting'];

    return rawPaymentSetting is Map
        ? Map<String, dynamic>.from(rawPaymentSetting)
        : <String, dynamic>{};
  }

  static Map<String, dynamic> _enabledMethodsFromPaymentSetting(
    Map<String, dynamic> paymentSetting,
  ) {
    final dynamic rawEnabledMethods = paymentSetting['enabledMethods'];

    final Map<String, dynamic> enabledMethods = rawEnabledMethods is Map
        ? Map<String, dynamic>.from(rawEnabledMethods)
        : <String, dynamic>{};

    return <String, dynamic>{
      'creditCard':
          enabledMethods['creditCard'] == true ||
          paymentSetting['creditCardEnabled'] == true,
      'atm':
          enabledMethods['atm'] == true || paymentSetting['atmEnabled'] == true,
      'cvsCode':
          enabledMethods['cvsCode'] == true ||
          paymentSetting['cvsCodeEnabled'] == true,
    };
  }

  static String _resolveShopName(Map<String, dynamic> shop) {
    final List<dynamic> candidates = <dynamic>[
      shop['shopName'],
      shop['name'],
      shop['displayName'],
      shop['title'],
    ];

    for (final dynamic candidate in candidates) {
      final String value = (candidate ?? '').toString().trim();

      if (value.isNotEmpty) {
        return value;
      }
    }

    return '未命名店家';
  }
}

/// 🧾 審核資料顯示列
class _InformationRow extends StatelessWidget {
  const _InformationRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 96,
            child: Text(
              label,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// 🎨 審核狀態的文字與顏色
class _ReviewStatusView {
  const _ReviewStatusView({
    required this.text,
    required this.foregroundColor,
    required this.backgroundColor,
  });

  final String text;
  final Color foregroundColor;
  final Color backgroundColor;

  factory _ReviewStatusView.fromStatus(String status) {
    switch (status) {
      case 'pending':
        return const _ReviewStatusView(
          text: '等待審核',
          foregroundColor: Color(0xFF9A6700),
          backgroundColor: Color(0xFFFFF3CD),
        );

      case 'approved':
        return const _ReviewStatusView(
          text: '已核准',
          foregroundColor: Color(0xFF137333),
          backgroundColor: Color(0xFFE6F4EA),
        );

      case 'rejected':
        return const _ReviewStatusView(
          text: '已退件',
          foregroundColor: Color(0xFFB3261E),
          backgroundColor: Color(0xFFFCE8E6),
        );

      case 'disabled':
        return const _ReviewStatusView(
          text: '已停用',
          foregroundColor: Color(0xFF4B5563),
          backgroundColor: Color(0xFFE5E7EB),
        );

      default:
        return const _ReviewStatusView(
          text: '未知狀態',
          foregroundColor: Color(0xFF4B5563),
          backgroundColor: Color(0xFFE5E7EB),
        );
    }
  }
}

/// 📭 尚無金流申請
class _EmptyPaymentReviewView extends StatelessWidget {
  const _EmptyPaymentReviewView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.payments_outlined, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              '目前沒有綠界金流申請',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              '店家送出綠界金流設定後，申請會顯示在這裡。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}
