// 檔案名稱：lib/core/models/home_banner_display.dart
// 功能說明：首頁活動海報的新舊顯示判斷。完整海報固定 16:9，不跟尺寸改比例。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/modern_banner_frame_setting.dart';
import 'package:petnest_saas/core/models/store_banner_model.dart';

class HomeBannerDisplay {
  HomeBannerDisplay._();

  static const double aspectRatio = 16 / 9;
  static const int maxBytes = 5 * 1024 * 1024;

  static bool isSixteenByNine(int width, int height) {
    if (width <= 0 || height <= 0) {
      return false;
    }
    return (width / height - aspectRatio).abs() <= 0.02;
  }

  /// 首頁輪播一律 16:9。新舊海報混排也不改比例。
  static double frameAspect({
    Iterable<StoreBannerModel> banners = const <StoreBannerModel>[],
    double legacyAspect = aspectRatio,
  }) {
    if (banners.isEmpty && legacyAspect == aspectRatio) {
      return aspectRatio;
    }
    return aspectRatio;
  }

  /// 顯示大小只改外距，不改 16:9。
  static EdgeInsets outerPadding(HomeBannerDisplaySize size) {
    switch (size) {
      case HomeBannerDisplaySize.small:
        return const EdgeInsets.symmetric(horizontal: 16);
      case HomeBannerDisplaySize.large:
        return EdgeInsets.zero;
      case HomeBannerDisplaySize.standard:
        return const EdgeInsets.symmetric(horizontal: 8);
    }
  }

  static String homeContentModeLabel(String mode) {
    if (mode == StoreBannerContentModes.templateOverlay) {
      return '使用海報製作器';
    }
    return '直接上傳完成海報';
  }

  static String homeContentModeHelp(String mode) {
    if (mode == StoreBannerContentModes.templateOverlay) {
      return '使用背景圖片、文字、漸層與按鈕製作海報；發布時會自動輸出成固定 16:9 成品圖。';
    }
    return '上傳已設計完成的 16:9 海報，發布後前台直接使用此成品。';
  }

  /// 直接上傳的完整海報不裁切。製作器只有放大後才需要移動位置。
  static bool showsImagePositionControls({
    required String contentMode,
    required double imageScale,
  }) {
    if (contentMode != StoreBannerContentModes.templateOverlay) {
      return false;
    }
    return imageScale > 1.001;
  }

  static String? validateAction(StoreBannerModel banner) {
    switch (banner.actionType) {
      case HomeBannerActionTypes.url:
        final Uri? uri = Uri.tryParse(banner.actionTargetId.trim());
        final bool ok =
            uri != null &&
            (uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty;
        return ok ? null : '請輸入 http 或 https 開頭的外部網址';
      case HomeBannerActionTypes.product:
        return banner.actionTargetId.trim().isEmpty ? '請選擇商品' : null;
      default:
        return null;
    }
  }
}

class HomeBannerStoredImage {
  const HomeBannerStoredImage({this.url = '', this.path = ''});

  final String url;
  final String path;

  bool get isEmpty => url.trim().isEmpty && path.trim().isEmpty;
}

/// 待清理圖片。未儲存的暫存圖離開時刪；已發布的圖只在儲存成功後刪。
class HomeBannerImageCleanup {
  final List<HomeBannerStoredImage> pending = <HomeBannerStoredImage>[];
  final List<HomeBannerStoredImage> retireAfterSave = <HomeBannerStoredImage>[];

  List<HomeBannerStoredImage> replacePending(HomeBannerStoredImage next) {
    final List<HomeBannerStoredImage> previous = pending
        .where((HomeBannerStoredImage image) => !image.isEmpty)
        .toList();
    pending
      ..clear()
      ..add(next);
    return previous;
  }

  void retireSaved(HomeBannerStoredImage image) {
    if (image.isEmpty) {
      return;
    }
    final bool alreadyPending = pending.any(
      (HomeBannerStoredImage item) =>
          item.path == image.path && item.url == image.url,
    );
    if (alreadyPending) {
      return;
    }
    retireAfterSave.add(image);
  }

  List<HomeBannerStoredImage> commitSave() {
    final List<HomeBannerStoredImage> retired =
        List<HomeBannerStoredImage>.from(retireAfterSave);
    retireAfterSave.clear();
    pending.clear();
    return retired;
  }

  List<HomeBannerStoredImage> abandon() {
    final List<HomeBannerStoredImage> drop = pending
        .where((HomeBannerStoredImage image) => !image.isEmpty)
        .toList();
    pending.clear();
    retireAfterSave.clear();
    return drop;
  }
}
