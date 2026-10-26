import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:petnest_saas/core/models/about_page_setting.dart';
import 'package:petnest_saas/core/models/environment_presentation.dart';

enum ShopIntroContentStatus { empty, configured, unpublished, failed }

/// Derived from acknowledged content, never from visiting an editor or its draft.
class ShopIntroContent {
  // Navigation invalidation only; never a saved/completed content flag.
  static final returned = ValueNotifier<(String, int)?>(null);
  static void notifyReturned(String shopId) =>
      returned.value = (shopId, (returned.value?.$2 ?? 0) + 1);
  static const keys = ['environment', 'about', 'announcement', 'faq'];
  static String _text(Object? value) => value is String ? value.trim() : '';
  static bool _hasText(Object? value) => _text(value).isNotEmpty;
  static bool _photo(Object? value) => _text(value).isNotEmpty;
  static bool environment(Map<String, dynamic> shop) {
    final raw = shop['environmentIntro'];
    if (raw is! Map) return false;
    if ([
      'heroTitle',
      'heroSubtitle',
      'bannerTitle',
      'bottomNote',
    ].any((key) => _hasText(raw[key]))) {
      return true;
    }
    if (_photo(raw['heroImageUrl']) || _photo(raw['bannerImageUrl'])) {
      return true;
    }
    if (aboutShopPhotos(shop).any(_photo)) return true;
    if (raw['facilityKeys'] is List &&
        (raw['facilityKeys'] as List).whereType<String>().any(_hasText)) {
      return true;
    }
    final features = raw['features'];
    if (features is List &&
        features.whereType<Map>().any(
          (f) =>
              _hasText(f['title']) ||
              _hasText(f['description']) ||
              _photo(f['imageUrl']),
        )) {
      return true;
    }
    return EnvironmentPresentation.fromMap(
      raw['environmentPresentation'],
    ).services.any(
      (s) =>
          _hasText(s.data['title']) ||
          _hasText(s.description) ||
          _photo(s.imageUrl),
    );
  }

  static bool about(Map<String, dynamic> shop) {
    if (_hasText(shop['aboutDescription']) || _hasText(shop['aboutMessage'])) {
      return true;
    }
    final setting = AboutPageSetting.fromShop(shop);
    // A cover, layout, contact details or generic section title alone is not an introduction.
    return ['highlights', 'stories', 'principles', 'team', 'credentials'].any(
      (section) => setting
          .items(section)
          .any(
            (item) =>
                item.hasContent &&
                (_hasText(item.text) ||
                    _hasText(item.role) ||
                    _hasText(item.title) ||
                    _photo(item.image.resolveShop(shop))),
          ),
    );
  }

  static ShopIntroContentStatus entries(
    Iterable<Map<String, dynamic>> items, {
    required bool faq,
  }) {
    final valid = items
        .where(
          (item) =>
              _hasText(item[faq ? 'question' : 'title']) &&
              _hasText(item[faq ? 'answer' : 'content']),
        )
        .toList();
    if (valid.any((item) => item['isPublished'] == true)) {
      return ShopIntroContentStatus.configured;
    }
    return valid.isEmpty
        ? ShopIntroContentStatus.empty
        : ShopIntroContentStatus.unpublished;
  }

  static Future<Map<String, ShopIntroContentStatus>> load(String shopId) async {
    final shop = FirebaseFirestore.instance.collection('shops').doc(shopId);
    const options = GetOptions(source: Source.server);
    final result = <String, ShopIntroContentStatus>{};
    // Three bounded reads per entry/return, no listeners recreated by build.
    await Future.wait([
      () async {
        try {
          final snapshot = await shop.get(options);
          if (!snapshot.exists || snapshot.metadata.hasPendingWrites) {
            throw StateError('Shop unavailable');
          }
          final data = snapshot.data()!;
          result['environment'] = environment(data)
              ? ShopIntroContentStatus.configured
              : ShopIntroContentStatus.empty;
          result['about'] = about(data)
              ? ShopIntroContentStatus.configured
              : ShopIntroContentStatus.empty;
        } catch (_) {
          result['environment'] = result['about'] =
              ShopIntroContentStatus.failed;
        }
      }(),
      for (final key in ['announcement', 'faq'])
        () async {
          try {
            final snapshot = await shop
                .collection(key == 'faq' ? 'faqs' : 'announcements')
                .get(options);
            if (snapshot.metadata.hasPendingWrites) {
              throw StateError('Pending write');
            }
            result[key] = entries(
              snapshot.docs.map((doc) => doc.data()),
              faq: key == 'faq',
            );
          } catch (_) {
            result[key] = ShopIntroContentStatus.failed;
          }
        }(),
    ]);
    return result;
  }
}
