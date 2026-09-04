// 客戶訂單詳細頁顯示資料與入住前準備解析測試

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
    test('住宿訂單顯示住宿詳細', () {
      final BookingDetailViewData view = BookingDetailViewData.fromBooking(
        data: <String, dynamic>{'bookingKind': 'accommodation'},
        docId: 'abc123456',
      );
      expect(view.pageTitle, '住宿詳細');
      expect(view.pageTitle.contains('臨托'), isFalse);
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
