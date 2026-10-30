import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/platform/widgets/compact_shop_card.dart';
import 'package:petnest_saas/features/platform/widgets/explore_discovery_header.dart';

void main() {
  for (final width in <double>[320, 390, 500]) {
    for (final scale in <double>[1, 2]) {
      testWidgets('mobile discovery card $width / $scale fits and separates favorite from opening', (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.runAsync(() async {
          await (FontLoader('jfOpenHuninn')..addFont(rootBundle.load('assets/fonts/jf-openhuninn-2.1.ttf'))).load();
          await (FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
        });
        final search = TextEditingController();
        addTearDown(search.dispose);
        int opens = 0, favorites = 0;
        await tester.pumpWidget(MaterialApp(theme: ThemeData(fontFamily: 'jfOpenHuninn', colorSchemeSeed: const Color(0xFF4D5B98)),
          builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)), child: child!),
          home: RepaintBoundary(key: const ValueKey('capture'), child: Scaffold(backgroundColor: const Color(0xFFF6F7FC),
            body: SafeArea(child: ListView(padding: const EdgeInsets.all(16), children: <Widget>[
              ExploreDiscoveryHeader(search: search, categories: const ['全部', '貓旅館', '狗旅館', '美容'], category: '全部', openOnly: false,
                onSearch: () {}, onCategory: (_) {}, onOpenOnly: (_) {}, onReset: () {}, onMap: () {}, onMember: () {}, onBack: () {}),
              const SizedBox(height: 20),
              const ExploreResultsHeading(count: 1, total: 1, filtered: false),
              const SizedBox(height: 12),
              CompactShopCard(mobile: true, name: '測試店家', meta: const Text('尚無評價 · 新竹縣新埔鎮', maxLines: 2),
                services: '貓旅館 · 狗旅館 · 美容 +2', imageUrl: '', logoUrl: '', isOpen: true,
                onTap: () => opens++, onFavorite: () => favorites++),
            ])),
          )),
        ));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(find.byTooltip('收藏店家'));
        await tester.tap(find.byTooltip('收藏店家'));
        expect(favorites, 1);
        expect(opens, 0);
        await tester.tap(find.text('測試店家'));
        expect(opens, 1);
        expect(tester.takeException(), isNull);
        if (width == 390 && scale == 1) {
          final output = const String.fromEnvironment('MOBILE_DISCOVERY_CAPTURE');
          if (output.isNotEmpty) {
            final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('capture')));
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 1);
              final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
              await File(output).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
        }
      });
    }
  }
}
