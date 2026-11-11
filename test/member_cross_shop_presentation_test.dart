import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/member/widgets/member_order_overview.dart';
import 'package:petnest_saas/features/member/widgets/member_order_room_image.dart';
import 'package:petnest_saas/features/member/widgets/member_shop_scope_label.dart';
import 'package:petnest_saas/features/member/widgets/member_lifestyle_tile.dart';

void main() {
  test('room photo only uses a valid booking snapshot', () {
    expect(
      memberOrderRoomImageUrl({
        'roomImages': [
          null,
          '',
          'https://example.com/a.jpg',
          'https://example.com/b.jpg',
        ],
      }),
      'https://example.com/a.jpg',
    );
    expect(
      memberOrderRoomImageUrl({
        'roomImages': 'broken',
        'roomImageUrl': 'https://example.com/fallback.jpg',
      }),
      'https://example.com/fallback.jpg',
    );
    expect(
      memberOrderRoomImageUrl({
        'roomImages': [
          'javascript:bad',
          {'url': 'bad'},
        ],
      }),
      '',
    );
    expect(memberOrderRoomImageUrl({}), '');
  });
  testWidgets(
    'recent cross-shop order attributes its shop and handles missing photo on small screens',
    (t) async {
      t.view.physicalSize = const Size(320, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      for (final shop in ['甲旅店', '乙旅店']) {
        await t.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: MemberOrderOverview(
                  theme: HomeThemeModel.modernDefault,
                  view: MemberOrderPreview(
                    id: shop,
                    data: {
                      'shopName': shop,
                      'roomTypeName': '陽光套房',
                      'status': 'pending',
                      'bookingCode': 'PN-123',
                    },
                  ).view,
                  onOpenOrders: () {},
                  onOpenLatest: () {},
                ),
              ),
            ),
          ),
        );
        expect(find.text(shop), findsOneWidget);
        expect(find.byType(MemberOrderRoomImage), findsOneWidget);
        expect(find.byIcon(Icons.bed_outlined), findsOneWidget);
        expect(t.takeException(), isNull);
      }
      expect(find.text('甲旅店'), findsNothing);
    },
  );
  testWidgets(
    'store-specific benefits show shop attribution in a narrow large-text tile',
    (t) async {
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MemberLifestyleTile(
                width: 144,
                theme: HomeThemeModel.modernDefault,
                tint: Colors.purple.shade50,
                icon: Icons.stars_outlined,
                title: '我的點數',
                subtitle: '查看點數紀錄',
                attribution: const MemberShopScopeLabel(
                  shopId: 'shop-a',
                  shopName: '甲旅店',
                  note: '點數僅限此店使用',
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.textContaining('所屬店家：甲旅店'), findsOneWidget);
      expect(find.textContaining('點數僅限此店使用'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
}
