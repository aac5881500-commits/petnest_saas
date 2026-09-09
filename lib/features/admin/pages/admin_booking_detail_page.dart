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
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/custom_form/widgets/custom_form_answer_view.dart';
import 'package:petnest_saas/core/services/booking_service.dart';
import 'package:petnest_saas/core/services/daycare_payment_display.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/core/exceptions/inventory_exception.dart';
import 'package:petnest_saas/core/services/member_point_service.dart';
import 'package:petnest_saas/core/services/member_coupon_service.dart';
import 'package:petnest_saas/core/services/point_setting_service.dart';
import 'package:petnest_saas/core/services/housekeeping_setting_service.dart';
import 'package:petnest_saas/core/services/shop_room_service.dart';
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
import 'package:petnest_saas/features/admin/widgets/admin_booking_note_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_pet_strip.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_price_section.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_status_chip.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_text_helpers.dart';
import 'package:petnest_saas/features/admin/widgets/admin_booking_timeline.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_message_section.dart';
import 'package:petnest_saas/core/services/daily_care_setting_service.dart';

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

        final rawPets = data['pets'];

        final List<Map<String, dynamic>> pets = rawPets is List
            ? rawPets.map((e) => Map<String, dynamic>.from(e as Map)).toList()
            : <Map<String, dynamic>>[];

        final status = data['status'] ?? 'pending';

        final emergency = Map<String, dynamic>.from(
          data['emergencyContact'] ?? {},
        );

        final depositPaid = data['depositPaid'] == true;
        final depositAmount = data['depositAmount'] ?? 0;
        final depositRequired = data['depositRequired'] == true;
        final String shopId = (data['shopId'] ?? '').toString();
        final String bookingCode = (data['bookingCode'] ?? '')
            .toString()
            .trim();

        return ShopFrontendThemeScope(
          shopId: shopId,
          builder: (BuildContext context) {
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
              actions: canEdit
                  ? AdminBookingDetailCard(
                      child: AdminBookingActionSection(
                        data: data,
                        status: status,
                        depositAmount: depositAmount,
                        depositPaid: depositPaid,
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
                          await _confirmDepositAndBooking();
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
                              const SnackBar(content: Text('此訂單尚未分房，不能辦理入住')),
                            );
                            return;
                          }
                          try {
                            await BookingService.instance.checkInBooking(
                              bookingId: bookingId,
                            );
                            await FirebaseFirestore.instance
                                .collection('action_logs')
                                .add({
                                  'type': 'booking_status_update',
                                  'bookingId': bookingId,
                                  'bookingShortId': bookingId.substring(0, 8),
                                  'shopId': data['shopId'],
                                  'roomId': data['roomId'],
                                  'roomName': data['roomName'],
                                  'roomTypeName': data['roomTypeName'],
                                  'fromStatus': status,
                                  'toStatus': 'checked_in',
                                  'operatorUid':
                                      FirebaseAuth.instance.currentUser?.uid,
                                  'operatorRole': 'staff',
                                  'operatorEmail':
                                      FirebaseAuth.instance.currentUser?.email,
                                  'createdAt': FieldValue.serverTimestamp(),
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
                          await _handleCheckOut(context: context, data: data);
                        },
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
                _buildMemberAdminNote(data),
                AdminBookingDetailSection(
                  title: '寵物資訊（${pets.length}隻）',
                  child: AdminBookingPetStrip(
                    pets: pets,
                    shopId: shopId,
                    userId: (data['userId'] ?? '').toString(),
                  ),
                ),
                AdminBookingDetailSection(
                  title: '價格與加值服務',
                  child: AdminBookingPriceSection(
                    data: data,
                    pets: pets,
                    lineItemsOnly: true,
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
                CustomFormAnswerView(
                  raw:
                      data['customFormAnswers'] ??
                      data['bookingFormAnswers'] ??
                      data['formAnswers'],
                  title: '本次照護交代',
                  theme: HomeThemeModel.classicDefault,
                  collapsible: true,
                ),
                AdminBookingDetailSection(
                  title: '訂單備註',
                  collapsible: true,
                  initiallyExpanded: false,
                  child: AdminBookingNoteSection(data: data),
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
                AdminBookingDetailPaymentAside(
                  data: data,
                  bookingId: bookingId,
                ),
                AdminBookingDetailPolicyCard(data: data),
                AdminBookingDetailSection(
                  title: '訂單時間軸',
                  collapsible: true,
                  child: AdminBookingTimeline(
                    data: data,
                    status: status,
                    depositRequired: depositRequired,
                  ),
                ),
                AdminBookingDetailSection(
                  title: '狀態',
                  collapsible: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      AdminBookingStatusChip(status: status.toString()),
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
    final extraFeeController = TextEditingController();
    final extraChargeTitleController = TextEditingController(text: '額外清潔費');
    final extraChargeNoteController = TextEditingController();

    List<XFile> extraChargeImages = [];
    bool isUploadingExtraImage = false;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('退房 - 額外收費'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: extraChargeTitleController,
                decoration: const InputDecoration(
                  labelText: '費用名稱',
                  hintText: '例如：額外清潔費',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: extraFeeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '金額',
                  hintText: '例如：300',
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: extraChargeNoteController,
                decoration: const InputDecoration(
                  labelText: '備註',
                  hintText: '例如：退房時發現亂尿尿',
                ),
              ),
              const SizedBox(height: 12),
              StatefulBuilder(
                builder: (context, setDialogState) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () async {
                          if (isUploadingExtraImage) return;

                          if (extraChargeImages.length >= 3) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('最多只能上傳 3 張照片')),
                            );
                            return;
                          }

                          setDialogState(() {
                            isUploadingExtraImage = true;
                          });

                          final picked = await ImagePicker().pickImage(
                            source: ImageSource.gallery,
                            maxWidth: 1200,
                            imageQuality: 75,
                          );

                          if (picked != null) {
                            extraChargeImages.add(picked);
                          }

                          setDialogState(() {
                            isUploadingExtraImage = false;
                          });
                        },
                        icon: Icon(
                          isUploadingExtraImage
                              ? Icons.hourglass_top
                              : Icons.photo_library,
                        ),
                        label: Text(
                          isUploadingExtraImage ? '照片處理中...' : '選擇照片',
                        ),
                      ),
                      if (extraChargeImages.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '已選擇 ${extraChargeImages.length} 張照片',
                            style: const TextStyle(
                              color: Colors.green,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, extraFeeController.text);
              },
              child: const Text('確認退房'),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    final confirmCheckout = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('確認退房'),
        content: const Text('確定要將此訂單改為退房完成嗎？此操作會結束本次入住流程。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('返回'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('確認退房'),
          ),
        ],
      ),
    );

    if (confirmCheckout != true) return;

    final extraFee = int.tryParse(result) ?? 0;
    final extraChargeTitle = extraChargeTitleController.text.trim();
    final extraChargeNote = extraChargeNoteController.text.trim();

    final List<Map<String, dynamic>> extraCharges = [];
    List<String> evidenceImageUrls = [];

    if (extraChargeImages.isNotEmpty) {
      showDialog(
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
          images: extraChargeImages,
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

    if (extraFee > 0) {
      extraCharges.add({
        'title': extraChargeTitle.isEmpty ? '退房額外費用' : extraChargeTitle,
        'amount': extraFee,
        'note': extraChargeNote,
        'imageUrls': evidenceImageUrls,
        'createdAt': Timestamp.now(),
      });
    }

    final now = FieldValue.serverTimestamp();

    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({
          'checkOutAt': now,
          'extraFee': extraFee,
          'extraCharges': FieldValue.arrayUnion(extraCharges),
          'status': 'completed',
          'updatedAt': now,
        });
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

        final dynamic rawCheckOutAt = updatedBookingData['checkOutAt'];

        DateTime? checkoutCompletedAt;

        if (rawCheckOutAt is Timestamp) {
          checkoutCompletedAt = rawCheckOutAt.toDate();
        } else if (rawCheckOutAt is DateTime) {
          checkoutCompletedAt = rawCheckOutAt;
        } else if (rawCheckOutAt is String) {
          checkoutCompletedAt = DateTime.tryParse(rawCheckOutAt);
        }

        if (checkoutCompletedAt == null) {
          throw StateError('退房完成，但找不到有效的 checkOutAt');
        }

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

    final String shopId = (data['shopId'] ?? '').toString().trim();
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

    /// 退房後依房務設定，將退房當日設為清潔中。
    ///
    /// 清潔狀態寫入失敗時，不阻斷後續的點數、報表與操作紀錄流程。
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
          } else {
            debugPrint('退房完成，但無法解析退房日期：$rawCheckoutDate');
          }
        }
      } catch (error, stackTrace) {
        debugPrint('退房完成，但建立清潔中狀態失敗：$error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    final bool rewardPointIssued = data['rewardPointIssued'] == true;

    if (!rewardPointIssued && shopId.isNotEmpty && userId.isNotEmpty) {
      try {
        final int orderAmount =
            ((data['totalPrice'] ?? data['total'] ?? 0) as num).toInt();

        final int nights = ((data['nights'] ?? 0) as num).toInt();

        final int rewardPoints = await PointSettingService.instance
            .calculateBookingPoints(
              shopId: shopId,
              orderAmount: orderAmount,
              nights: nights,
            );

        if (rewardPoints > 0) {
          await MemberPointService.instance.addBookingPoints(
            shopId: shopId,
            userId: userId,
            bookingId: bookingId,
            points: rewardPoints,
            note: '訂單完成自動發放',
          );
        }
      } catch (error, stackTrace) {
        debugPrint('訂單完成，但自動發放點數失敗：$error');
        debugPrintStack(stackTrace: stackTrace);
      }
    }

    await FirebaseFirestore.instance.collection('reports').add({
      'shopId': data['shopId'],
      'bookingId': bookingId,
      'roomName': data['roomName'],
      'totalPrice': data['totalPrice'] ?? 0,
      'extraFee': extraFee,
      'extraCharges': extraCharges,
      'finalAmount': (data['totalPrice'] ?? 0) + extraFee,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final user = FirebaseAuth.instance.currentUser;

    await FirebaseFirestore.instance.collection('action_logs').add({
      'type': 'checkout_completed',
      'bookingId': bookingId,
      'bookingShortId': bookingId.substring(0, 8),
      'shopId': data['shopId'],
      'roomId': data['roomId'],
      'roomName': data['roomName'],
      'roomTypeName': data['roomTypeName'],
      'totalPrice': data['totalPrice'] ?? 0,
      'extraFee': extraFee,
      'finalAmount': (data['totalPrice'] ?? 0) + extraFee,
      'extraCharges': extraCharges,
      'extraChargeImageCount': evidenceImageUrls.length,
      'operatorUid': user?.uid,
      'operatorRole': 'staff',
      'operatorEmail': user?.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
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
  Future<void> _confirmDepositAndBooking() async {
    final user = FirebaseAuth.instance.currentUser;
    final DocumentSnapshot<Map<String, dynamic>> current =
        await FirebaseFirestore.instance
            .collection('bookings')
            .doc(bookingId)
            .get();
    final Map<String, dynamic> before = current.data() ?? <String, dynamic>{};
    if (before['depositPaid'] == true ||
        (before['depositStatus'] ?? '').toString() == 'confirmed') {
      return;
    }
    final int totalAmount = DaycarePaymentDisplay.resolveTotal(before);
    final int depositAmount = SafeParse.parseMoney(before['depositAmount']);
    final int existingPaid = SafeParse.parseMoney(before['paidAmount']);
    final int paid = existingPaid > depositAmount
        ? existingPaid
        : depositAmount;
    final int remaining = totalAmount - paid < 0 ? 0 : totalAmount - paid;
    final String paymentStatus = paid >= totalAmount && totalAmount > 0
        ? 'paid'
        : (paid > 0 ? 'partial' : 'unpaid');

    await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .update({
          'depositPaid': true,
          'depositStatus': 'confirmed',
          'depositPaidAt': FieldValue.serverTimestamp(),
          'confirmedAt': FieldValue.serverTimestamp(),
          'status': 'confirmed',
          'paidAmount': paid,
          'remainingAmount': remaining,
          'paymentStatus': paymentStatus,
          'updatedAt': FieldValue.serverTimestamp(),
        });

    final doc = await FirebaseFirestore.instance
        .collection('bookings')
        .doc(bookingId)
        .get();

    final data = doc.data() ?? {};

    await FirebaseFirestore.instance.collection('action_logs').add({
      'type': 'deposit_confirmed',

      /// 訂單資訊
      'bookingId': bookingId,
      'bookingShortId': bookingId.substring(0, 8),
      'shopId': data['shopId'],
      'roomId': data['roomId'],
      'roomName': data['roomName'],
      'roomTypeName': data['roomTypeName'],

      /// 訂金資訊
      'depositAmount': data['depositAmount'] ?? 0,
      'paymentMethod': data['paymentMethod'],
      'transferLast5': data['transferLast5'],

      /// 操作者
      'operatorUid': user?.uid,
      'operatorRole': 'staff',
      'operatorEmail': user?.email,

      /// 時間
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
