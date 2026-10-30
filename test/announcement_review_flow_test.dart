import 'package:petnest_saas/core/theme/petnest_app_theme.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/pages/campaigns/shop_campaign_center_page.dart';
import 'package:petnest_saas/features/shop/widgets/content/announcement_management_card.dart';

Map<String, dynamic> job(String status) => {
  'id': 'existing-job',
  'announcementId': 'a',
  'status': status,
  'version': 4,
  'title': '營業時間調整公告',
  'body': '週日照常營業，歡迎提前預約接送。',
  'category': 'shop_notice',
  'channel': 'inbox',
  'audience': 'all',
  'memberIds': [],
  'recipientCount': 2,
  'counts': {'inbox': 2},
};
Map<String, dynamic> overview(Map<String, dynamic> item) => {
  'permissions': {'draft': true, 'send': true},
  'campaigns': [item],
};
Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  final output = Platform.environment['PETNEST_NOTICE_PREVIEW'];
  if (output == null) return;
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    await Directory(output).create(recursive: true);
    await File('$output/$name.png').writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'linked draft reuses id and settings without duplicate form at $width',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 950));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.runAsync(() async {
          await (FontLoader('MaterialIcons')
                ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf')))
              .load();
          await (FontLoader('NotoSansTC')..addFont(
                rootBundle.load(
                  'assets/fonts/NotoSansTC-VariableFont_wght.ttf',
                ),
              ))
              .load();
        });
        var sends = 0;
        final key = GlobalKey();
        await tester.pumpWidget(
          RepaintBoundary(
            key: key,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: PetNestAppTheme.build().copyWith(
                textTheme: PetNestAppTheme.build().textTheme.apply(
                  fontFamily: 'NotoSansTC',
                ),
              ),
              home: ShopCampaignCenterPage(
                shopId: 's',
                announcementId: 'a',
                api: (action, data) async {
                  if (action == 'bootstrap') return overview(job('draft'));
                  if (action == 'preview') {
                    expect(data['campaignId'], 'existing-job');
                    expect(data['version'], 4);
                    expect((data['draft'] as Map)['channel'], 'push');
                    expect((data['draft'] as Map)['audience'], 'all');
                    return {
                      'campaign': {'version': 5},
                      'preview': {'count': 2, 'excluded': 0, 'revision': 'r'},
                    };
                  }
                  if (action == 'send') {
                    sends++;
                    return {};
                  }
                  throw StateError('unexpected $action');
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('確認公告通知'), findsOneWidget);
        expect(find.byType(TextFormField), findsNothing);
        expect(find.byType(DropdownButtonFormField<String>), findsNothing);
        await capture(tester, key, 'announcement_review_${width.toInt()}');
        await tester.tap(find.text('預覽並發送'));
        await tester.pumpAndSettle();
        expect(sends, 0);
        await tester.tap(find.text('確認發送給 2 位'));
        await tester.pumpAndSettle();
        expect(sends, 1);
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('repeat makes a fresh job only after explicit confirmation', (
    tester,
  ) async {
    String? created;
    var sends = 0;
    var repeatVersion = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ShopCampaignCenterPage(
          shopId: 's',
          api: (action, data) async {
            if (action == 'bootstrap') return overview(job('completed'));
            if (action == 'preview') {
              created = '${data['campaignId']}';
              expect(created, isNot('existing-job'));
              expect(data['version'], repeatVersion++);
              return {
                'campaign': {'version': repeatVersion},
                'preview': {'count': 2, 'excluded': 0, 'revision': 'r'},
              };
            }
            if (action == 'send') {
              sends++;
              expect(data['campaignId'], created);
              return {};
            }
            throw StateError(action);
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('再次通知'));
    await tester.pumpAndSettle();
    expect(find.textContaining('可能再次收到'), findsOneWidget);
    expect(sends, 0);
    await tester.tap(find.text('預覽並發送'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('返回調整'));
    await tester.pumpAndSettle();
    expect(sends, 0);
    await tester.tap(find.text('預覽並發送'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('確認發送給 2 位'));
    await tester.pumpAndSettle();
    expect(sends, 1);
  });
  testWidgets('announcement card keeps actions inside 320px screen', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 950));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.runAsync(() async {
      await (FontLoader(
        'MaterialIcons',
      )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
      await (FontLoader('NotoSansTC')..addFont(
            rootBundle.load('assets/fonts/NotoSansTC-VariableFont_wght.ttf'),
          ))
          .load();
    });
    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: PetNestAppTheme.build().copyWith(
            textTheme: PetNestAppTheme.build().textTheme.apply(
              fontFamily: 'NotoSansTC',
            ),
          ),
          home: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                AnnouncementManagementCard(
                  title: '營業時間調整公告',
                  body: '週日照常營業，歡迎提前預約接送。',
                  typeLabel: '營業異動',
                  published: true,
                  pinned: false,
                  disabled: false,
                  onPublish: (_) {},
                  onPin: () {},
                  onEdit: () {},
                  onDelete: () {},
                  notificationActions: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('通知待發送・設定已保留'),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.send_outlined),
                        label: const Text('繼續發送通知'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await capture(tester, key, 'announcement_card_320');
    await tester.tap(find.byTooltip('公告更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('編輯內容'), findsOneWidget);
    expect(find.text('刪除公告'), findsOneWidget);
  });
}
