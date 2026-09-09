// 檔案名稱：test/operator_display_test.dart
// 功能說明：操作人顯示 email，找不到時不回退 UID

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/operator_display.dart';

void main() {
  test('有 email 就顯示 email', () {
    expect(
      OperatorDisplay.fromLog(<String, dynamic>{
        'operatorEmail': 'staff@shop.com',
        'operatorUid': 'abcdefghijklmnopqrstuv',
      }),
      'staff@shop.com',
    );
  });

  test('沒有 email 且沒有 UID 顯示系統操作', () {
    expect(OperatorDisplay.fromLog(<String, dynamic>{}), '系統操作');
  });

  test('有 UID 但對不到店員顯示已移除店員', () {
    expect(
      OperatorDisplay.fromLog(<String, dynamic>{
        'operatorUid': 'abcdefghijklmnopqrstuv',
      }),
      '已移除店員',
    );
  });
}
