// 檔案名稱：lib/core/models/fixed_image_spec.dart
// 功能說明：固定版型圖片：比例、輸出尺寸與上傳提示集中定義。

class FixedImageSpec {
  const FixedImageSpec({
    required this.id,
    required this.label,
    required this.aspectWidth,
    required this.aspectHeight,
    required this.outputWidth,
    required this.outputHeight,
    required this.recommendedWidth,
    required this.recommendedHeight,
    required this.minWidth,
    required this.minHeight,
    this.maxFileBytes = 5 * 1024 * 1024,
    this.supportedFormats = defaultFormats,
    this.shouldCrop = true,
  });

  final String id;
  final String label;
  final int aspectWidth;
  final int aspectHeight;
  final int outputWidth;
  final int outputHeight;
  final int recommendedWidth;
  final int recommendedHeight;
  final int minWidth;
  final int minHeight;
  final int maxFileBytes;
  final List<String> supportedFormats;
  final bool shouldCrop;

  static const List<String> defaultFormats = <String>[
    'JPG',
    'JPEG',
    'PNG',
    'WEBP',
  ];

  double get cropAspectRatio => aspectWidth / aspectHeight;

  String get aspectLabel => '$aspectWidth:$aspectHeight';

  String get recommendedSizeLabel =>
      '$recommendedWidth × $recommendedHeight px';

  String get minSizeLabel => '$minWidth × $minHeight px';

  String get outputSizeLabel => '$outputWidth × $outputHeight px';

  String get maxFileSizeLabel {
    final int mb = (maxFileBytes / (1024 * 1024)).round();
    return '$mb MB';
  }

  String get formatsLabel => supportedFormats.join('、');

  String get hintText {
    return '建議比例 $aspectLabel\n'
        '最佳尺寸 $recommendedSizeLabel\n'
        '最低建議 $minSizeLabel\n'
        '最大檔案 $maxFileSizeLabel\n'
        '支援格式 $formatsLabel\n'
        '其他尺寸也能上傳，下一步可以拖曳與縮放裁切';
  }

  String get cropUsageText {
    return '框內區域就是「$label」前台主要顯示範圍。可拖曳、縮放圖片來選擇實際要顯示的內容。';
  }

  static const FixedImageSpec homeBanner = FixedImageSpec(
    id: 'homeBanner',
    label: '首頁活動海報',
    aspectWidth: 16,
    aspectHeight: 9,
    outputWidth: 1600,
    outputHeight: 900,
    recommendedWidth: 1600,
    recommendedHeight: 900,
    minWidth: 1280,
    minHeight: 720,
  );

  static const FixedImageSpec storeBanner = FixedImageSpec(
    id: 'storeBanner',
    label: '商城活動海報',
    aspectWidth: 2,
    aspectHeight: 1,
    outputWidth: 1600,
    outputHeight: 800,
    recommendedWidth: 1600,
    recommendedHeight: 800,
    minWidth: 1200,
    minHeight: 600,
  );

  static const FixedImageSpec roomTypePhoto = FixedImageSpec(
    id: 'roomTypePhoto',
    label: '房型照片',
    aspectWidth: 4,
    aspectHeight: 3,
    outputWidth: 1600,
    outputHeight: 1200,
    recommendedWidth: 1600,
    recommendedHeight: 1200,
    minWidth: 1200,
    minHeight: 900,
  );

  static const FixedImageSpec storeProduct = FixedImageSpec(
    id: 'storeProduct',
    label: '商城商品圖片',
    aspectWidth: 1,
    aspectHeight: 1,
    outputWidth: 1200,
    outputHeight: 1200,
    recommendedWidth: 1200,
    recommendedHeight: 1200,
    minWidth: 800,
    minHeight: 800,
  );

  static const FixedImageSpec inventoryItem = FixedImageSpec(
    id: 'inventoryItem',
    label: '庫存品項圖片',
    aspectWidth: 1,
    aspectHeight: 1,
    outputWidth: 1200,
    outputHeight: 1200,
    recommendedWidth: 1200,
    recommendedHeight: 1200,
    minWidth: 800,
    minHeight: 800,
  );

  static const FixedImageSpec pointReward = FixedImageSpec(
    id: 'pointReward',
    label: '點數兌換商品圖片',
    aspectWidth: 1,
    aspectHeight: 1,
    outputWidth: 1200,
    outputHeight: 1200,
    recommendedWidth: 1200,
    recommendedHeight: 1200,
    minWidth: 800,
    minHeight: 800,
  );

  static const FixedImageSpec environmentFeature = FixedImageSpec(
    id: 'environmentFeature',
    label: '環境特色圖片',
    aspectWidth: 4,
    aspectHeight: 3,
    outputWidth: 1200,
    outputHeight: 900,
    recommendedWidth: 1200,
    recommendedHeight: 900,
    minWidth: 800,
    minHeight: 600,
  );

  static const FixedImageSpec storeEntryBackground = FixedImageSpec(
    id: 'storeEntryBackground',
    label: '首頁商城入口背景',
    aspectWidth: 16,
    aspectHeight: 9,
    outputWidth: 1600,
    outputHeight: 900,
    recommendedWidth: 1600,
    recommendedHeight: 900,
    minWidth: 1200,
    minHeight: 675,
  );

  static const FixedImageSpec memberAvatar = FixedImageSpec(
    id: 'memberAvatar',
    label: '寵物與會員頭像',
    aspectWidth: 1,
    aspectHeight: 1,
    outputWidth: 800,
    outputHeight: 800,
    recommendedWidth: 800,
    recommendedHeight: 800,
    minWidth: 500,
    minHeight: 500,
  );

  static const FixedImageSpec environmentHero = FixedImageSpec(
    id: 'environmentHero',
    label: '環境介紹首頁大圖',
    aspectWidth: 11,
    aspectHeight: 8,
    outputWidth: 1760,
    outputHeight: 1280,
    recommendedWidth: 1760,
    recommendedHeight: 1280,
    minWidth: 1100,
    minHeight: 800,
  );

  static const FixedImageSpec environmentBanner = FixedImageSpec(
    id: 'environmentBanner',
    label: '環境介紹中間橫幅',
    aspectWidth: 12,
    aspectHeight: 5,
    outputWidth: 1680,
    outputHeight: 700,
    recommendedWidth: 1680,
    recommendedHeight: 700,
    minWidth: 1200,
    minHeight: 500,
  );

  /// 與 [AboutCoverFrameSetting] 相同：接近正方形輸出。
  static const FixedImageSpec aboutCover = FixedImageSpec(
    id: 'aboutCover',
    label: '關於我們封面',
    aspectWidth: 1,
    aspectHeight: 1,
    outputWidth: 1600,
    outputHeight: 1600,
    recommendedWidth: 1600,
    recommendedHeight: 1600,
    minWidth: 800,
    minHeight: 800,
  );

  static const List<FixedImageSpec> allCropped = <FixedImageSpec>[
    homeBanner,
    storeBanner,
    roomTypePhoto,
    storeProduct,
    inventoryItem,
    pointReward,
    environmentFeature,
    storeEntryBackground,
    memberAvatar,
    environmentHero,
    environmentBanner,
    aboutCover,
  ];
}
