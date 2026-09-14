// 檔案名稱：test/booking_action_log_display_test.dart
// 功能說明：操作紀錄前後值與金額顯示，相容舊欄位

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/booking_action_log_display.dart';

void main() {
  test('分配房間顯示未分房到房號', () {
    final List<String> lines = BookingActionLogDisplay.detailLines(
      <String, dynamic>{
        'type': 'room_assigned',
        'roomTypeName': '舒適標準房',
        'roomName': 'A5',
      },
    );
    expect(BookingActionLogDisplay.title(<String, dynamic>{'type': 'room_assigned'}), '分配房間');
    expect(lines, contains('房型：舒適標準房'));
    expect(lines.any((String line) => line.contains('未分房') && line.contains('A5')), isTrue);
  });

  test('更換房間顯示舊到新與原因', () {
    final Map<String, dynamic> log = <String, dynamic>{
      'type': 'room_changed',
      'oldRoomName': 'A5',
      'newRoomName': 'A3',
      'reason': '清潔',
    };
    expect(BookingActionLogDisplay.title(log), '更換房間');
    final List<String> lines = BookingActionLogDisplay.detailLines(log);
    expect(lines.any((String line) => line.contains('A5') && line.contains('A3')), isTrue);
    expect(lines, contains('原因：清潔'));
  });

  test('手動調整顯示前後應收與正負金額', () {
    final List<String> plus = BookingActionLogDisplay.detailLines(
      <String, dynamic>{
        'action': 'settlement_applyAdjust',
        'payload': <String, dynamic>{
          'before': 2000,
          'after': 2500,
          'delta': 500,
          'reason': '加收清潔',
        },
      },
    );
    expect(plus, contains('舊最終應收 NT\$ 2000'));
    expect(plus, contains('調整金額 +NT\$ 500'));
    expect(plus, contains('新最終應收 NT\$ 2500'));
    expect(plus, contains('原因：加收清潔'));

    final List<String> minus = BookingActionLogDisplay.detailLines(
      <String, dynamic>{
        'type': 'settlement_applyAdjust',
        'before': 2500,
        'after': 2200,
        'delta': -300,
        'reason': '減免',
      },
    );
    expect(minus, contains('調整金額 -NT\$ 300'));
    expect(minus, contains('新最終應收 NT\$ 2200'));
  });

  test('舊換房 log 只有 roomId 時不露出 id', () {
    const String roomId = 'T7D4M2h7qbCAWoz37pWD';
    final Map<String, dynamic> log = <String, dynamic>{
      'type': 'room_changed',
      'fromRoomId': roomId,
      'fromRoomName': roomId,
      'toRoomName': 'A1',
      'roomTypeName': '舒適標準房',
      'reason': '清潔調度',
    };
    expect(BookingActionLogDisplay.title(log), '更換房間');
    final List<String> unresolved = BookingActionLogDisplay.detailLines(log);
    expect(unresolved.join('\n').contains(roomId), isFalse);
    expect(unresolved, contains('實際房間：原房間資料已不存在 → A1'));
    expect(unresolved, contains('原因：清潔調度'));

    final List<String> resolved = BookingActionLogDisplay.detailLines(
      log,
      roomNames: <String, String>{roomId: 'A5'},
    );
    expect(resolved, contains('實際房間：A5 → A1'));
    expect(resolved.join('\n').contains(roomId), isFalse);
  });

  test('付款方式變更顯示中文', () {
    final List<String> lines = BookingActionLogDisplay.detailLines(
      <String, dynamic>{
        'type': 'payment_choice_changed',
        'mode': 'settlement_top_up',
        'previousPaymentMethod': 'credit_card',
        'paymentMethod': 'atm',
        'previousSettlementTopUpStatus': 'awaiting_supplement',
        'settlementTopUpStatus': 'selected',
      },
    );
    expect(BookingActionLogDisplay.title(<String, dynamic>{
      'type': 'payment_choice_changed',
    }), '變更付款方式');
    expect(lines, contains('結算尾款付款方式：信用卡 → ATM 虛擬帳號'));
    expect(lines, contains('付款狀態：待補款 → 已選擇付款方式'));
    expect(lines.join('\n').contains('credit_card'), isFalse);
  });

  test('結算標題顯示具體動作', () {
    expect(
      BookingActionLogDisplay.title(<String, dynamic>{
        'type': 'daycare_settle',
      }),
      '確認安親結算',
    );
    expect(
      BookingActionLogDisplay.title(<String, dynamic>{
        'action': 'settlement_applyAdjust',
        'delta': 500,
      }),
      '手動加收 NT\$ 500',
    );
    expect(
      BookingActionLogDisplay.title(<String, dynamic>{
        'action': 'settlement_applyAdjust',
        'delta': -300,
      }),
      '手動減免 NT\$ 300',
    );
    expect(
      BookingActionLogDisplay.title(<String, dynamic>{
        'type': 'settlement_confirmCollect',
        'amount': 800,
      }),
      '確認現場補款 NT\$ 800',
    );
    expect(
      BookingActionLogDisplay.title(<String, dynamic>{
        'type': 'settlement_confirmRefund',
        'refundAmount': 200,
      }),
      '辦理退款 NT\$ 200',
    );
  });
}
