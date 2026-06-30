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
import 'dart:async';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_status_card.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_header_section.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_price_section.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_customer_pet_section.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_payment_section.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_after_checkout_section.dart';
import 'package:petnest_saas/features/shop/pages/policy_version_detail_page.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_message_section.dart';

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
