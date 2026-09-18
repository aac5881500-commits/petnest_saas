// 檔案名稱：lib/core/widgets/platform_media_library_scope.dart
// 功能說明：集中載入 enabled 平台圖庫，提供卡片／頁背景查詢，避免每卡各打 Firestore。

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/platform_media_asset.dart';
import '../services/platform_media_library_service.dart';

class PlatformMediaLibraryScope extends StatelessWidget {
  const PlatformMediaLibraryScope({
    super.key,
    required this.child,
    this.assetsOverride,
  });

  final Widget child;
  final Map<String, PlatformMediaAsset>? assetsOverride;

  static PlatformMediaAsset? lookup(BuildContext context, String id) {
    final String key = id.trim();
    if (key.isEmpty) {
      return null;
    }
    final _LibraryInherited? inherited = context
        .dependOnInheritedWidgetOfExactType<_LibraryInherited>();
    if (inherited != null) {
      final PlatformMediaAsset? fromScope = inherited.byId[key];
      if (fromScope != null && fromScope.enabled) {
        return fromScope;
      }
    }
    if (!_firebaseReady) {
      return null;
    }
    return PlatformMediaLibraryService.instance.cachedEnabledAsset(key);
  }

  static bool get _firebaseReady {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (assetsOverride != null) {
      return _LibraryInherited(byId: assetsOverride!, child: child);
    }
    if (!_firebaseReady) {
      return _LibraryInherited(
        byId: const <String, PlatformMediaAsset>{},
        child: child,
      );
    }
    Stream<List<PlatformMediaAsset>>? stream;
    try {
      stream = PlatformMediaLibraryService.instance.streamEnabledAssets();
    } catch (_) {
      stream = null;
    }
    if (stream == null) {
      return _LibraryInherited(
        byId: PlatformMediaLibraryService.instance.enabledCache,
        child: child,
      );
    }
    return StreamBuilder<List<PlatformMediaAsset>>(
      stream: stream,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<PlatformMediaAsset>> snapshot,
          ) {
            final Iterable<PlatformMediaAsset> source =
                snapshot.data ??
                PlatformMediaLibraryService.instance.enabledCache.values;
            final Map<String, PlatformMediaAsset> byId =
                <String, PlatformMediaAsset>{
                  for (final PlatformMediaAsset asset in source)
                    asset.id: asset,
                };
            return _LibraryInherited(byId: byId, child: child);
          },
    );
  }
}

class _LibraryInherited extends InheritedWidget {
  const _LibraryInherited({required this.byId, required super.child});

  final Map<String, PlatformMediaAsset> byId;

  @override
  bool updateShouldNotify(covariant _LibraryInherited oldWidget) {
    return !mapEquals(oldWidget.byId, byId);
  }
}
