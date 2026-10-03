// 檔案名稱：test/contact_case_labels_test.dart
// 功能說明：聯絡案件狀態、摘要與訊息左右判斷。

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/support/contact_case_labels.dart';

void main() {
  test('狀態文字保留原代碼並顯示結案', () {
    expect(contactCaseStatusLabel('open'), '待處理');
    expect(contactCaseStatusLabel('processing'), '處理中');
    expect(contactCaseStatusLabel('closed'), '已結案');
    expect(contactCaseStatusLabel('legacy'), 'legacy');
  });

  test('摘要優先用最後訊息，沒有時用原始問題', () {
    expect(
      contactCaseSummary(<String, dynamic>{
        'lastMessage': '已收到',
        'content': '原本的問題',
      }),
      '已收到',
    );
    expect(contactCaseSummary(<String, dynamic>{'content': '原本的問題'}), '原本的問題');
    expect(contactCaseSummary(<String, dynamic>{}), '尚無內容');
  });

  test('店主與平台各自只把自己的訊息放在右側', () {
    expect(
      contactBubbleIsMine(platformViewer: false, senderType: 'shop_owner'),
      isTrue,
    );
    expect(
      contactBubbleIsMine(platformViewer: false, senderType: 'platform'),
      isFalse,
    );
    expect(
      contactBubbleIsMine(platformViewer: true, senderType: 'platform'),
      isTrue,
    );
    expect(
      contactBubbleIsMine(platformViewer: true, senderType: 'member'),
      isFalse,
    );
    expect(contactOpeningSenderType('member'), 'member');
    expect(contactOpeningSenderType('shop_owner'), 'shop_owner');
  });

  test('日期分隔用本地日期', () {
    expect(
      contactDayLabel(DateTime(2026, 10, 2, 23, 50)),
      contactDayLabel(DateTime(2026, 10, 2, 1, 5)),
    );
    expect(
      contactDayLabel(DateTime(2026, 10, 2, 23, 50)) ==
          contactDayLabel(DateTime(2026, 10, 3, 0, 5)),
      isFalse,
    );
  });
}
