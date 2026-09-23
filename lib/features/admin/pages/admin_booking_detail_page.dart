// 檔案名稱：lib/features/admin/pages/admin_booking_detail_page.dart
// 功能說明：訂單詳細頁（後台版）
//  店主自己的後台店家詳細頁
//
// 功能：
// - 即時讀取 booking（Firestore）
// - 顯示完整訂單資料
// - 可操作狀態（確認 / 完成 / 取消）
// - 未來可擴充員工操作

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_form_answers_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_settlement_panel.dart';
import 'package:petnest_saas/features/admin/widgets/admin_internal_handover_card.dart';
import 'package:petnest_saas/core/services/booking_payment_status.dart';
import 'package:petnest_saas/core/debug/chat_error_probe.dart';
import 'package:petnest_saas/core/services/admin_manual_deposit_confirm.dart';
import 'package:petnest_saas/core/services/booking_settlement_function_service.dart';
import 'package:petnest_saas/core/services/booking_settlement_math.dart';
import 'package:petnest_saas/core/services/daycare_function_service.dart';
import 'package:petnest_saas/core/services/internal_handover_note_service.dart';
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';
import 'package:petnest_saas/core/services/member_coupon_service.dart';
import 'package:petnest_saas/core/services/booking_service.dart';
import 'package:petnest_saas/core/services/housekeeping_setting_service.dart';
import 'package:petnest_saas/core/services/shop_room_service.dart';
import 'package:petnest_saas/core/services/stay_booking_function_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:petnest_saas/core/widgets/shop_frontend_theme_scope.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_action_log_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_action_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_customer_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_layout.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_payment_aside.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_detail_policy_card.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_dialogs.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_extra_charge_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_header_card.dart';
import 'package:petnest_saas/features/admin/widgets/admin_shop_identity_debug_card.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_note_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_strip.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_price_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_status_chip.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_text_helpers.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_timeline.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_message_section.dart';
import 'package:petnest_saas/core/services/pet_shop_form_answers.dart';
import 'package:petnest_saas/core/services/daily_care_setting_service.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_form_summary_card.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_stay_meta_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_daily_care_report_shortcut.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_points_card.dart';
import 'package:petnest_saas/features/admin/widgets/admin_stay_settle_sheet.dart';

class AdminBookingDetailPage extends StatelessWidget {
  const AdminBookingDetailPage({
    super.key,
    required this.bookingId,
    this.canEdit = true,
  });

  final String bookingId;

  /// 是否可操作訂單
  /// true：訂單管理進來，可確認 / 取消 / 入住 / 退房
  /// false：房務或會員詳細進來，只能查看
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final doc = snapshot.data!;
        if (!doc.exists) {
          return const Scaffold(body: Center(child: Text('訂單不存在')));
        }

        final data = doc.data() as Map<String, dynamic>;

        final List<Map<String, dynamic>> pets =
            AdminBookingFormAnswersSection.petsOf(data);

        final status = data['status'] ?? 'pending';

        final emergency = Map<String, dynamic>.from(
          data['emergencyContact'] ?? {},
        );

        final depositAmount = data['depositAmount'] ?? 0;
        final depositRequired = data['depositRequired'] == true;
        final String shopId = (data['shopId'] ?? '').toString();
        final String bookingCode = (data['bookingCode'] ?? '')
            .toString()
            .trim();

