import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/features/member/widgets/member_lifestyle_tile.dart';

void main() {
  testWidgets(
    'detachable service tiles reflow on narrow and wide displays with large text',
    (t) async {
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      for (final width in [320.0, 390.0, 1024.0]) {
        t.view.physicalSize = Size(width, 1000);
        t.view.devicePixelRatio = 1;
        for (final points in [true, false]) {
          var tapped = false;
          final available = width - 32;
          final columns = available >= 800 ? 4 : 2;
          await t.pumpWidget(
            MaterialApp(
              home: Scaffold(
                body: MediaQuery(
                  data: MediaQueryData(
                    size: Size(width, 1000),
                    textScaler: const TextScaler.linear(1.6),
                  ),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Wrap(
                      spacing: 0,
                      runSpacing: 0,
                      children: [
                        for (final name in ['我的優惠券', '我的點數', '通知設定'])
                          if (!points && name == '我的點數')
                            const SizedBox.shrink()
                          else
                            Padding(
                              padding: const EdgeInsets.fromLTRB(0, 0, 12, 12),
                              child: MemberLifestyleTile(
                                width: available / columns - 12,
                                theme: HomeThemeModel.modernDefault,
                                tint: const Color(0xFFE9DEFF),
                                icon: Icons.stars_outlined,
                                title: name,
                                subtitle: '查看目前店家的權益與紀錄',
                                onTap: () => tapped = true,
                              ),
                            ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
          expect(find.text('我的點數'), points ? findsOneWidget : findsNothing);
          await t.tap(find.text('我的優惠券'));
          expect(tapped, isTrue);
          expect(t.takeException(), isNull);
          final first = t.getRect(find.byType(MemberLifestyleTile).first);
          final second = t.getRect(find.byType(MemberLifestyleTile).at(1));
          expect(first.top, second.top);
          expect(second.right, lessThanOrEqualTo(width - 15));
        }
      }
    },
  );
}
