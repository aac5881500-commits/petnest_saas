import 'package:petnest_saas/core/models/modern_store_home_setting.dart';

/// Merge only fields edited in the frontend draft; preserve newer store content.
ModernStoreHomeSetting mergeStoreHomeDisplayDraft({
  required ModernStoreHomeSetting latest,
  required ModernStoreHomeSetting loaded,
  required ModernStoreHomeSetting draft,
}) {
  final before = loaded.toMap();
  return ModernStoreHomeSetting.fromMap({
    ...latest.toMap(),
    for (final entry in draft.toMap().entries)
      if (entry.value != before[entry.key]) entry.key: entry.value,
  });
}
