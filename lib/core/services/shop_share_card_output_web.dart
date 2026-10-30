import 'dart:convert';
import 'dart:typed_data';
import 'package:universal_html/html.dart' as html;

Future<void> printShopShareCard(Future<Uint8List> Function() capture) async {
  // Open immediately in the user's click event, before asynchronous rendering.
  final popup = html.window.open('about:blank', '_blank');
  try {
    final bytes = await capture();
    final source =
        '''<!doctype html><html lang="zh-Hant"><head>
<meta charset="utf-8"><title>店家分享卡</title><style>
@page{size:A4 portrait;margin:15mm}*{box-sizing:border-box}
body{margin:0;background:white;text-align:center}
img{display:block;width:155mm;max-width:100%;height:auto;margin:0 auto;break-inside:avoid}
button{margin:16px;padding:12px 24px;font-size:16px}
@media print{button{display:none}}</style></head><body>
<button onclick="window.print()">列印／另存 PDF</button>
<img alt="店家 QR Code 與 APP 搜尋碼分享卡" src="data:image/png;base64,${base64Encode(bytes)}">
</body></html>''';
    final url = html.Url.createObjectUrlFromBlob(
      html.Blob([source], 'text/html;charset=utf-8'),
    );
    popup.location.href = url;
    // The print page owns a self-contained data image; keep the URL while open.
  } catch (_) {
    popup.close();
    rethrow;
  }
}

Future<void> downloadShopShareCard(Uint8List bytes) async {
  final url = html.Url.createObjectUrlFromBlob(html.Blob([bytes], 'image/png'));
  html.AnchorElement(href: url)
    ..download = 'petnest_shop_card.png'
    ..click();
  html.Url.revokeObjectUrl(url);
}
