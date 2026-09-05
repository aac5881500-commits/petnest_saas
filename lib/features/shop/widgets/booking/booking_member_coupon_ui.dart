// 檔案名稱：lib/features/shop/widgets/booking/booking_member_coupon_ui.dart
// 功能說明：前台住宿預約的會員優惠券選擇卡與挑選 BottomSheet。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/member_coupon_model.dart';

class BookingMemberCouponSection extends StatelessWidget {
  const BookingMemberCouponSection({
    super.key,
    required this.theme,
    required this.selectedCoupon,
    required this.availableCoupons,
    required this.loading,
    required this.couponBlockedBySpecialDate,
    required this.unavailableReason,
    required this.couponDiscountAmount,
    required this.onClear,
    required this.onPick,
  });

  final HomeThemeModel theme;
  final MemberCouponModel? selectedCoupon;
  final List<MemberCouponModel> availableCoupons;
  final bool loading;
  final bool couponBlockedBySpecialDate;
  final String? unavailableReason;
  final int couponDiscountAmount;
  final VoidCallback onClear;
  final VoidCallback onPick;

  static String couponNumberText(num value) {
    if (value == value.toInt()) {
      return value.toInt().toString();
    }
    return value.toString();
  }

  static String formatCouponDate(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}/$month/$day';
  }

  static String benefitText(MemberCouponModel coupon) {
    switch (coupon.type) {
      case MemberCouponType.fixedAmount:
        return '折抵 NT\$ ${coupon.discountValue.toInt()}';
      case MemberCouponType.percent:
        return '折抵 ${couponNumberText(coupon.discountValue)}%';
      case MemberCouponType.freeStay:
        return '免費住宿 ${coupon.freeStayNights} 晚';
      case MemberCouponType.freeService:
        if (coupon.serviceName.trim().isEmpty) {
          return '免費指定服務';
        }
        return '免費 ${coupon.serviceName.trim()}';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (couponBlockedBySpecialDate) {
      return Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Row(
                children: <Widget>[
                  Icon(Icons.confirmation_number_outlined),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '使用優惠券',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade300),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      Icons.info_outline,
                      color: Colors.orange.shade800,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '目前住宿日期包含特殊日期加價，本次不可使用優惠券。',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 13.5,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                const Icon(Icons.confirmation_number_outlined),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    '使用優惠券',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                ),
                if (selectedCoupon != null)
                  TextButton(onPressed: onClear, child: const Text('不使用')),
              ],
            ),
            const SizedBox(height: 12),
            if (loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (availableCoupons.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '目前沒有可使用的優惠券',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
              )
            else
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: onPick,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selectedCoupon == null
                          ? theme.cardBorderColor
                          : theme.primaryColor,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: selectedCoupon == null
                            ? const Text('點擊選擇優惠券')
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    selectedCoupon!.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    benefitText(selectedCoupon!),
                                    style: TextStyle(
                                      color: theme.textColor.withValues(
                                        alpha: 0.7,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                ),
              ),
            if (selectedCoupon != null) ...<Widget>[
              const SizedBox(height: 10),
              if (unavailableReason != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.info_outline,
                        size: 19,
                        color: Colors.orange.shade800,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '此優惠券目前未套用\n$unavailableReason',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Colors.orange.shade900,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (selectedCoupon!.type == MemberCouponType.freeService &&
                  couponDiscountAmount <= 0)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '請先在加值服務中選擇此優惠券指定的服務，系統才會計算折抵金額。',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: Colors.orange.shade800,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                Row(
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_outline,
                      size: 19,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 7),
                    Text(
                      '本次預估折抵：NT\$ $couponDiscountAmount',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.green.shade700,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
            ],
            if (selectedCoupon != null &&
                selectedCoupon!.description.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              Text(
                selectedCoupon!.description.trim(),
                style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<MemberCouponModel?> showBookingMemberCouponPicker({
  required BuildContext context,
  required HomeThemeModel theme,
  required List<MemberCouponModel> coupons,
  required MemberCouponModel? selectedCoupon,
}) {
  return showModalBottomSheet<MemberCouponModel>(
    context: context,
    isScrollControlled: true,
    builder: (BuildContext bottomSheetContext) {
      return SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(bottomSheetContext).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
                child: Row(
                  children: <Widget>[
                    const Expanded(
                      child: Text(
                        '選擇優惠券',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(bottomSheetContext);
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: coupons.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (BuildContext context, int index) {
                    final MemberCouponModel coupon = coupons[index];
                    final bool isSelected = coupon.id == selectedCoupon?.id;
                    return Card(
                      margin: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: isSelected
                              ? theme.primaryColor
                              : Colors.grey.shade300,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () {
                          Navigator.pop(bottomSheetContext, coupon);
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              CircleAvatar(
                                backgroundColor: theme.primaryColor.withValues(
                                  alpha: 0.12,
                                ),
                                child: Icon(
                                  Icons.confirmation_number_outlined,
                                  color: theme.primaryColor,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      coupon.name,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      BookingMemberCouponSection.benefitText(
                                        coupon,
                                      ),
                                      style: TextStyle(
                                        color: theme.textColor.withValues(
                                          alpha: 0.7,
                                        ),
                                      ),
                                    ),
                                    if (coupon.minimumAmount > 0) ...<Widget>[
                                      const SizedBox(height: 4),
                                      Text(
                                        '最低消費 NT\$ ${coupon.minimumAmount}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                    ],
                                    if (coupon.expireAt != null) ...<Widget>[
                                      const SizedBox(height: 4),
                                      Text(
                                        '有效期限：${BookingMemberCouponSection.formatCouponDate(coupon.expireAt!)}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  Icons.check_circle,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
