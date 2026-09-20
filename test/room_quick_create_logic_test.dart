// 檔案名稱：test/room_quick_create_logic_test.dart
// 功能說明：快速建房連續編號、分隔解析與重複略過。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_quick_create_logic.dart';

void main() {
  test('連續房號可依位數預覽', () {
    expect(
      RoomQuickCreateLogic.sequentialNames(
        prefix: 'A',
        start: 1,
        count: 5,
        digitCount: 2,
      ),
      <String>['A01', 'A02', 'A03', 'A04', 'A05'],
    );
  });

  test('自行輸入可用換行、逗號與空格分隔並去掉空白', () {
    expect(
      RoomQuickCreateLogic.parseCustomNames(' A01\nA02, VIP01  A02  '),
      <String>['A01', 'A02', 'VIP01', 'A02'],
    );
  });

  test('已存在與同批重複會略過，超過上限會標記', () {
    final RoomQuickCreatePlan plan = RoomQuickCreateLogic.plan(
      names: <String>['A01', ' A02 ', 'A01', 'A03', ''],
      existingNames: <String>{'A02'},
      remaining: 1,
    );
    expect(plan.toCreate, <String>['A01', 'A03']);
    expect(plan.skippedExisting, <String>['A02']);
    expect(plan.skippedInBatch, <String>['A01']);
    expect(plan.exceedsRemaining, isTrue);
  });
}
