// 檔案名稱：lib/features/admin/widgets/booking_order_card.dart
// 功能說明：後台訂單卡片（展開式升級版）
// 功能：
// - 預設顯示精簡訂單資訊
// - 點擊卡片展開顧客 / 寵物 / 付款 / 訂金資訊
// - 點擊「查看詳細」進入訂單詳細頁
// - 適合手機版後台快速掃描訂單

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';

class BookingOrderCard extends StatefulWidget {
  const BookingOrderCard({
    super.key,
    required this.bookingId,
    required this.data,
    required this.onTap,
  });

  final String bookingId;
  final Map<String, dynamic> data;
  final VoidCallback onTap;

  @override
  State<BookingOrderCard> createState() => _BookingOrderCardState();
}

class _BookingOrderCardState extends State<BookingOrderCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    final start = _toDate(data['startDate']);
    final end = _toDate(data['endDate']);

    final status = (data['status'] ?? 'pending').toString();
    final statusInfo = _statusInfo(status);

    final roomName = (data['roomName'] ?? '-').toString();

    final assignStatus = (data['assignStatus'] ?? 'assigned').toString();

    final isUnassigned = assignStatus == 'unassigned';

    final roomTypeName = (data['roomTypeName'] ?? '未設定房型').toString();

    final customerName = (data['customerName'] ?? '未填姓名').toString();
    final customerPhone = (data['customerPhone'] ?? '-').toString();

    final nights = data['nights'] ?? _calcNights(start, end);
    final bool daycare = BookingKind.isDaycare(data);

    final pets = (data['pets'] as List?) ?? [];
    final petNames = pets
        .map((e) {
          if (e is Map<String, dynamic>) {
            return (e['name'] ?? '').toString();
          }
          return '';
        })
        .where((name) => name.isNotEmpty)
        .join('、');

    final totalPrice = data['totalPrice'] ?? 0;
    final depositAmount = data['depositAmount'] ?? 0;
    final payAmountType = (data['payAmountType'] ?? 'deposit').toString();

    final paymentTitle = payAmountType == 'full' ? '全額' : '訂金';

    final paymentAmount = payAmountType == 'full' ? totalPrice : depositAmount;
    final depositPaid =
        data['depositPaid'] == true || data['depositStatus'] == 'confirmed';

    final depositStatus = (data['depositStatus'] ?? '').toString();
    final shopUnreadMessageCount = (data['shopUnreadMessageCount'] ?? 0) as int;

    final hasUnreadMessage = shopUnreadMessageCount > 0;

    final discountAmount = (data['discountAmount'] ?? 0) as num;
    final discountMinNights = (data['discountMinNights'] ?? 0) as num;
    final hasDiscount = discountAmount > 0;

    final isDepositReview = depositStatus == 'pending_review';

    final paymentMethod = _paymentMethodText(data['paymentMethod']);
    final createdAtText = _formatDateTime(data['createdAt']);
    final depositExpireText = _formatDateTime(data['depositExpireAt']);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.055),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () {
          setState(() {
            _expanded = !_expanded;
          });
        },
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 12, 12),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _roomBox(isUnassigned ? '待分' : roomName),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    roomTypeName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (data['bookingKind'] ?? '') == 'daycare'
                                        ? Colors.orange.shade50
                                        : Colors.blue.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    (data['bookingKind'] ?? '') == 'daycare'
                                        ? '臨托'
                                        : '住宿',
                                    style: const TextStyle(fontSize: 11),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                _statusChip(statusInfo),
                              ],
                            ),

                            const SizedBox(height: 6),

                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    daycare
                                        ? '${_formatDate(start)}  ${DaycareTimeHelper.formatHm(start)} → ${DaycareTimeHelper.formatHm(end)}'
                                        : '${_formatDate(start)} → ${_formatDate(end)}',
                                    style: TextStyle(
                                      color: Colors.grey.shade700,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade100,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    daycare ? '臨托' : '$nights 晚',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 5),

                            Row(
                              children: [
                                Expanded(
                                  child: Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blueGrey.shade50,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          data['bookingCode'] ??
                                              '#${widget.bookingId.substring(0, 8)}',
                                          style: TextStyle(
                                            color: Colors.blueGrey.shade800,
                                            fontSize: 14,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),

                                      if (data['source'] == 'admin')
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.blue.shade50,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '手動新增',
                                            style: TextStyle(
                                              color: Colors.blue.shade800,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),

                                      if (isDepositReview)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.red.shade50,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '已回傳付款',
                                            style: TextStyle(
                                              color: Colors.red.shade700,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),

                                      if (hasUnreadMessage)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '💬 新留言 $shopUnreadMessageCount',
                                            style: TextStyle(
                                              color: Colors.green.shade800,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),

                                      if (isUnassigned)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange.shade50,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '待分房',
                                            style: TextStyle(
                                              color: Colors.orange.shade800,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                      if (hasDiscount)
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.shade50,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            '🏷 滿${discountMinNights.toInt()}晚優惠 -NT\$ ${discountAmount.toInt()}',
                                            style: TextStyle(
                                              color: Colors.green.shade800,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),

                                Icon(
                                  _expanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: Colors.grey.shade700,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),
                  Divider(color: Colors.grey.shade200, height: 1),
                  const SizedBox(height: 10),

                  _compactInfoRow(
                    customerName: customerName,
                    customerPhone: customerPhone,
                    petNames: petNames,
                  ),
                ],
              ),
            ),

            AnimatedCrossFade(
              duration: const Duration(milliseconds: 180),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                child: Column(
                  children: [
                    const SizedBox(height: 4),

                    _compactExpandBox(
                      customerName: customerName,
                      customerPhone: customerPhone,
                      petNames: petNames,
                      paymentMethod: paymentMethod,
                      depositExpireText: depositExpireText,
                      depositAmount: depositAmount,
                      paymentTitle: paymentTitle,
                      expireTitle: payAmountType == 'full' ? '付款期限' : '訂金期限',
                      depositText: depositAmount <= 0
                          ? '無需訂金'
                          : depositPaid
                          ? '已確認'
                          : '尚未確認',
                      depositColor: depositAmount <= 0
                          ? Colors.grey
                          : depositPaid
                          ? Colors.green
                          : Colors.orange,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: _amountBox(
                            title: '總金額',
                            value: 'NT\$ $totalPrice',
                            color: Colors.red,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _amountBox(
                            title: paymentTitle,
                            value: paymentAmount > 0
                                ? 'NT\$ $paymentAmount'
                                : '無需訂金',
                            color: depositAmount > 0
                                ? depositPaid
                                      ? Colors.green
                                      : Colors.orange
                                : Colors.grey,
                            subText: paymentAmount > 0
                                ? depositPaid
                                      ? '已確認'
                                      : '尚未確認'
                                : null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '下訂時間：$createdAtText',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: widget.onTap,
                          icon: const Icon(Icons.open_in_new, size: 16),
                          label: const Text('查看詳細'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _roomBox(String roomName) {
    return Container(
      width: 68,
      height: 68,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blueGrey.shade900, Colors.blueGrey.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            roomName,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactInfoRow({
    required String customerName,
    required String customerPhone,
    required String petNames,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Icon(Icons.person, size: 17, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                customerName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            Icon(Icons.phone, size: 16, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              customerPhone,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Row(
          children: [
            Icon(Icons.pets, size: 17, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                petNames.isEmpty ? '無寵物資料' : petNames,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey.shade800,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _compactExpandBox({
    required String customerName,
    required String customerPhone,
    required String petNames,
    required String paymentMethod,
    required String depositText,
    required String depositExpireText,
    required num depositAmount,
    required Color depositColor,
    required String paymentTitle,
    required String expireTitle,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          /// 第一排
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _miniInfo(
                  icon: Icons.person,
                  label: '姓名',
                  value: customerName,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: _miniInfo(
                  icon: Icons.phone,
                  label: '電話',
                  value: customerPhone,
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          /// 第二排
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _miniInfo(
                  icon: Icons.pets,
                  label: '寵物',
                  value: petNames.isEmpty ? '無寵物資料' : petNames,
                ),
              ),

              const SizedBox(width: 16),

              Expanded(
                child: _miniInfo(
                  icon: Icons.credit_card,
                  label: '付款',
                  value: paymentMethod,
                ),
              ),
            ],
          ),

          /// 第三排
          if (depositAmount > 0 && depositExpireText != '-') ...[
            const SizedBox(height: 14),

            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _miniInfo(
                    icon: Icons.verified,
                    label: paymentTitle,
                    value: depositText,
                    valueColor: depositColor,
                  ),
                ),

                const SizedBox(width: 16),

                Expanded(
                  child: _miniInfo(
                    icon: Icons.schedule,
                    label: expireTitle,
                    value: depositExpireText,
                    valueColor: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ] else ...[
            const SizedBox(height: 14),

            Row(
              children: [
                Expanded(
                  child: _miniInfo(
                    icon: Icons.verified,
                    label: paymentTitle,
                    value: depositText,
                    valueColor: depositColor,
                  ),
                ),

                const SizedBox(width: 16),

                const Expanded(child: SizedBox()),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _amountBox({
    required String title,
    required String value,
    required Color color,
    String? subText,
  }) {
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          if (subText != null)
            Text(
              subText,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(_StatusInfo info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: info.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(
        info.text,
        style: TextStyle(
          color: info.color,
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  DateTime _toDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return DateTime.now();
  }

  int _calcNights(DateTime start, DateTime end) {
    final diff = end.difference(start).inDays;
    return diff <= 0 ? 1 : diff;
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDateTime(dynamic value) {
    if (value is Timestamp) {
      final date = value.toDate();
      final y = date.year.toString().padLeft(4, '0');
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      final h = date.hour.toString().padLeft(2, '0');
      final min = date.minute.toString().padLeft(2, '0');
      return '$y-$m-$d $h:$min';
    }

    return '-';
  }

  String _paymentMethodText(dynamic value) {
    switch (value) {
      case 'cash':
        return '到店付款';
      case 'transfer':
        return '銀行轉帳';
      default:
        return '未設定';
    }
  }

  _StatusInfo _statusInfo(String status) {
    final bool daycare = BookingKind.isDaycare(widget.data);
    switch (status) {
      case 'confirmed':
        return _StatusInfo('已確認', Colors.blue);
      case 'checked_in':
        return _StatusInfo('入住中', Colors.green);
      case 'completed':
        return _StatusInfo(daycare ? '已完成臨托' : '已完成', Colors.grey);
      case 'cancelled':
        return _StatusInfo('已取消', Colors.red);
      case 'unpaid':
        return _StatusInfo('尚未付款', Colors.red);
      default:
        return _StatusInfo('待確認', Colors.orange);
    }
  }
}

Widget _miniInfo({
  required IconData icon,
  required String label,
  required String value,
  Color? valueColor,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 16, color: Colors.blue.shade600),
      const SizedBox(width: 5),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: valueColor ?? Colors.black87,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _StatusInfo {
  const _StatusInfo(this.text, this.color);

  final String text;
  final Color color;
}
