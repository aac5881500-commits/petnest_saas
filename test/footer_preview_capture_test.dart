import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_shop_footer.dart';
void main() {
  testWidgets('capture actual footer component preview', (tester) async {
    await tester.runAsync(() async {
    final font = FontLoader('PreviewChinese');
    font.addFont(Future.value(ByteData.sublistView(await File('C:/Windows/Fonts/msjh.ttc').readAsBytes())));
    await font.load();
    final icons = FontLoader('MaterialIcons');
    icons.addFont(Future.value(ByteData.sublistView(await File('C:/src/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf').readAsBytes())));
    await icons.load();
    final brands = FontLoader('packages/font_awesome_flutter/FontAwesomeBrands');
    brands.addFont(Future.value(ByteData.sublistView(await File('C:/Users/aac58/AppData/Local/Pub/Cache/hosted/pub.dev/font_awesome_flutter-10.12.0/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf').readAsBytes())));
    await brands.load();
    });
    tester.view.physicalSize = const Size(820, 1000); tester.view.devicePixelRatio = 1;
    final key = GlobalKey();
    const footer = ModernShopFooter(shopId: '', shopName: 'PetNest 貓咪旅店',
      shop: {'businessHours': '週一至週日 10:00–19:00（採預約制）', 'phone': '02-1234-5678',
        'city': '台北市', 'district': '大安區', 'address': '示範路 12 號 2 樓',
        'licenseNumber': '示範字號', 'lineUrl': 'https://line.me', 'igUrl': 'https://instagram.com'},
      primaryColor: Color(0xFFFF8A00), darkTextColor: Color(0xFF3C3530), secondaryTextColor: Color(0xFF867C72),
      cardColor: Colors.white, borderColor: Color(0xFFF0E2D4), isPreview: true);
    await tester.pumpWidget(RepaintBoundary(key: key, child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, fontFamily: 'PreviewChinese',
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFFF8A00))),
      home: Scaffold(backgroundColor: const Color(0xFFFFF9F3), body: Padding(
        padding: const EdgeInsets.all(36), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('店家資訊 · 新版預覽', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          const Text('示範資料｜使用實際 Flutter 元件渲染', style: TextStyle(fontSize: 13, color: Color(0xFF867C72))),
          const SizedBox(height: 28),
          const Text('收合時', style: TextStyle(fontSize: 14, color: Color(0xFF867C72))),
          const ModernShopInfoPanel(footer: footer),
          const SizedBox(height: 18),
          const Text('展開時', style: TextStyle(fontSize: 14, color: Color(0xFF867C72))),
          const ModernShopInfoPanel(footer: footer),
        ])),
      ),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.text('店家資訊').last); await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final img = await boundary.toImage(pixelRatio: 1.5);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    await File('C:/Users/aac58/OneDrive/文件/ChatGPT/貓咪旅店專案/review-work/footer-preview.png').writeAsBytes(bytes!.buffer.asUint8List());
    img.dispose();
    });
  });
}




