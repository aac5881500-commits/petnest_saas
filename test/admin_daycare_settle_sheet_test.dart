// 檔案名稱：test/admin_daycare_settle_sheet_test.dart
// 功能說明：安親結算 UI 不再出現免收本次超時費

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

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
  });
}
