import 'dart:typed_data';

Future<void> printShopShareCard(Future<Uint8List> Function() capture) async {
  throw UnsupportedError('請在電腦網頁版列印，或分享圖片後列印。');
}

Future<void> downloadShopShareCard(Uint8List bytes) async {
  throw UnsupportedError('請使用分享圖片，儲存到手機或傳給 LINE。');
}
