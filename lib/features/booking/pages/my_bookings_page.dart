// lib/features/booking/pages/my_bookings_page.dart
// 📄 我的訂單頁
//
// 功能：
// - 顯示目前登入會員的所有訂單
// - 訂單卡片顯示房號 / 日期 / 寵物數 / 中文狀態 / 總金額
// - 點擊訂單卡片可直接進入訂單詳細頁
// - 狀態不顯示英文，統一轉成客戶看得懂的中文

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/features/shop/pages/shop_public_page.dart';
import 'booking_detail_page.dart';

class MyBookingsPage extends StatefulWidget {
  const MyBookingsPage({super.key, this.returnShopId});

  final String? returnShopId;

  @override
  State<MyBookingsPage> createState() => _MyBookingsPageState();
}

class _MyBookingsPageState extends State<MyBookingsPage> {
  int _limit = 5;
  bool _checkingHistoryMergedNotice = false;
  bool _historyNoticeCheckedOnce = false;

  String _bookingStatusText(Map<String, dynamic> data) {
    final status = (data['status'] ?? '').toString();
    final depositStatus = (data['depositStatus'] ?? '').toString();
    final paymentMethod = (data['paymentMethod'] ?? '').toString();

    final depositAmountRaw = data['depositAmount'];
    final int depositAmount = depositAmountRaw is int
        ? depositAmountRaw
        : depositAmountRaw is double
        ? depositAmountRaw.round()
        : 0;

    final bool hasDeposit = depositAmount > 0;
    final bool isBankTransfer =
        paymentMethod == 'transfer' ||
        paymentMethod == 'bank_transfer' ||
        paymentMethod == 'bankTransfer' ||
        paymentMethod == '銀行轉帳';

    if (status == 'completed') {
      return '已完成';
    }

    if (status == 'cancelled') {
      return '已取消';
    }

    if (status == 'checked_in') {
      return '入住中';
    }

    if (status == 'confirmed') {
      return '已確認';
    }

    if (depositStatus == 'pending_review') {
      return hasDeposit ? '已付款・待確認' : '已回傳轉帳';
    }

    if (hasDeposit) {
      return '需支付訂金';
    }

    if (isBankTransfer) {
      return '尚未轉帳';
    }

    return '待店家確認';
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '';

    DateTime? date;

    if (value is Timestamp) {
      date = value.toDate();
    } else if (value is DateTime) {
      date = value;
    }

    if (date == null) return '';

    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');

    return '$y-$m-$d $hh:$mm';
  }

  int _getPetCount(Map<String, dynamic> data) {
    final petIds = data['petIds'];
    if (petIds is List) return petIds.length;

    final pets = data['pets'];
    if (pets is List) return pets.length;

    return 0;
  }

  int _getTotalPrice(Map<String, dynamic> data) {
    final totalPrice = data['totalPrice'];
    if (totalPrice is int) return totalPrice;
    if (totalPrice is double) return totalPrice.round();

    final totalAmount = data['totalAmount'];
    if (totalAmount is int) return totalAmount;
    if (totalAmount is double) return totalAmount.round();

    return 0;
  }

  Future<void> _checkHistoryMergedNotice({
    required String shopId,
    required String userId,
  }) async {
    if (_checkingHistoryMergedNotice || _historyNoticeCheckedOnce) return;

    _checkingHistoryMergedNotice = true;
    _historyNoticeCheckedOnce = true;

    try {
      final memberRef = FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('members')
          .doc(userId);

      final memberDoc = await memberRef.get();

      if (!memberDoc.exists) return;

      final memberData = memberDoc.data() ?? {};

      final shouldShow = memberData['historyMergedNoticeShown'] == false;
      final count = memberData['historyMergedBookingCount'] ?? 0;

      if (!shouldShow || count <= 0) return;
      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (_) {
          return AlertDialog(
            title: const Text('已同步歷史訂單'),
            content: Text(
              '已同步 $count 筆歷史住宿紀錄。\n\n'
              '這些訂單是在您使用 PetNest App 前，由店家協助建立，'
              '因此已同步到您的會員中心。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('我知道了'),
              ),
            ],
          );
        },
      );

