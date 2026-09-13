// 檔案名稱：test/admin_payment_trade_no_label_test.dart
// 功能說明：店主交易編號文案，客戶端不顯示技術單號

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('店主完整交易紀錄改為 PetNest 付款單號', () {
    final String detail = File(
      'lib/features/admin/pages/admin_payment_detail_page.dart',
    ).readAsStringSync();
    final String center = File(
      'lib/features/admin/pages/admin_payment_center_page.dart',
    ).readAsStringSync();
    expect(detail.contains('PetNest 付款單號'), isTrue);
    expect(center.contains('PetNest 付款單號'), isTrue);
    expect(detail.contains('綠界交易編號'), isTrue);
    expect(center.contains('綠界交易編號'), isTrue);
    expect(detail.contains('尚未取得'), isTrue);
    expect(detail.contains("'商店交易編號'"), isFalse);
    expect(center.contains('商店交易編號'), isFalse);
  });

  test('客戶端不顯示 MerchantTradeNo／TradeNo／CheckMacValue', () {
    final List<File> files = Directory('lib/features/booking')
        .listSync(recursive: true)
        .whereType<File>()
        .where((File f) => f.path.endsWith('.dart'))
        .toList();
    for (final File file in files) {
      final String source = file.readAsStringSync();
      expect(source.contains('MerchantTradeNo'), isFalse, reason: file.path);
      expect(source.contains('CheckMacValue'), isFalse, reason: file.path);
      expect(source.contains('商店交易編號'), isFalse, reason: file.path);
      expect(source.contains('綠界交易編號'), isFalse, reason: file.path);
    }
  });
}
