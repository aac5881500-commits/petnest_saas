import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/appearance_category_bar.dart';

void main() {
  test('區塊捷徑對應外觀分類', () {
    expect(
      AppearanceCategories.forSection('header'),
      AppearanceCategories.brand,
    );
    expect(
      AppearanceCategories.forSection('sharedEntries'),
      AppearanceCategories.cards,
    );
    expect(
      AppearanceCategories.forSection('banners'),
      AppearanceCategories.banners,
    );
    expect(
      AppearanceCategories.forSection('footer'),
      AppearanceCategories.other,
    );
    expect(AppearanceCategories.all.first.shortLabel, '快速風格');
    expect(AppearanceCategories.all[1].shortLabel, '品牌標題');
    expect(
      AppearanceCategories.of(AppearanceCategories.brand).shortLabel,
      '品牌標題',
    );
  });

  testWidgets('右側垂直分類可切換且名稱不被裁切', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(112, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int selected = AppearanceCategories.brand;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return AppearanceCategoryRail(
                selected: selected,
                onSelected: (int value) {
                  setState(() => selected = value);
                },
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('快速風格'), findsOneWidget);
    expect(find.text('品牌標題'), findsOneWidget);
    expect(find.text('背景色彩'), findsOneWidget);
    expect(find.text('其他外觀'), findsOneWidget);
    await tester.tap(
      find.byKey(
        ValueKey<String>('appearance-category-${AppearanceCategories.cards}'),
      ),
    );
    await tester.pump();
    expect(selected, AppearanceCategories.cards);
    expect(tester.takeException(), isNull);
  });

  testWidgets('手機分類選擇器可開關並切換', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    int selected = AppearanceCategories.brand;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              final AppearanceCategoryItem item = AppearanceCategories.of(
                selected,
              );
              return ListView(
                children: <Widget>[
                  ListTile(
                    key: const ValueKey<String>('appearance-category-selector'),
                    title: Text('目前分類：${item.shortLabel}'),
                    onTap: () async {
                      final int? next = await showModalBottomSheet<int>(
                        context: context,
                        showDragHandle: true,
                        builder: (BuildContext sheetContext) {
                          return SafeArea(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                              child: AppearanceCategoryPicker(
                                selected: selected,
                                onSelected: (int value) {
                                  Navigator.of(sheetContext).pop(value);
                                },
                              ),
                            ),
                          );
                        },
                      );
                      if (next == null) {
                        return;
                      }
                      setState(() => selected = next);
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('目前分類：品牌標題'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('appearance-category-selector')),
    );
    await tester.pumpAndSettle();
    expect(find.text('品牌與標題'), findsOneWidget);
    expect(find.text('活動海報'), findsWidgets);
    await tester.tap(
      find.byKey(
        ValueKey<String>('appearance-category-${AppearanceCategories.banners}'),
      ),
    );
    await tester.pumpAndSettle();
    expect(selected, AppearanceCategories.banners);
    expect(find.text('目前分類：活動海報'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
