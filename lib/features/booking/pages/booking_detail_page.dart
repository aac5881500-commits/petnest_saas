// lib/features/booking/pages/booking_detail_page.dart
// 📄 訂單詳細頁（客戶端）
//
// 功能：
// - 顯示完整訂單資訊（卡片式 UI）
// - 顧客 / 寵物 / 訂金 / 備註
// - 上傳轉帳截圖
// - 填寫轉帳後五碼

//
// 特點：
// - UI 已升級（區塊卡片）
// - 訂金區強化（橘色提示）
// - 不顯示員工備註（安全）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/services/booking_service.dart';
import 'package:petnest_saas/core/models/create_payment_request_model.dart';
import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/core/services/payment_function_service.dart';
import 'package:petnest_saas/features/payment/pages/ecpay_payment_page.dart';
import 'dart:async';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_status_card.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_header_section.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_price_section.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_customer_pet_section.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_payment_section.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_after_checkout_section.dart';
import 'package:petnest_saas/features/shop/pages/policy_version_detail_page.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_message_section.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_review_section.dart';

class BookingDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;

  const BookingDetailPage({super.key, required this.data, required this.docId});

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  final TextEditingController _last5Controller = TextEditingController();
  final FocusNode _last5FocusNode = FocusNode();
  bool _loading = false;

  /// 💳 是否正在建立新的線上付款
  bool _creatingPayment = false;
  bool _autoCancelling = false;
  Timer? _expireTimer;
  final GlobalKey _messageSectionKey = GlobalKey();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _expireTimer?.cancel();
    _last5Controller.dispose();
    _last5FocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔥 價格計算（你現在缺這段）

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.docId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>;
        final shopName = (data['shopName'] ?? '').toString();
        final reviewed = data['reviewed'] == true;
        final basePrice = data['basePrice'] ?? 0;
        final nights = data['nights'] ?? 1;
        final extraPetPrice = data['extraPetPrice'] ?? 0;
        final extraPetCount = data['extraPetCount'] ?? 0;

        /// 房費
        final roomPriceTotal = basePrice * nights;

        /// 寵物費
        final petPriceTotal = extraPetPrice * extraPetCount * nights;

        /// 小計（房間＋寵物）
        final correctSubtotal = roomPriceTotal + petPriceTotal;

        /// 🔥 加值服務總金額
        final addonTotal = (data['addons'] as List? ?? []).fold<int>(0, (
          int sum,
          dynamic item,
        ) {
          final price = (item['price'] ?? 0) as num;
          final count = (item['count'] ?? 1) as num;
          final total = (item['total'] ?? (price * count)) as num;

          return sum + total.toInt();
        });

        /// 🔥 最終總價：優先使用訂單已存的 totalPrice（折後金額）
        final finalTotal = data['totalPrice'] ?? (correctSubtotal + addonTotal);
        final depositStatus = data['depositStatus'] ?? '';
        final bookingStatus = data['status'] ?? 'unpaid';
        final transferLast5 = (data['transferLast5'] ?? '').toString();

        if (_last5Controller.text.isEmpty && transferLast5.isNotEmpty) {
          _last5Controller.text = transferLast5;
        }
        final bankName = data['bankName'] ?? '';
        final accountName = data['accountName'] ?? '';
        final accountNumber = data['accountNumber'] ?? '';
        if (_isDepositExpired(data)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _autoCancelExpiredBooking(data);
          });
        } else {
          _scheduleDepositExpireCheck(data);
        }

        final start = (data['startDate'] as Timestamp).toDate();
        final end = (data['endDate'] as Timestamp).toDate();

        return Scaffold(
          appBar: AppBar(
            title: const Text('訂單詳細'),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade50,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        /// 🔹 小標題
                        const Text(
                          '訂單編號',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey,
                          ),
                        ),

                        /// 🔥 編號（放大）
                        GestureDetector(
                          onTap: () async {
                            final id =
                                (data['bookingCode'] ?? '')
                                    .toString()
                                    .isNotEmpty
                                ? data['bookingCode']
                                : widget.docId.substring(0, 8);

                            await Clipboard.setData(ClipboardData(text: id));
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已複製訂單編號')),
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                (data['bookingCode'] ?? '')
                                        .toString()
                                        .isNotEmpty
                                    ? data['bookingCode']
                                    : widget.docId.substring(0, 8),
                                style: const TextStyle(
                                  fontSize: 13, // 🔥 放大
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(
                                Icons.copy,
                                size: 13,
                                color: Colors.grey,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              controller: _scrollController,
              children: [
                /// 🏠 房型卡（完全後台版🔥）
                BookingDetailStatusCard(data: data),
                const SizedBox(height: 12),
                if ((data['source'] ?? '').toString() == 'admin' ||
                    (data['source'] ?? '').toString() == 'manual')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade100),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.orange.shade700,
                          size: 22,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '此訂單由店家代為建立，可能是電話、現場或合併歷史訂單後同步到您的會員中心。',
                            style: TextStyle(
                              color: Colors.orange.shade900,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                if (bookingStatus == 'pending' || bookingStatus == 'unpaid')
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        if (depositStatus == 'pending_review') {
                          _scrollToMessageSection();

                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已帶你到留言區')),
                          );
                          return;
                        }

                        final cancelReason = await _showCancelReasonDialog(
                          context,
                        );

                        if (cancelReason == null) return;

                        await BookingService.instance.cancelBooking(
                          bookingId: widget.docId,
                          cancelReason: cancelReason,
                          cancelBy: 'customer',
                        );

                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('訂單已取消')),
                          );
                        }
                      },
                      icon: Icon(
                        depositStatus == 'pending_review'
                            ? Icons.chat_bubble_outline
                            : Icons.close,
                      ),
                      label: Text(
                        depositStatus == 'pending_review' ? '聯絡店家' : '取消訂單',
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: depositStatus == 'pending_review'
                            ? Colors.blue
                            : Colors.red,
                        side: BorderSide(
                          color: depositStatus == 'pending_review'
                              ? Colors.blue.shade200
                              : Colors.red.shade200,
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),

                if (bookingStatus == 'cancelled')
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Text(
                      '取消原因：${data['cancelReason'] ?? '未填寫'}',
                      style: const TextStyle(
                        color: Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 12),

                BookingDetailHeaderSection(
                  data: data,
                  start: start,
                  end: end,
                  formatDateTime: _formatDateTime,
                ),

                BookingDetailCustomerPetSection(data: data),

                BookingDetailPriceSection(
                  data: data,
                  basePrice: basePrice,
                  nights: nights,
                  extraPetPrice: extraPetPrice,
                  extraPetCount: extraPetCount,
                  roomPriceTotal: roomPriceTotal,
                  petPriceTotal: petPriceTotal,
                  correctSubtotal: correctSubtotal,
                  addonTotal: addonTotal,
                  finalTotal: finalTotal,
                ),

                const SizedBox(height: 16),

                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.teal.shade100),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.teal.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.gavel_rounded,
                              color: Colors.teal,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['policyTitle'] ?? '入住須知',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '版本：v${data['policyVersion'] ?? '-'}',
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '同意時間：${_formatDateTime(data['policyAcceptedAt']) ?? '未記錄'}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final shopId = (data['shopId'] ?? '').toString();
                            final version = data['policyVersion'];

                            if (shopId.isEmpty || version == null) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('找不到條款版本資料')),
                              );
                              return;
                            }

                            final doc = await FirebaseFirestore.instance
                                .collection('shops')
                                .doc(shopId)
                                .collection('policy_versions')
                                .doc('v$version')
                                .get();

                            if (!context.mounted) return;

                            if (!doc.exists) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('找不到該版本條款')),
                              );
                              return;
                            }

                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    PolicyVersionDetailPage(data: doc.data()!),
                              ),
                            );
                          },
                          icon: const Icon(Icons.history, size: 18),
                          label: const Text('查看當時條款內容'),
                        ),
                      ),
                    ],
                  ),
                ),

                /// 💰 訂金提示
                /// 💰 訂金提示
                if ((data['depositAmount'] ?? 0) > 0 &&
                    (data['paymentMethod'] == 'transfer' ||
                        data['paymentMethod'] == 'cash') &&
                    depositStatus != 'confirmed')
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: depositStatus == 'pending_review'
                          ? Colors.green.shade50
                          : Colors.red.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      depositStatus == 'pending_review'
                          ? '✅ 已回傳轉帳證明，等待店家確認\n回傳時間：${_formatDateTime(data['depositSubmittedAt']) ?? '剛剛'}'
                          : '⚠️ 請依店家規定完成訂金付款，訂單才會成立\n付款期限：${_formatDateTime(data['depositExpireAt']) ?? '未設定'}',
                      style: TextStyle(
                        color: depositStatus == 'pending_review'
                            ? Colors.green
                            : Colors.red,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if ((data['depositAmount'] ?? 0) <= 0 ||
                    data['paymentMethod'] == 'cash')
                  Container(
                    padding: const EdgeInsets.all(10),
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text(
                      '💡 本訂單無需線上支付訂金，請依店家安排付款',
                      style: TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                  stream: FirebaseFirestore.instance
                      .collection('shops')
                      .doc((data['shopId'] ?? '').toString())
                      .snapshots(),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>>
                        shopSnapshot,
                      ) {
                        if (!shopSnapshot.hasData) {
                          return const SizedBox.shrink();
                        }

                        final Map<String, dynamic> shopData =
                            shopSnapshot.data?.data() ?? <String, dynamic>{};

                        final dynamic rawPaymentSetting =
                            shopData['paymentSetting'];

                        final Map<String, dynamic> paymentSetting =
                            rawPaymentSetting is Map
                            ? Map<String, dynamic>.from(rawPaymentSetting)
                            : <String, dynamic>{};

                        final dynamic rawOperationSettings =
                            paymentSetting['operationSettings'];

                        final Map<String, dynamic> operationSettings =
                            rawOperationSettings is Map
                            ? Map<String, dynamic>.from(rawOperationSettings)
                            : <String, dynamic>{};

                        final String reviewStatus =
                            (paymentSetting['reviewStatus'] ?? '')
                                .toString()
                                .trim()
                                .toLowerCase();

                        final bool ecpayEnabled =
                            operationSettings['ecpayEnabled'] == true;

                        final bool hasEnabledEcpayMethod =
                            operationSettings['creditCardEnabled'] == true ||
                            operationSettings['atmEnabled'] == true ||
                            operationSettings['cvsCodeEnabled'] == true;

                        final bool platformSuspended =
                            paymentSetting['platformSuspended'] == true;

                        final bool shopDisabled =
                            paymentSetting['shopDisabled'] == true;

                        final int totalAmount =
                            ((data['totalPayableAmount'] ??
                                        data['totalPrice'] ??
                                        data['totalAmount'] ??
                                        data['total'] ??
                                        0)
                                    as num)
                                .toInt();

                        final int paidAmount =
                            ((data['paidAmount'] ?? 0) as num).toInt();

                        final int remainingAmount =
                            ((data['remainingAmount'] ??
                                        (totalAmount - paidAmount))
                                    as num)
                                .toInt()
                                .clamp(0, totalAmount);

                        final bool canCreateOnlinePayment =
                            reviewStatus == 'approved' &&
                            ecpayEnabled &&
                            hasEnabledEcpayMethod &&
                            !platformSuspended &&
                            !shopDisabled &&
                            remainingAmount > 0 &&
                            bookingStatus != 'cancelled' &&
                            bookingStatus != 'completed';

                        if (!canCreateOnlinePayment) {
                          return const SizedBox.shrink();
                        }

                        return Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: _creatingPayment
                                  ? null
                                  : () async {
                                      await _showOnlinePaymentMethodSheet(
                                        booking: data,
                                      );
                                    },
                              icon: _creatingPayment
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.payment),
                              label: Text(
                                _creatingPayment
                                    ? '正在建立付款...'
                                    : paidAmount > 0
                                    ? '支付剩餘金額 NT\$ $remainingAmount'
                                    : '立即付款 NT\$ $remainingAmount',
                              ),
                              style: ElevatedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                ),

                BookingDetailPaymentSection(
                  data: data,
                  depositStatus: depositStatus.toString(),
                  bankName: bankName.toString(),
                  accountName: accountName.toString(),
                  accountNumber: accountNumber.toString(),
                  last5Controller: _last5Controller,
                  loading: _loading,
                  onUploadImage: _uploadImage,
                  onSubmitDeposit: _submitDeposit,
                  onDeleteTransferImage: _deleteTransferImage,
                ),

                BookingDetailReviewSection(
                  bookingId: widget.docId,
                  data: data,
                  bookingStatus: bookingStatus.toString(),
                ),

                const SizedBox(height: 16),

                Container(
                  key: _messageSectionKey,
                  child: BookingDetailMessageSection(
                    bookingId: widget.docId,
                    senderType: 'customer',
                    bookingStatus: bookingStatus.toString(),
                  ),
                ),
                const SizedBox(height: 16),

                BookingDetailAfterCheckoutSection(
                  data: data,
                  bookingStatus: bookingStatus.toString(),
                  depositStatus: depositStatus.toString(),
                  formatDateTime: _formatDateTime,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _scrollToMessageSection() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeInOut,
      );
    });
  }

  /// 💳 顯示線上付款方式選擇視窗
  ///
  /// 顧客選擇付款方式後，
  /// 針對同一筆 Booking 建立新的 Payment。
  Future<void> _showOnlinePaymentMethodSheet({
    required Map<String, dynamic> booking,
  }) async {
    if (_creatingPayment) {
      return;
    }

    final String? selectedMethod = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext bottomSheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '選擇付款方式',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(
                  '請選擇這次要使用的線上付款方式。',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 16),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(child: Icon(Icons.credit_card)),
                  title: const Text(
                    '信用卡',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('前往綠界信用卡付款頁'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(
                      bottomSheetContext,
                      PaymentMethodType.creditCard,
                    );
                  },
                ),

                const Divider(height: 1),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.account_balance),
                  ),
                  title: const Text(
                    'ATM 虛擬帳號',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('取得 ATM 繳費帳號'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(bottomSheetContext, PaymentMethodType.atm);
                  },
                ),

                const Divider(height: 1),

                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    child: Icon(Icons.storefront_outlined),
                  ),
                  title: const Text(
                    '超商代碼',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: const Text('取得超商繳費代碼'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(
                      bottomSheetContext,
                      PaymentMethodType.convenienceStoreCode,
                    );
                  },
                ),

                const SizedBox(height: 12),

                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(bottomSheetContext);
                    },
                    child: const Text('取消'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );

    if (selectedMethod == null || !mounted) {
      return;
    }

    await _createRemainingPayment(
      booking: booking,
      paymentMethod: selectedMethod,
    );
  }

  /// 💳 針對同一筆 Booking 建立新的綠界付款
  ///
  /// - 完全未付款：建立全額付款 full
  /// - 已支付部分金額：建立尾款 balance
  /// - Booking 永久保留，不重新建立訂單
  Future<void> _createRemainingPayment({
    required Map<String, dynamic> booking,
    required String paymentMethod,
  }) async {
    if (_creatingPayment) {
      return;
    }

    final String shopId = (booking['shopId'] ?? '').toString().trim();

    final int totalAmount =
        ((booking['totalPayableAmount'] ??
                    booking['totalPrice'] ??
                    booking['totalAmount'] ??
                    booking['total'] ??
                    0)
                as num)
            .toInt();

    final int paidAmount = ((booking['paidAmount'] ?? 0) as num).toInt();

    final int remainingAmount =
        ((booking['remainingAmount'] ?? (totalAmount - paidAmount)) as num)
            .toInt()
            .clamp(0, totalAmount);

    if (shopId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('找不到店家資料。')));
      return;
    }

    if (!PaymentMethodType.isOnlinePayment(paymentMethod)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請選擇有效的線上付款方式。')));
      return;
    }

    if (totalAmount <= 0 || remainingAmount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('這筆訂單目前沒有待支付金額。')));
      return;
    }

    final String paymentPurpose = paidAmount > 0
        ? PaymentPurpose.balance
        : PaymentPurpose.full;

    /*
     * 後端目前的 PaymentAmountType 只有 deposit / full。
     *
     * 尾款仍使用 full 作為金額類型，
     * 實際用途則由 paymentPurpose = balance 標記。
     */
    const String amountType = PaymentAmountType.full;

    final String paymentRequestId = FirebaseFirestore.instance
        .collection('payments')
        .doc()
        .id;

    setState(() {
      _creatingPayment = true;
    });

    try {
      final paymentResult = await PaymentFunctionService.instance.createPayment(
        request: CreatePaymentRequestModel(
          shopId: shopId,
          bookingId: widget.docId,
          paymentMethod: paymentMethod,
          amountType: amountType,
          paymentPurpose: paymentPurpose,
          amount: remainingAmount,
          requestId: paymentRequestId,
        ),
      );

      if (!mounted) {
        return;
      }

      if (!paymentResult.hasPaymentHtml) {
        throw const PaymentFunctionException(
          code: 'missing-payment-html',
          message: '綠界付款頁資料不完整，請稍後再試。',
        );
      }

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              EcpayPaymentPage(paymentHtml: paymentResult.paymentHtml),
        ),
      );
    } catch (error) {
      if (!mounted) {
        return;
      }

      final String message = error is PaymentFunctionException
          ? error.message
          : error.toString().replaceFirst('Exception: ', '');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } finally {
      if (mounted) {
        setState(() {
          _creatingPayment = false;
        });
      }
    }
  }

  Future<String?> _showCancelReasonDialog(BuildContext context) async {
    String selectedReason = '客戶自行取消';
    final otherReasonController = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('取消訂單原因'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    value: selectedReason,
                    items: const [
                      DropdownMenuItem(value: '客戶自行取消', child: Text('客戶自行取消')),
                      DropdownMenuItem(value: '行程變更', child: Text('行程變更')),
                      DropdownMenuItem(value: '重複預約', child: Text('重複預約')),
                      DropdownMenuItem(
                        value: '改用其他付款方式',
                        child: Text('改用其他付款方式'),
                      ),
                      DropdownMenuItem(value: '其他', child: Text('其他')),
                    ],
                    onChanged: (v) {
                      setDialogState(() {
                        selectedReason = v ?? '客戶自行取消';
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: '取消原因',
                      border: OutlineInputBorder(),
                    ),
                  ),

                  if (selectedReason == '其他') ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: otherReasonController,
                      decoration: const InputDecoration(
                        labelText: '其他原因',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('返回'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final reason = selectedReason == '其他'
                        ? otherReasonController.text.trim()
                        : selectedReason;

                    if (reason.isEmpty) return;

                    Navigator.pop(context, reason);
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('確認取消'),
                ),
              ],
            );
          },
        );
      },
    );

    otherReasonController.dispose();
    return result;
  }

  /// 🔥 寫入訂金
  Future<void> _submitDeposit() async {
    final last5 = _last5Controller.text.trim();

    final bookingDoc = await FirebaseFirestore.instance
        .collection('bookings')
        .doc(widget.docId)
        .get();

    final bookingData = bookingDoc.data() ?? {};
    final transferImageUrl = (bookingData['transferImageUrl'] ?? '').toString();

    if (transferImageUrl.isEmpty) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('尚未上傳轉帳截圖'),
          content: const Text('你目前沒有上傳轉帳截圖，確定只送出後五碼嗎？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('返回上傳'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確定送出'),
            ),
          ],
        ),
      );

      if (confirm != true) return;
    }

    if (last5.length != 5) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請輸入正確的後五碼')));
      return;
    }

    try {
      setState(() {
        _loading = true;
      });

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.docId)
          .update({
            'transferLast5': last5,

            /// 🔥 客戶已回傳付款資料
            'depositStatus': 'pending_review',

            /// 🔥 記錄送出時間
            'depositSubmittedAt': FieldValue.serverTimestamp(),
          });

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('訂金已送出')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('錯誤：$e')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  /// 📸 上傳圖片
  Future<void> _uploadImage() async {
    final picker = ImagePicker();

    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1200, // 🔥 限制圖片寬度
      imageQuality: 75, // 🔥 壓縮品質
    );

    if (picked == null) return;

    if (!mounted) return;

    setState(() {
      _loading = true;
    });

    try {
      final bytes = await picked.readAsBytes();

      /// 🔥 限制上傳後大小，避免高階手機大圖炸容量
      if (bytes.length > 5 * 1024 * 1024) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('圖片太大，請選擇 5MB 以下的圖片')));

        setState(() {
          _loading = false;
        });

        return;
      }

      final ref = FirebaseStorage.instance
          .ref()
          .child('booking_images')
          .child(widget.docId)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.docId)
          .update({'transferImageUrl': url});
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('圖片上傳成功')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('上傳失敗：$e')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _deleteTransferImage(String imageUrl) async {
    if (imageUrl.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('刪除轉帳截圖'),
        content: const Text('確定要刪除目前上傳的轉帳截圖嗎？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定刪除'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _loading = true;
    });

    try {
      await FirebaseStorage.instance.refFromURL(imageUrl).delete();

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.docId)
          .update({'transferImageUrl': FieldValue.delete()});

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('已刪除轉帳截圖')));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('刪除失敗：$e')));
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  String? _formatDateTime(dynamic value) {
    if (value == null) return null;

    if (value is Timestamp) {
      final date = value.toDate();

      final y = date.year.toString().padLeft(4, '0');
      final m = date.month.toString().padLeft(2, '0');
      final d = date.day.toString().padLeft(2, '0');
      final h = date.hour.toString().padLeft(2, '0');
      final min = date.minute.toString().padLeft(2, '0');

      return '$y-$m-$d $h:$min';
    }

    return null;
  }

  bool _needDepositPayment(Map<String, dynamic> data) {
    final depositAmount = data['depositAmount'] ?? 0;
    final paymentMethod = data['paymentMethod'] ?? '';
    final depositStatus = data['depositStatus'] ?? '';
    final status = data['status'] ?? '';

    return depositAmount > 0 &&
        (paymentMethod == 'transfer' || paymentMethod == 'cash') &&
        depositStatus != 'pending' &&
        depositStatus != 'pending_review' &&
        depositStatus != 'confirmed' &&
        status != 'cancelled';
  }

  bool _isDepositExpired(Map<String, dynamic> data) {
    if (!_needDepositPayment(data)) return false;

    final expireAt = data['depositExpireAt'];
    if (expireAt == null || expireAt is! Timestamp) return false;

    return DateTime.now().isAfter(expireAt.toDate());
  }

  Future<void> _autoCancelExpiredBooking(Map<String, dynamic> data) async {
    if (_autoCancelling) return;

    _autoCancelling = true;

    try {
      await BookingService.instance.cancelBooking(
        bookingId: widget.docId,
        cancelReason: '訂單保留逾期自動取消',
        cancelBy: 'system',
      );

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.docId)
          .update({'depositExpired': true});
    } finally {
      _autoCancelling = false;
    }
  }

  void _scheduleDepositExpireCheck(Map<String, dynamic> data) {
    if (!_needDepositPayment(data)) return;

    final expireAt = data['depositExpireAt'];
    if (expireAt == null || expireAt is! Timestamp) return;

    _expireTimer?.cancel();

    final diff = expireAt.toDate().difference(DateTime.now());

    if (diff.isNegative) return;

    _expireTimer = Timer(diff, () {
      if (!mounted) return;
      _autoCancelExpiredBooking(data);
    });
  }
}
