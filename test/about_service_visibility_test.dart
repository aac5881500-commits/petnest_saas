// 功能：快速範本與服務顯示開關保持單一狀態，不可被舊visibility擋住。
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/about_page_setting.dart';
import 'package:petnest_saas/core/models/about_page_template.dart';

void main() {
  test('舊範本visibility false不可擋住已開啟的服務', () {
    final value = AboutPageSetting.fromMap({
      'visibility': {'services': false},
      'moduleShowcase': {
        'layout': 'cards',
        'selected': ['cat_hotel'],
        'cardSize': 'small',
      },
    });
    expect(value.visible('services'), isTrue);
    final applied = AboutPageTemplate.complete(value);
    expect(applied.visible('services'), isTrue);
    expect(applied.serviceShowcase.selected, ['cat_hotel']);
    expect(applied.serviceShowcase.cardSize, 'small');
    expect(
      AboutPageSetting.fromMap(applied.toMap()).visible('services'),
      isTrue,
    );
  });
  test('兩處服務開關同源，關閉再開不遺失選項', () {
    final value = AboutPageSetting.fromMap({
      'moduleShowcase': {
        'layout': 'cards',
        'selected': ['cat_hotel'],
      },
    });
    final off = value.setVisible('services', false);
    expect(off.serviceShowcase.layout, 'hidden');
    expect(off.visible('services'), isFalse);
    final on = off.setVisible('services', true);
    expect(on.visible('services'), isTrue);
    expect(on.serviceShowcase.layout, 'cards');
    expect(on.serviceShowcase.selected, ['cat_hotel']);
  });
}
