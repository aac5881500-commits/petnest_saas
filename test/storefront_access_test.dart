import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/storefront_access.dart';
import 'package:petnest_saas/core/services/store_home_draft_merge.dart';
import 'package:petnest_saas/core/models/modern_store_home_setting.dart';

void main() {
  final now = DateTime.parse('2026-10-26T15:59:59Z');
  final cases =
      jsonDecode(
            File('test/fixtures/store_access_cases.json').readAsStringSync(),
          )
          as List;
  for (final row in cases) {
    test(row['name'] as String, () {
      final shop = Map<String, dynamic>.from(row['shop'] as Map);
      final settings = Map<String, dynamic>.from(row['settings'] as Map);
      expect(StorefrontAccess.hasEntitlement(shop, now: now), row['entitled']);
      expect(
        StorefrontAccess.canAcceptOrders(
          shop: shop,
          settings: settings,
          now: now,
        ),
        row['accept'],
      );
    });
  }
  test('台北午夜後停止新單，舊 Timestamp 精確到期', () {
    expect(
      StorefrontAccess.hasEntitlement({
        'plan': 'basic',
        'paidUntilDate': '2026-10-26',
      }, now: DateTime.parse('2026-10-26T16:00:00Z')),
      isFalse,
    );
    final shop = {
      'plan': 'basic',
      'paidUntil': Timestamp.fromDate(now.add(const Duration(seconds: 1))),
    };
    expect(StorefrontAccess.hasEntitlement(shop, now: now), isTrue);
    expect(
      StorefrontAccess.hasEntitlement(
        shop,
        now: now.add(const Duration(seconds: 1)),
      ),
      isFalse,
    );
  });
  test('暫停接單仍可瀏覽，準備中不公開瀏覽', () {
    final shop = {'plan': 'basic', 'paidUntilDate': '2027-01-01'};
    expect(
      StorefrontAccess.isStorefrontOpen(
        shop: shop,
        settings: {'businessStatus': 'paused'},
        now: now,
      ),
      isTrue,
    );
    expect(
      StorefrontAccess.isStorefrontOpen(
        shop: shop,
        settings: {'businessStatus': 'preparing'},
        now: now,
      ),
      isFalse,
    );
  });
  test('首頁開關變更保留其他頁面最新圖片、文案與精選開關', () {
    const loaded = ModernStoreHomeSetting();
    final latest = loaded.copyWith(
      storeBannerTitle: '新文案',
      storeBannerImageUrl: 'https://example.com/new.png',
      showFeaturedProducts: false,
    );
    final next = mergeStoreHomeDisplayDraft(
      latest: latest,
      loaded: loaded,
      draft: loaded.copyWith(showStoreBanner: false),
    );
    expect(next.showStoreBanner, isFalse);
    expect(next.storeBannerTitle, '新文案');
    expect(next.storeBannerImageUrl, latest.storeBannerImageUrl);
    expect(next.showFeaturedProducts, isFalse);
  });
  test('未動首頁入口開關時保留其他頁面新設定', () {
    const loaded = ModernStoreHomeSetting();
    final next = mergeStoreHomeDisplayDraft(
      latest: loaded.copyWith(showStoreBanner: false),
      loaded: loaded,
      draft: loaded,
    );
    expect(next.showStoreBanner, isFalse);
  });
}
