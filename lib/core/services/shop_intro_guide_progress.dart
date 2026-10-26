import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// One-time local guide decisions. Content/publication status stays separate.
class ShopIntroGuideProgress {
  const ShopIntroGuideProgress({
    this.completed = const {},
    this.skipped = const {},
    this.dismissed = false,
  });
  final Set<String> completed, skipped;
  final bool dismissed;
  static const items = {'environment', 'about', 'announcement', 'faq'};
  bool handled(String item) =>
      dismissed || completed.contains(item) || skipped.contains(item);
  bool get ended => dismissed || items.every(handled);
  static String key(String shopId) => 'openingIntro:v2:$shopId';
  static ShopIntroGuideProgress _read(SharedPreferences prefs, String shopId) {
    final raw = prefs.getString(key(shopId));
    if (raw == null) return const ShopIntroGuideProgress();
    final map = jsonDecode(raw) as Map<String, dynamic>;
    return ShopIntroGuideProgress(
      completed: (map['completed'] as List? ?? [])
          .whereType<String>()
          .where(items.contains)
          .toSet(),
      skipped: (map['skipped'] as List? ?? [])
          .whereType<String>()
          .where(items.contains)
          .toSet(),
      dismissed: map['dismissed'] == true,
    );
  }

  static Future<ShopIntroGuideProgress> load(
    String shopId,
    String userId,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getString(key(shopId)) == null &&
        prefs.getBool('openingOptional:$userId:$shopId') == true) {
      return save(shopId, dismissed: true);
    }
    return _read(prefs, shopId);
  }

  // Serialize local writes and merge decisions; no older callback can erase a
  // completed item, even if two retained dashboard instances share this shop.
  static Future<void>? _writes;
  static Future<ShopIntroGuideProgress> save(
    String shopId, {
    Set<String> completed = const {},
    Set<String> skipped = const {},
    bool dismissed = false,
  }) {
    Future<ShopIntroGuideProgress> write() async {
      final prefs = await SharedPreferences.getInstance();
      final previous = _read(prefs, shopId);
      final next = ShopIntroGuideProgress(
        completed: {...previous.completed, ...completed.where(items.contains)},
        skipped: {
          ...previous.skipped,
          ...skipped.where((id) => id == 'announcement' || id == 'faq'),
        },
        dismissed: previous.dismissed || dismissed,
      );
      final ok = await prefs.setString(
        key(shopId),
        jsonEncode({
          'completed': next.completed.toList(),
          'skipped': next.skipped.toList(),
          'dismissed': next.dismissed,
        }),
      );
      if (!ok) throw StateError('無法保存引導狀態');
      return next;
    }

    final previousWrite = _writes;
    final operation = previousWrite == null
        ? write()
        : previousWrite.then((_) => write());
    late final Future<void> pending;
    void release() {
      if (identical(_writes, pending)) _writes = null;
    }

    pending = operation.then<void>(
      (_) => release(),
      onError: (Object _) => release(),
    );
    _writes = pending;
    return operation;
  }
}