        return ShopFrontendThemeScope(
          shopId: shopId,
          builder: (BuildContext context) {
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: InternalHandoverNoteService.instance.stream(
                shopId: shopId,
                bookingId: bookingId,
              ),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>>
                    handoverSnap,
                  ) {
                    final bool handoverHasContent =
                        ((handoverSnap.data?.data()?['text'] ?? '')
                                .toString()
                                .trim())
                            .isNotEmpty;
                    AdminShopIdentityLog.logOnce(
                      bookingId: bookingId,
                      shopId: shopId,
                      bookingShopId: shopId,
                      settlementLocked:
                          BookingSettlementMath.isSettlementLocked(data),
                    );
                    return AdminBookingDetailScaffold(
                      title: '訂單詳細',
                      bookingCode: bookingCode.isEmpty
                          ? (bookingId.length >= 8
                                ? bookingId.substring(0, 8)
                                : bookingId)
                          : bookingCode,
                      banners: <Widget>[
                        if (data['source'] == 'admin' &&
                            (data['note'] ?? '').toString().trim().isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AdminBookingDetailCard(
                              child: Text(
                                '代客建立備註：${data['note']}',
                                style: const TextStyle(height: 1.4),
                              ),
                            ),
                          ),
                      ],
                      overview: AdminBookingHeaderCard(
                        data: data,
                        bookingId: bookingId,
                      ),
                      actions:
                          canEdit &&
                              !BookingSettlementMath.isSettlementLocked(data)
                          ? AdminBookingDetailCard(
                              child: AdminBookingActionSection(
                                data: data,
                                status: status,
                                depositAmount: depositAmount,
                                depositPaid:
                                    BookingPaymentStatus.isDepositConfirmed(
                                      data,
                                    ),
                                onAssignRoom: () async {
                                  await showAdminAssignRoomDialog(
                                    context: context,
                                    bookingId: bookingId,
                                    data: data,
                                  );
                                },
                                onChangeRoom: () async {
                                  await showAdminChangeRoomDialog(
                                    context: context,
                                    bookingId: bookingId,
                                    data: data,
                                  );
                                },
                                onConfirmBooking: () async {
                                  await _updateStatus('confirmed');
                                },
                                onConfirmDeposit: () async {
                                  await _confirmDepositAndBooking(context);
                                },
                                onCancelBooking: () async {
                                  await showAdminCancelBookingDialog(
                                    context: context,
                                    bookingId: bookingId,
                                  );
                                },
                                onCheckIn: () async {
                                  if (data['assignStatus'] != 'assigned' ||
                                      data['roomId'] == null ||
                                      data['roomName'] == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('此訂單尚未分房，不能辦理入住'),
                                      ),
                                    );
                                    return;
                                  }
                                  try {
                                    await BookingService.instance
                                        .checkInBooking(bookingId: bookingId);
                                    await FirebaseFirestore.instance
                                        .collection('action_logs')
                                        .add({
                                          'type': 'booking_status_update',
                                          'bookingId': bookingId,
                                          'bookingShortId': bookingId.substring(
                                            0,
                                            8,
                                          ),
                                          'shopId': data['shopId'],
                                          'roomId': data['roomId'],
                                          'roomName': data['roomName'],
                                          'roomTypeName': data['roomTypeName'],
                                          'fromStatus': status,
                                          'toStatus': 'checked_in',
                                          'operatorUid': FirebaseAuth
                                              .instance
                                              .currentUser
                                              ?.uid,
                                          'operatorRole': 'staff',
                                          'operatorEmail': FirebaseAuth
                                              .instance
                                              .currentUser
                                              ?.email,
                                          'createdAt':
                                              FieldValue.serverTimestamp(),
                                        });
                                  } catch (error) {
                                    if (!context.mounted) {
                                      return;
                                    }
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          InventoryException.userMessage(error),
                                        ),
                                      ),
                                    );
                                  }
                                },
                                onCheckOut: () async {
                                  await _handleCheckOut(
                                    context: context,
                                    data: data,
                                  );
                                },
                                onOpenDailyCareReport:
                                    (data['status'] ?? '').toString() ==
                                        'checked_in'
                                    ? () =>
                                          AdminDailyCareReportShortcut.openStayEntry(
                                            context: context,
                                            shopId: shopId,
                                            bookingId: bookingId,
                                            booking: data,
                                          )
                                    : null,
                              ),
                            )
                          : null,
                      left: <Widget>[
                        AdminBookingDetailSection(
                          title: '顧客資訊',
                          child: AdminBookingCustomerSection(
                            data: data,
                            emergency: emergency,
                            shopId: shopId,
                          ),
                        ),
                        AdminBookingDetailSection(
                          title: '寵物資訊（${pets.length}隻）',
                          child: AdminBookingPetStrip(
                            pets: pets,
                            shopId: shopId,
                            userId: PetShopFormAnswers.bookingUserId(data),
                          ),
                        ),
                        AdminBookingDetailSection(
                          title: '入住／退房日期',
                          child: AdminBookingStayMetaSection(data: data),
                        ),
                        AdminBookingDetailSection(
                          title: '點數折抵',
                          child: AdminBookingPointsCard(
                            shopId: shopId,
                            bookingId: bookingId,
                            booking: data,
                          ),
                        ),
                        AdminBookingDetailSection(
                          title: '服務與費用明細',
                          child: AdminBookingPriceSection(
                            data: data,
                            pets: pets,
                            lineItemsOnly: true,
                            bookingId: bookingId,
                          ),
                        ),
                        AdminBookingDetailSection(
                          title: '每日照護摘要',
                          child: AdminDailyCareReportShortcut(
                            shopId: shopId,
                            bookingId: bookingId,
                            booking: data,
                          ),
                        ),
                        if (data['extraCharges'] is List &&
                            (data['extraCharges'] as List).isNotEmpty)
                          AdminBookingDetailSection(
                            title: '退房額外費用',
                            collapsible: true,
                            initiallyExpanded: false,
                            child: AdminBookingExtraChargeSection(data: data),
                          ),
                      ],
                      progress: AdminBookingDetailSection(
                        title: '訂單進度',
                        collapsible: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            AdminBookingStatusChip(status: status.toString()),
                            const SizedBox(height: 10),
                            AdminBookingTimeline(
                              data: data,
                              status: status,
                              depositRequired: depositRequired,
                            ),
                            if (status == 'cancelled') ...<Widget>[
                              const SizedBox(height: 10),
                              Text(
                                '取消原因：${data['cancelReason'] ?? '未填寫'}',
                                style: const TextStyle(
                                  color: Colors.red,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                '取消來源：${adminBookingCancelByText(data['cancelBy'])}',
                                style: TextStyle(
                                  color: Colors.red.shade700,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      forms: <Widget>[
                        AdminBookingFormAnswersSection(
                          shopId: shopId,
                          bookingId: bookingId,
                          data: data,
                        ),
                      ],
                      formSummary: AdminBookingFormSummaryCard(
                        shopId: shopId,
                        bookingId: bookingId,
                        data: data,
                      ),
                      communication: <Widget>[
                        _buildMemberAdminNote(data),
                        AdminBookingDetailSection(
                          title: '客戶備註',
                          collapsible: true,
                          initiallyExpanded: false,
                          child: AdminBookingNoteSection(
                            data: data,
                            shopId: shopId,
                            bookingId: bookingId,
                          ),
                        ),
                        AdminBookingDetailSection(
                          title: '訂單留言',
                          collapsible: true,
                          initiallyExpanded: false,
                          child: BookingDetailMessageSection(
                            bookingId: bookingId,
                            senderType: 'shop',
                            bookingStatus: status.toString(),
                          ),
                        ),
                      ],
                      right: <Widget>[
                        AdminBookingSettlementPanel(
                          shopId: shopId,
                          bookingId: bookingId,
                          data: data,
                          onReadjust:
                              canEdit &&
                                  !BookingSettlementMath.isSettlementLocked(
                                    data,
                                  )
                              ? () {
                                  _handleCheckOut(context: context, data: data);
                                }
                              : null,
                        ),
                        AdminBookingDetailPaymentAside(
                          data: data,
                          bookingId: bookingId,
                          onConfirmDeposit:
                              canEdit &&
                                  !BookingSettlementMath.isSettlementLocked(
                                    data,
                                  ) &&
                                  (status == 'pending' ||
                                      status == 'pending_confirmation' ||
                                      status == 'unpaid') &&
                                  BookingPaymentStatus.resolveDepositAmount(
                                        data,
                                      ) >
                                      0 &&
                                  !BookingPaymentStatus.isDepositConfirmed(data)
                              ? () => _applyConfirmDeposit()
                              : null,
                        ),
                        AdminBookingDetailPolicyCard(data: data),
                        AdminBookingDetailSection(
                          title: '操作紀錄',
                          collapsible: true,
                          initiallyExpanded: false,
                          child: AdminBookingActionLogSection(
                            shopId: shopId,
                            bookingId: bookingId,
                          ),
                        ),
                      ],
                      handover: AdminInternalHandoverCard(
                        shopId: shopId,
                        bookingId: bookingId,
                        readOnly: BookingSettlementMath.isSettlementLocked(
                          data,
                        ),
                      ),
                      handoverHasContent: handoverHasContent,
                    );
                  },
            );
          },
        );
      },
    );
  }

  Widget _buildMemberAdminNote(Map<String, dynamic> bookingData) {
    final shopId = (bookingData['shopId'] ?? '').toString();
    final userId = (bookingData['userId'] ?? '').toString();

    if (shopId.isEmpty || userId.isEmpty) {
      return const SizedBox();
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .collection('members')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final note = (data['adminNote1'] ?? '').toString().trim();

        if (note.isEmpty) {
          return const SizedBox();
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12, bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.orange.shade100),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.note_alt_outlined, color: Colors.orange.shade800),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '店家會員備註：$note',
                  style: TextStyle(
                    color: Colors.orange.shade900,
                    fontWeight: FontWeight.w700,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _handleCheckOut({
    required BuildContext context,
    required Map<String, dynamic> data,
  }) async {
    final String shopId = (data['shopId'] ?? '').toString().trim();
    final AdminStaySettleResult? result = await showAdminStaySettleSheet(
      context: context,
      shopId: shopId,
      bookingId: bookingId,
      booking: data,
    );
    if (result == null) {
      return;
    }
    if (!context.mounted) {
      return;
    }

    List<String> evidenceImageUrls = <String>[];
    if (result.images.isNotEmpty) {
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('照片上傳中，請稍候...'),
            ],
          ),
        ),
      );
      try {
        evidenceImageUrls = await _uploadExtraChargeImages(
          bookingId: bookingId,
          images: result.images,
        );
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('照片上傳失敗：$e')));
        }
        return;
      }
      if (context.mounted) {
        Navigator.pop(context);
      }
    }

    final bool alreadyEnded =
        data['checkOutAt'] != null ||
        data['checkedOutAt'] != null ||
        (data['status'] ?? '').toString() == 'checked_out' ||
        data['stayRoomReleased'] == true;
    try {
      await BookingSettlementFunctionService.instance.call(
        shopId: shopId,
        bookingId: bookingId,
        action: 'checkOutStay',
        requestId: alreadyEnded
            ? 'checkOutStay_adjust_${DateTime.now().millisecondsSinceEpoch}'
            : 'checkOutStay_$bookingId',
        extra: <String, dynamic>{
          'manualAdjust': result.manualAdjust,
          'reason': result.manualAdjustReason,
          'settlementTopUpMethod': result.topUpMethod,
          'settlementRefundMethod': result.refundMethod,
          'settlementRefundNote': result.refundNote,
          'lockIfClear': result.lockIfClear,
          'evidenceImageUrls': evidenceImageUrls,
          if (result.rewardPointsAdjusted) ...<String, dynamic>{
            'rewardPointsAdjusted': true,
            'rewardPointsFinal': result.rewardPointsFinal,
            'rewardPointsAdjustReason': result.rewardPointsAdjustReason,
          },
        },
      );
    } on DaycareFunctionException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
      return;
    }

    try {
      final String checkoutShopId = (data['shopId'] ?? '').toString().trim();
      if (checkoutShopId.isNotEmpty) {
        final setting = await DailyCareSettingService.instance.getSetting(
          checkoutShopId,
        );
        final int downloadHours = setting.downloadHoursAfterCheckout;
        final DocumentSnapshot<Map<String, dynamic>> updatedBookingSnapshot =
            await FirebaseFirestore.instance
                .collection('bookings')
                .doc(bookingId)
                .get();
        final Map<String, dynamic> updatedBookingData =
            updatedBookingSnapshot.data() ?? <String, dynamic>{};
        final dynamic rawCheckOutAt =
            updatedBookingData['checkOutAt'] ??
            updatedBookingData['checkedOutAt'];
        DateTime? checkoutCompletedAt;
        if (rawCheckOutAt is Timestamp) {
          checkoutCompletedAt = rawCheckOutAt.toDate();
        } else if (rawCheckOutAt is DateTime) {
          checkoutCompletedAt = rawCheckOutAt;
        } else if (rawCheckOutAt is String) {
          checkoutCompletedAt = DateTime.tryParse(rawCheckOutAt);
        }
        checkoutCompletedAt ??= DateTime.now();
        final DateTime expiresAt = checkoutCompletedAt.add(
          Duration(hours: downloadHours),
        );
        final QuerySnapshot<Map<String, dynamic>> downloadSnapshot =
            await FirebaseFirestore.instance
                .collection('daily_care_photo_downloads')
                .where('bookingId', isEqualTo: bookingId)
                .get();
        if (downloadSnapshot.docs.isNotEmpty) {
          final WriteBatch batch = FirebaseFirestore.instance.batch();
          for (final doc in downloadSnapshot.docs) {
            batch.update(doc.reference, <String, dynamic>{
              'expiresAt': Timestamp.fromDate(expiresAt),
            });
          }
          await batch.commit();
        }
      }
    } catch (error, stackTrace) {
      debugPrint('退房完成，但更新照護照片下載期限失敗：$error');
      debugPrintStack(stackTrace: stackTrace);
    }

    final String userId = (data['userId'] ?? '').toString().trim();
    final String couponId = (data['couponId'] ?? '').toString().trim();
    if (couponId.isNotEmpty) {
      try {
        await MemberCouponService.instance.redeemCoupon(
          shopId: shopId,
          couponId: couponId,
          userId: userId,
          bookingId: bookingId,
        );
      } catch (error, stackTrace) {
        debugPrint('優惠券核銷失敗：$error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    final String roomId = (data['roomId'] ?? '').toString().trim();
    final String roomName = (data['roomName'] ?? '').toString().trim();
    if (shopId.isNotEmpty && roomId.isNotEmpty) {
      try {
        final setting = await HousekeepingSettingService.instance.getSetting(
          shopId,
        );
        if (setting.autoCleaningAfterCheckout) {
          final dynamic rawCheckoutDate = data['endDate'];
          DateTime? checkoutDate;
          if (rawCheckoutDate is Timestamp) {
            checkoutDate = rawCheckoutDate.toDate();
          } else if (rawCheckoutDate is DateTime) {
            checkoutDate = rawCheckoutDate;
          } else if (rawCheckoutDate is String) {
            checkoutDate = DateTime.tryParse(rawCheckoutDate);
          }
          if (checkoutDate != null) {
            await ShopRoomService.instance.startCleaningAfterCheckout(
              shopId: shopId,
              roomId: roomId,
              roomName: roomName,
              bookingId: bookingId,
              checkoutDate: checkoutDate,
            );
          }
        }
      } catch (error, stackTrace) {
        debugPrint('退房完成，但建立清潔中狀態失敗：$error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }
    try {
      await StayBookingFunctionService.instance.manage(
        shopId: shopId,
        bookingId: bookingId,
        action: 'release',
      );
    } catch (error, stackTrace) {
      debugPrint('退房釋放房型保留失敗：$error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<List<String>> _uploadExtraChargeImages({
    required String bookingId,
    required List<XFile> images,
  }) async {
    final List<String> urls = [];

    for (final image in images) {
      final bytes = await image.readAsBytes();

      if (bytes.length > 5 * 1024 * 1024) {
        throw Exception('圖片太大，請選擇 5MB 以下的圖片');
      }

      final ref = FirebaseStorage.instance
          .ref()
          .child('booking_extra_charges')
          .child(bookingId)
          .child('${DateTime.now().millisecondsSinceEpoch}_${image.name}');

      await ref.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      final url = await ref.getDownloadURL();
      urls.add(url);
    }

    return urls;
  }

  Future<void> _updateStatus(String newStatus) async {
    final user = FirebaseAuth.instance.currentUser;

    final doc = await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .get();

    final data = doc.data() ?? {};
    final oldStatus = data['status'] ?? '';

    await BookingService.instance.updateBookingStatus(
      bookingId: bookingId,
      status: newStatus,
    );

    await FirebaseFirestore.instance.collection('action_logs').add({
      'type': 'booking_status_update',

      /// 訂單資訊
      'bookingId': bookingId,
      'bookingShortId': bookingId.substring(0, 8),
      'shopId': data['shopId'],
      'roomId': data['roomId'],
      'roomName': data['roomName'],
      'roomTypeName': data['roomTypeName'],

      /// 狀態變化
      'fromStatus': oldStatus,
      'toStatus': newStatus,

      /// 操作者
      'operatorUid': user?.uid,
      'operatorRole': 'staff',
      'operatorEmail': user?.email,

      /// 時間
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// UI 小工具
  Future<void> _applyConfirmDeposit() {
    return AdminManualDepositConfirm.confirmStayBooking(bookingId: bookingId);
  }

  Future<void> _confirmDepositAndBooking(BuildContext context) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('確認收到訂金'),
          content: const Text('確認已收到訂金？此操作不可重複執行。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('確認'),
            ),
          ],
        );
      },
    );
    if (ok != true || !context.mounted) {
      return;
    }
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const AlertDialog(
          content: Row(
            children: <Widget>[
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Expanded(child: Text('正在確認訂金…')),
            ],
          ),
        );
      },
    );
    try {
      await _applyConfirmDeposit();
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('訂金已確認')));
      }
    } catch (error, stack) {
      ChatErrorProbe.dump(
        'AdminBookingDetail confirmDeposit',
        error,
        stack,
        operation: 'bookings/$bookingId confirmStayBooking',
      );
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(ChatErrorProbe.describe(error))));
      }
    }
  }
}
