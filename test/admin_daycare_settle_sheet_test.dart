// 檔案名稱：test/admin_daycare_settle_sheet_test.dart
// 功能說明：安親結算 UI 不再出現免收本次超時費

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';

void main() {
  test('安親結算 UI 不存在免收本次超時費', () {
    final String src = File(
      'lib/features/admin/widgets/admin_daycare_settle_sheet.dart',
    ).readAsStringSync();
    expect(src.contains('免收本次超時費'), isFalse);
    expect(src.contains('免收原因'), isFalse);
    expect(src.contains('_waiveOvertime'), isFalse);
    expect(src.contains('＋ 加收'), isTrue);
    expect(src.contains('－ 減免'), isTrue);
    expect(src.contains('actualTimesError'), isTrue);
    expect(src.contains('DateTime.now().add(const Duration(days: 2))'), isFalse);
    expect(src.contains('晚接回超時計費'), isTrue);
  });

  test('實際接回不可晚於現在', () {
    final DateTime now = DateTime(2026, 9, 13, 13, 42);
    expect(
      DaycareTimeHelper.actualTimesError(
        actualStartAt: DateTime(2026, 9, 13, 13, 40),
        actualEndAt: DateTime(2026, 9, 13, 21, 40),
        now: now,
      ),
      DaycareTimeHelper.actualEndInFutureMessage,
    );
  });

  test('住宿退房結算 UI 與安親同套加收減免', () {
    final String src = File(
      'lib/features/admin/widgets/admin_stay_settle_sheet.dart',
    ).readAsStringSync();
    expect(src.contains('＋ 加收'), isTrue);
    expect(src.contains('－ 減免'), isTrue);
    expect(src.contains('⚠ 調整原因（必填）'), isTrue);
    expect(src.contains('額外清潔費'), isFalse);
  });

  test('核對轉帳改讀 paymentProofs，無照片可現場核對', () {
    final String src = File(
      'lib/features/admin/widgets/admin_booking_settlement_panel.dart',
    ).readAsStringSync();
    expect(src.contains('latestUnconfirmedBalance'), isTrue);
    expect(src.contains("'proofId': proof.proofId"), isTrue);
    expect(src.contains('核對客戶回傳'), isTrue);
    expect(src.contains('現場已核對入帳'), isTrue);
    expect(src.contains('confirmStaffVerifiedTransfer'), isTrue);
    expect(src.contains('等待結算尾款證明'), isFalse);
    expect(
      src.contains("settlementTopUpTransferImageUrl'] ?? '尚未上傳'"),
      isFalse,
    );
  });

  test('結算減免後依待補待退顯示補款或退款', () {
    final String stay = File(
      'lib/features/admin/widgets/admin_stay_settle_sheet.dart',
    ).readAsStringSync();
    final String daycare = File(
      'lib/features/admin/widgets/admin_daycare_settle_sheet.dart',
    ).readAsStringSync();
    expect(stay.contains('SettlementRefundMethodPicker'), isTrue);
    expect(stay.contains('_showTopUp'), isTrue);
    expect(daycare.contains('SettlementRefundMethodPicker'), isTrue);
    expect(daycare.contains('_showRefund'), isTrue);
    expect(daycare.contains('DaycareTimeHelper.callableInstant'), isTrue);
    final String labels = File(
      'lib/core/services/settlement_adjust_display.dart',
    ).readAsStringSync();
    expect(labels.contains('現場退款'), isTrue);
    expect(labels.contains('銀行退款'), isTrue);
    expect(labels.contains('其他退款'), isTrue);
  });
}
