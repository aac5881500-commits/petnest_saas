// 檔案名稱：test/fixed_image_spec_test.dart
// 功能說明：固定比例圖片規格的單元測試（固定版型規格比例與輸出尺寸）

import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/about_cover_frame_setting.dart';
import 'package:petnest_saas/core/models/fixed_image_spec.dart';

void main() {
  test('固定版型規格比例與輸出尺寸', () {
    expect(FixedImageSpec.homeBanner.cropAspectRatio, 16 / 9);
    expect(FixedImageSpec.homeBanner.outputWidth, 1600);
    expect(FixedImageSpec.homeBanner.outputHeight, 900);

    expect(FixedImageSpec.storeBanner.cropAspectRatio, 2 / 1);
    expect(FixedImageSpec.storeBanner.outputWidth, 1600);
    expect(FixedImageSpec.storeBanner.outputHeight, 800);

    expect(FixedImageSpec.roomTypePhoto.cropAspectRatio, 4 / 3);
    expect(FixedImageSpec.roomTypePhoto.outputWidth, 1600);
    expect(FixedImageSpec.roomTypePhoto.outputHeight, 1200);

    expect(FixedImageSpec.storeProduct.cropAspectRatio, 1);
    expect(FixedImageSpec.storeProduct.outputWidth, 1200);
    expect(FixedImageSpec.inventoryItem.outputWidth, 1200);
    expect(FixedImageSpec.pointReward.outputHeight, 1200);

    expect(FixedImageSpec.environmentFeature.cropAspectRatio, 4 / 3);
    expect(FixedImageSpec.environmentFeature.outputWidth, 1200);
    expect(FixedImageSpec.environmentFeature.outputHeight, 900);

    expect(FixedImageSpec.storeEntryBackground.cropAspectRatio, 16 / 9);
    expect(FixedImageSpec.storeEntryBackground.outputWidth, 1600);
    expect(FixedImageSpec.storeEntryBackground.outputHeight, 900);

    expect(FixedImageSpec.memberAvatar.outputWidth, 800);
    expect(FixedImageSpec.memberAvatar.outputHeight, 800);

    expect(FixedImageSpec.environmentHero.cropAspectRatio, 11 / 8);
    expect(FixedImageSpec.environmentHero.outputWidth, 1760);
    expect(FixedImageSpec.environmentHero.outputHeight, 1280);

    expect(FixedImageSpec.environmentBanner.cropAspectRatio, 12 / 5);
    expect(FixedImageSpec.environmentBanner.outputWidth, 1680);
    expect(FixedImageSpec.environmentBanner.outputHeight, 700);

    expect(
      FixedImageSpec.aboutCover.cropAspectRatio,
      AboutCoverFrameSetting.cropAspectRatio,
    );
    expect(
      FixedImageSpec.aboutCover.outputWidth,
      AboutCoverFrameSetting.outputWidth,
    );
    expect(
      FixedImageSpec.aboutCover.outputHeight,
      AboutCoverFrameSetting.outputHeight,
    );
  });

  test('提示文字包含比例、尺寸與可裁切說明', () {
    for (final FixedImageSpec spec in FixedImageSpec.allCropped) {
      expect(spec.hintText, contains('建議比例'));
      expect(spec.hintText, contains('最佳尺寸'));
      expect(spec.hintText, contains('最低建議'));
      expect(spec.hintText, contains('最大檔案'));
      expect(spec.hintText, contains('支援格式'));
      expect(spec.hintText, contains('下一步可以拖曳與縮放裁切'));
    }
  });
}
