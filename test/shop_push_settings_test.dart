import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/customer_notification_kind.dart';
import 'package:petnest_saas/core/services/notification_setting_service.dart';
import 'package:petnest_saas/features/notifications/pages/notification_setting_page.dart';

class MemorySettings implements NotificationSettingsStore {
  final changes = StreamController<Map<String, dynamic>>.broadcast();
  Map<String, dynamic> data = {
    'shopOverrides': {
      'A': {'shopMarketing': false, 'shopName': 'A 店'},
    },
  };
  final calls = <String>[];
  bool fail = false;
  @override
  Stream<Map<String, dynamic>> settingsDataStream() async* {
    yield data;
    yield* changes.stream;
  }

  @override
  Future<void> ensureDefaultSettings() async {}
  @override
  Future<void> updateSetting({required String key, required bool value}) async {
    if (fail) throw StateError('offline');
    calls.add(key);
    data = {...data, key: value};
    changes.add(data);
  }

  @override
  Future<void> updateShopSetting({
    required String shopId,
    required String shopName,
    required String key,
    required bool value,
  }) async {
    if (fail) throw StateError('offline');
    calls.add('$shopId/$key');
    final overrides = Map<String, dynamic>.from(data['shopOverrides'] as Map);
    overrides[shopId] = {
      ...?overrides[shopId] as Map?,
      key: value,
      'shopName': shopName,
    };
    data = {...data, 'shopOverrides': overrides};
    changes.add(data);
  }
}

void main() {
  test('shop mutes never affect transactional or unrelated categories', () {
    expect(
      customerPushAllowed(
        mandatory: false,
        category: 'shop_marketing',
        settings: {},
        shopSettings: {'shopMarketing': false},
      ),
      false,
    );
    expect(
      customerPushAllowed(
        mandatory: true,
        category: 'shop_marketing',
        settings: {},
        shopSettings: {'shopMarketing': false},
      ),
      false,
    );
    expect(
      customerPushAllowed(
        mandatory: false,
        category: 'transactional',
        settings: {'enabled': false},
        shopSettings: {'shopNotice': false},
      ),
      true,
    );
    expect(
      customerPushAllowed(
        mandatory: false,
        category: 'shop_notice',
        settings: {'shopNotice': false},
        shopSettings: {'shopNotice': true},
      ),
      false,
    );
  });
  for (final width in [320.0, 900.0]) {
    testWidgets('per-shop preferences isolated and fit $width', (tester) async {
      await tester.binding.setSurfaceSize(Size(width, 1000));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final store = MemorySettings();
      addTearDown(store.changes.close);
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationSettingPage(
            store: store,
            shopId: 'B',
            shopName: 'B 店',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('重要服務通知・固定保留'), findsOneWidget);
      final tile = find.widgetWithText(SwitchListTile, '優惠與活動提醒');
      final control = find
          .descendant(of: tile.last, matching: find.byType(Switch))
          .last;
      await tester.scrollUntilVisible(control, 200);
      await tester.pumpAndSettle();
      await tester.tap(control);
      await tester.pumpAndSettle();
      expect(store.calls, ['B/shopMarketing']);
      final overrides = store.data['shopOverrides'] as Map;
      expect(overrides['A']['shopMarketing'], false);
      expect(overrides['B']['shopMarketing'], false);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'failed write displays retry message and leaves saved state unchanged',
    (tester) async {
      final store = MemorySettings()..fail = true;
      addTearDown(store.changes.close);
      await tester.pumpWidget(
        MaterialApp(
          home: NotificationSettingPage(
            store: store,
            shopId: 'A',
            shopName: 'A 店',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final tile = find.widgetWithText(SwitchListTile, '店家公告');
      await tester.ensureVisible(tile);
      await tester.tap(tile);
      await tester.pumpAndSettle();
      expect(find.textContaining('儲存失敗'), findsOneWidget);
      expect(store.calls, isEmpty);
    },
  );
}
