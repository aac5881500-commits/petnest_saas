// 檔案名稱：test/booking_detail_view_data_test.dart
// 功能說明：客戶訂單詳細頁顯示資料與入住前準備解析測試

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_view_data.dart';

void main() {
  group('SafeParse', () {
    test('金額相容 int、double、字串', () {
      expect(SafeParse.parseMoney(1200), 1200);
      expect(SafeParse.parseMoney(1200.6), 1201);
      expect(SafeParse.parseMoney('1,250'), 1250);
      expect(SafeParse.parseMoney('99.4'), 99);
      expect(SafeParse.parseMoney(null), 0);
    });

    test('bool 相容 true／false、0／1 與字串', () {
      expect(SafeParse.parseBool(true), isTrue);
      expect(SafeParse.parseBool(1), isTrue);
      expect(SafeParse.parseBool('true'), isTrue);
      expect(SafeParse.parseBool('1'), isTrue);
      expect(SafeParse.parseBool(false), isFalse);
      expect(SafeParse.parseBool(0), isFalse);
      expect(SafeParse.parseBool('false'), isFalse);
    });
  });

  group('BookingDetailViewData', () {
    test('客戶端永不顯示手動訂單表單', () {
      final BookingDetailViewData view = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{
          'source': 'admin',
          'adminCustomFormAnswers': <String, dynamic>{
            'answers': <Map<String, dynamic>>[
              <String, dynamic>{'displayValue': '內部'},
            ],
          },
        },
        docId: 'b1',
      );
      expect(view.showAdminCreateFormOnCustomerPage, isFalse);
    });

    test('客戶自助訂單才顯示客戶送單表單', () {
      expect(
        BookingDetailViewData.fromBooking(
          data: <String, dynamic>{
            'source': 'app',
            'customFormAnswers': <String, dynamic>{'q1': '是'},
          },
          docId: 'b1',
        ).showCustomerSubmitFormOnCustomerPage,
        isTrue,
      );
      expect(
        BookingDetailViewData.fromBooking(
          data: <String, dynamic>{
            'source': 'admin',
            'customFormAnswers': <String, dynamic>{'q1': '是'},
          },
          docId: 'b1',
        ).showCustomerSubmitFormOnCustomerPage,
        isFalse,
      );
    });

    test('安親訂單顯示安親詳細，不顯示臨托', () {
      final BookingDetailViewData view = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{'bookingKind': 'daycare'},
        docId: 'abc123456',
      );
      expect(view.pageTitle, '安親詳細');
      expect(view.serviceLabel, '安親');
      expect(view.pageTitle.contains('臨托'), isFalse);
      expect(view.serviceLabel.contains('臨托'), isFalse);
    });

    test('安親小時計費明細顯示起步與超過起步，不用方案名稱當時間費', () {
      final BookingDetailViewData view = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{
          'bookingKind': 'daycare',
          'totalPrice': 1500,
          'daycarePlanName': '每小時計費',
          'daycarePlanSnapshot': <String, dynamic>{
            'name': '每小時計費',
            'includedMinutes': 120,
            'basePrice': 200,
            'extraBillingMinutes': 60,
            'extraBillingPrice': 100,
          },
          'daycarePricingSnapshot': <String, dynamic>{
            'baseAmount': 200,
            'extraTimeAmount': 800,
            'extraMinutes': 480,
            'extraUnits': 8,
            'includedMinutes': 120,
            'extraBillingMinutes': 60,
            'timeCharge': 1000,
            'addonAmount': 500,
            'totalAmount': 1500,
            'durationMinutes': 600,
          },
          'addons': <Map<String, dynamic>>[
            <String, dynamic>{'name': '加值 A', 'total': 300},
            <String, dynamic>{'name': '加值 B', 'total': 200},
          ],
        },
        docId: 'id',
      );
      expect(view.daycareBillingRuleText, contains('起步 2 小時 NT\$200'));
      expect(
        view.feeLines.any((BookingDetailFeeLine line) => line.label == '每小時計費'),
        isFalse,
      );
      expect(
        view.feeLines.any(
          (BookingDetailFeeLine line) =>
              line.label.startsWith('起步費') && line.amount == 200,
        ),
        isTrue,
      );
      expect(
        view.feeLines.any(
          (BookingDetailFeeLine line) =>
              line.label.contains('超過起步') && line.amount == 800,
        ),
        isTrue,
      );
      expect(
        view.feeLines.any(
          (BookingDetailFeeLine line) =>
              line.label == '加值 A' && line.amount == 300,
        ),
        isTrue,
      );
      expect(
        view.feeLines
            .firstWhere((BookingDetailFeeLine line) => line.isTotal)
            .amount,
        1500,
      );
    });

    test('未分房不顯示 ---', () {
      final BookingDetailViewData view = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{
          'bookingKind': 'accommodation',
          'roomTypeName': '貓咪套房',
          'roomId': null,
          'roomName': null,
        },
        docId: 'id',
      );
      expect(view.roomAssignmentLabel.contains('---'), isFalse);
      expect(view.roomAssignmentLabel, contains('店家確認後安排房間'));
    });

    test('住宿顯示晚數，安親顯示天數', () {
      final BookingDetailViewData stay = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{'bookingKind': 'accommodation', 'nights': 3},
        docId: 'id',
      );
      expect(stay.durationLabel, '3 晚');

      final BookingDetailViewData daycare = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{
          'bookingKind': 'daycare',
          'startDate': DateTime(2026, 8, 1),
          'endDate': DateTime(2026, 8, 2),
        },
        docId: 'id',
      );
      expect(daycare.durationLabel.contains('晚'), isFalse);
      expect(daycare.durationLabel, contains('天'));
    });

    test('費用 0 的空項目隱藏', () {
      final BookingDetailViewData view = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{
          'totalPrice': 2000,
          'basePrice': 2000,
          'nights': 1,
          'discountAmount': 0,
          'couponDiscountAmount': 0,
          'extraPetTotal': 0,
        },
        docId: 'id',
      );
      expect(
        view.feeLines.any(
          (BookingDetailFeeLine line) => line.label == '優惠活動折扣',
        ),
        isFalse,
      );
      expect(
        view.feeLines.any((BookingDetailFeeLine line) => line.label == '優惠券折扣'),
        isFalse,
      );
    });

    test('已付款顯示已付清', () {
      final BookingDetailViewData view = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{
          'totalPayableAmount': 3000,
          'paidAmount': 3000,
          'remainingAmount': 0,
        },
        docId: 'id',
      );
      expect(view.isPaidInFull, isTrue);
      expect(view.paymentStatusLabel, '已付清');
    });

    test('有剩餘金額顯示待付款', () {
      final BookingDetailViewData view = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{
          'totalPrice': 3000,
          'paidAmount': 1000,
          'remainingAmount': 2000,
          'status': 'pending',
        },
        docId: 'id',
      );
      expect(view.remainingAmount, 2000);
      expect(view.paymentStatusLabel, '待付款');
    });

    test('沒有 extraCharges 不顯示退房結算', () {
      final BookingDetailViewData view = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{},
        docId: 'id',
      );
      expect(view.hasExtraCharges, isFalse);
    });

    test('沒有 note 不顯示備註卡', () {
      final BookingDetailViewData empty = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{'note': ''},
        docId: 'id',
      );
      expect(empty.showCustomerNote, isFalse);
      final BookingDetailViewData none = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{'note': '無'},
        docId: 'id',
      );
      expect(none.showCustomerNote, isFalse);
    });

    test('只有一隻寵物不留下三欄結構資料', () {
      final BookingDetailViewData view = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{
          'pets': <Map<String, dynamic>>[
            <String, dynamic>{'name': '小白', 'photoUrl': ''},
          ],
        },
        docId: 'id',
      );
      expect(view.petInfos.length, 1);
    });

    test('已完成才顯示評價', () {
      final BookingDetailViewData pending = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{'status': 'checked_in'},
        docId: 'id',
      );
      expect(pending.showReview, isFalse);
      final BookingDetailViewData done = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{'status': 'completed'},
        docId: 'id',
      );
      expect(done.showReview, isTrue);
      expect(done.reviewLabel, '住宿評價');
    });

    test('入住中才顯示攝影機條件', () {
      final BookingDetailViewData inStay = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{
          'status': 'checked_in',
          'shopId': 'shop1',
          'roomId': 'room1',
        },
        docId: 'id',
      );
      expect(inStay.showCamera, isTrue);
      final BookingDetailViewData pending = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{
          'status': 'pending',
          'shopId': 'shop1',
          'roomId': 'room1',
        },
        docId: 'id',
      );
      expect(pending.showCamera, isFalse);
    });

    test('未入住不顯示照護；入住後可看', () {
      final BookingDetailViewData pending = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{
          'status': 'confirmed',
          'bookingKind': 'daycare',
        },
        docId: 'id',
      );
      expect(
        pending.canViewDailyCare(
          downloadHoursAfterCheckout: 24,
          daycareCareEnabled: true,
        ),
        isFalse,
      );
      final BookingDetailViewData inStay = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{
          'status': 'checked_in',
          'bookingKind': 'daycare',
        },
        docId: 'id',
      );
      expect(
        inStay.canViewDailyCare(
          downloadHoursAfterCheckout: 24,
          daycareCareEnabled: true,
        ),
        isTrue,
      );
      final BookingDetailViewData stayPending =
          BookingDetailViewData.fromBooking(
            data: <String, dynamic>{'status': 'confirmed'},
            docId: 'id',
          );
      expect(
        stayPending.canViewDailyCare(downloadHoursAfterCheckout: 24),
        isFalse,
      );
    });

    test('照護下載期限仍以 checkOutAt 計算', () {
      final DateTime checkOut = DateTime(2026, 8, 1, 12);
      final BookingDetailViewData view = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{'status': 'completed', 'checkOutAt': checkOut},
        docId: 'id',
      );
      expect(
        view.dailyCareDownloadDeadline(24),
        checkOut.add(const Duration(hours: 24)),
      );
      expect(
        view.dailyCareDownloadExpired(
          downloadHoursAfterCheckout: 24,
          now: checkOut.add(const Duration(hours: 25)),
        ),
        isTrue,
      );
    });

    test('舊訂單缺少新欄位不崩潰', () {
      final BookingDetailViewData view = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{'status': 'pending'},
        docId: 'short',
      );
      expect(view.pageTitle, '住宿詳細');
      expect(view.bookingCode, 'short');
      expect(view.feeLines, isNotEmpty);
      expect(view.roomAssignmentLabel.contains('---'), isFalse);
    });

    test('安親結算手動加收顯示店家調整說明，沒原因不捏造', () {
      final BookingDetailViewData withReason =
          BookingDetailViewData.fromBooking(
            data: <String, dynamic>{
              'bookingKind': 'daycare',
              'settlementConfirmed': true,
              'quotedTotalPrice': 1000,
              'overtimeAmount': 0,
              'manualAdjust': 500,
              'manualAdjustmentReason': '測試',
            },
            docId: 'id',
          );
      final BookingDetailFeeLine add = withReason.feeLines.firstWhere(
        (BookingDetailFeeLine line) => line.label == '手動加收',
      );
      expect(add.amount, 500);
      expect(add.subtitle, '店家調整說明：測試');

      final BookingDetailViewData discount = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{
          'bookingKind': 'daycare',
          'settlementConfirmed': true,
          'quotedTotalPrice': 1000,
          'overtimeAmount': 0,
          'manualAdjust': -300,
          'manualAdjustReason': '提早接回',
        },
        docId: 'id',
      );
      final BookingDetailFeeLine minus = discount.feeLines.firstWhere(
        (BookingDetailFeeLine line) => line.label == '手動減免',
      );
      expect(minus.amount, 300);
      expect(minus.subtitle, '店家調整說明：提早接回');

      final BookingDetailViewData legacy = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{
          'bookingKind': 'daycare',
          'settlementConfirmed': true,
          'quotedTotalPrice': 1000,
          'manualAdjust': 500,
        },
        docId: 'id',
      );
      final BookingDetailFeeLine noReason = legacy.feeLines.firstWhere(
        (BookingDetailFeeLine line) => line.label == '手動加收',
      );
      expect(noReason.subtitle, '');
    });

    test('店家內部備註不會出現在客戶備註', () {
      final BookingDetailViewData view = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{
          'note': '',
          'staffNote': '內部備註',
          'adminNote': '不要給客人',
        },
        docId: 'id',
      );
      expect(view.showCustomerNote, isFalse);
      expect(view.customerNote.contains('內部'), isFalse);
    });
  });

  group('PreArrivalGuideModel', () {
    test('停用時客戶不顯示', () {
      final PreArrivalGuideModel guide = PreArrivalGuideModel.fromMap(
        shopId: 'shopA',
        serviceType: 'accommodation',
        data: <String, dynamic>{
          'enabled': false,
          'title': '入住前請準備',
          'blocks': <Map<String, dynamic>>[
            <String, dynamic>{'id': '1', 'type': 'text', 'text': '請帶項圈'},
          ],
        },
      );
      expect(guide.hasCustomerContent, isFalse);
    });

    test('只有文字內容可正常顯示', () {
      final PreArrivalGuideModel guide = PreArrivalGuideModel.fromMap(
        shopId: 'shopA',
        serviceType: 'accommodation',
        data: <String, dynamic>{
          'enabled': true,
          'blocks': <Map<String, dynamic>>[
            <String, dynamic>{'id': '1', 'type': 'text', 'text': '請帶飼料'},
            <String, dynamic>{'id': '2', 'type': 'image', 'imageUrl': ''},
          ],
        },
      );
      expect(guide.hasCustomerContent, isTrue);
      expect(guide.visibleBlocks.length, 1);
      expect(guide.visibleBlocks.first.type, 'text');
    });

    test('只有圖片內容可正常顯示', () {
      final PreArrivalGuideModel guide = PreArrivalGuideModel.fromMap(
        shopId: 'shopA',
        serviceType: 'accommodation',
        data: <String, dynamic>{
          'enabled': '1',
          'blocks': <Map<String, dynamic>>[
            <String, dynamic>{
              'id': '1',
              'type': 'image',
              'imageUrl': 'https://example.com/a.jpg',
              'storagePath':
                  'shops/shopA/pre_arrival_guides/accommodation/1.jpg',
            },
          ],
        },
      );
      expect(guide.visibleBlocks.length, 1);
      expect(guide.visibleBlocks.first.type, 'image');
    });

    test('安親沿用住宿內容可正常顯示', () {
      final PreArrivalGuideModel daycare = PreArrivalGuideModel.fromMap(
        shopId: 'shopA',
        serviceType: 'daycare',
        data: <String, dynamic>{
          'enabled': true,
          'inheritAccommodation': true,
          'blocks': <dynamic>[],
        },
      );
      expect(daycare.inheritAccommodation, isTrue);
      final PreArrivalGuideModel accommodation = PreArrivalGuideModel.fromMap(
        shopId: 'shopA',
        serviceType: 'accommodation',
        data: <String, dynamic>{
          'enabled': true,
          'title': '住宿準備',
          'blocks': <Map<String, dynamic>>[
            <String, dynamic>{'id': '1', 'type': 'heading', 'text': '攜帶物品'},
          ],
        },
      );
      expect(accommodation.hasCustomerContent, isTrue);
    });

    test('不同 shopId 文件各自獨立', () {
      final PreArrivalGuideModel a = PreArrivalGuideModel.fromMap(
        shopId: 'shopA',
        serviceType: 'accommodation',
        data: <String, dynamic>{'shopId': 'shopA', 'enabled': true},
      );
      final PreArrivalGuideModel b = PreArrivalGuideModel.fromMap(
        shopId: 'shopB',
        serviceType: 'accommodation',
        data: <String, dynamic>{'shopId': 'shopB', 'enabled': true},
      );
      expect(a.shopId, isNot(b.shopId));
    });
  });
}