      await memberRef.update({
        'historyMergedNoticeShown': true,
        'historyMergedNoticeShownAt': FieldValue.serverTimestamp(),
      });
    } finally {
      _checkingHistoryMergedNotice = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return const Scaffold(body: Center(child: Text('請先登入')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('我的訂單'),
        leading: IconButton(
          icon: const Icon(Icons.home),
          onPressed: () {
            final shopId = widget.returnShopId;

            if (shopId != null && shopId.isNotEmpty) {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(
                  builder: (_) => ShopPublicPage(shopId: shopId),
                ),
                (route) => false,
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: () {
          Query<Map<String, dynamic>> query = FirebaseFirestore.instance
              .collection('bookings')
              .where('userId', isEqualTo: user.uid);

          final String currentShopId = widget.returnShopId?.trim() ?? '';

          if (currentShopId.isNotEmpty) {
            query = query.where('shopId', isEqualTo: currentShopId);
          }

          return query
              .orderBy('createdAt', descending: true)
              .limit(30)
              .snapshots();
        }(),

        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('讀取失敗：${snapshot.error}'),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('目前沒有訂單'));
          }
          final docs = snapshot.data!.docs.toList();

          final firstData = docs.first.data() as Map<String, dynamic>;
          final firstShopId = (firstData['shopId'] ?? '').toString();

          if (firstShopId.isNotEmpty) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _checkHistoryMergedNotice(shopId: firstShopId, userId: user.uid);
            });
          }

          final visibleDocs = docs.take(_limit).toList();

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: visibleDocs.length + 1,
            itemBuilder: (context, index) {
              if (index == visibleDocs.length) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: OutlinedButton.icon(
                    onPressed: docs.length < _limit
                        ? null
                        : () {
                            setState(() {
                              _limit += 10;
                            });
                          },
                    icon: const Icon(Icons.expand_more),
                    label: Text(docs.length < _limit ? '沒有更多訂單了' : '載入更多訂單'),
                  ),
                );
              }
              final data = visibleDocs[index].data() as Map<String, dynamic>;

              final start = (data['startDate'] as Timestamp).toDate();
              final end = (data['endDate'] as Timestamp).toDate();

              final roomName = (data['roomName'] ?? '房型').toString();
              final roomTypeName =
                  (data['roomTypeName'] ?? data['roomName'] ?? '預約訂單')
                      .toString();

              final statusText = _bookingStatusText(data);
              final petCount = _getPetCount(data);
              final totalPrice = _getTotalPrice(data);
              final paymentMethod = (data['paymentMethod'] ?? '').toString();

              final depositAmount = (data['depositAmount'] ?? 0) as num;

              final depositExpireAt = data['depositExpireAt'];

              final paymentMethodText = paymentMethod == 'transfer'
                  ? '銀行轉帳'
                  : '現場付款';

              final depositExpireText = _formatDateTime(depositExpireAt);

              final bool hasDeposit = depositAmount > 0;
              final bookingCode = (data['bookingCode'] ?? '').toString();
              final shopName = (data['shopName'] ?? '').toString();
              final createdAtText = _formatDateTime(data['createdAt']);

              final source = (data['source'] ?? '').toString();

              final bool isAdminBooking =
                  source == 'admin' || source == 'manual';
              final shortBookingId = bookingCode.isNotEmpty
                  ? bookingCode
                  : (visibleDocs[index].id.length > 8
                        ? visibleDocs[index].id.substring(0, 8)
                        : visibleDocs[index].id);

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BookingDetailPage(
                          data: data,
                          docId: visibleDocs[index].id,
                        ),
                      ),
                    );
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 58,
                          height: 58,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.blueGrey.shade800,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Text(
                            roomName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),

                        const SizedBox(width: 12),

                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (shopName.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.storefront,
                                            size: 14,
                                            color: Colors.orange,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              shopName,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.orange,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (isAdminBooking)
                                    Padding(
                                      padding: const EdgeInsets.only(bottom: 4),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.badge_outlined,
                                            size: 14,
                                            color: Colors.orange.shade700,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '店家代為建立',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.orange.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  Text(
                                    roomTypeName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 4),

                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_formatDate(start)} → ${_formatDate(end)}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                    ),
                                  ),

                                  if (createdAtText.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2),
                                      child: Text(
                                        '下訂 $createdAtText',
                                        style: TextStyle(
                                          color: Colors.grey.shade500,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 6),

                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: [
                                  _SmallInfoChip(text: '#$shortBookingId'),
                                  _SmallInfoChip(text: '寵物 $petCount 隻'),
                                  _SmallInfoChip(text: paymentMethodText),
                                  if (hasDeposit)
                                    _SmallInfoChip(
                                      text: '訂金 NT\$ ${depositAmount.toInt()}',
                                    ),
                                  _StatusChip(text: statusText),
                                ],
                              ),

                              if (hasDeposit &&
                                  depositExpireText.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text(
                                  '付款期限：$depositExpireText',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.red,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              totalPrice > 0 ? 'NT\$ $totalPrice' : '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 10),
                            const Icon(Icons.chevron_right, size: 22),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.text});

  final String text;

  Color get backgroundColor {
    switch (text) {
      case '需支付訂金':
        return Colors.amber.shade100;

      case '尚未轉帳':
        return Colors.deepOrange.shade50;

      case '已回傳轉帳':
        return Colors.lightBlue.shade100;

      case '已付款・待確認':
        return Colors.orange.shade100;

      case '待店家確認':
        return Colors.blueGrey.shade100;

      case '已確認':
        return Colors.blue.shade100;

      case '入住中':
        return Colors.green.shade100;

      case '已完成':
        return Colors.grey.shade300;

      case '已取消':
        return Colors.red.shade100;

      default:
        return Colors.grey.shade100;
    }
  }

  Color get textColor {
    switch (text) {
      case '需支付訂金':
        return Colors.amber.shade900;

      case '尚未轉帳':
        return Colors.deepOrange.shade700;

      case '已回傳轉帳':
        return Colors.lightBlue.shade800;

      case '已付款・待確認':
        return Colors.orange.shade800;

      case '待店家確認':
        return Colors.blueGrey.shade800;

      case '已確認':
        return Colors.blue.shade800;

      case '入住中':
        return Colors.green.shade800;

      case '已完成':
        return Colors.grey.shade800;

      case '已取消':
        return Colors.red.shade800;

      default:
        return Colors.black87;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}

class _SmallInfoChip extends StatelessWidget {
  const _SmallInfoChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
