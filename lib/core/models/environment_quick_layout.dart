import 'environment_presentation.dart';
import 'environment_layout_settings.dart';

/// A recipe for the same public controls available in the editor, not a renderer.
class EnvironmentQuickLayout {
  static const layout = <String, dynamic>{
    'heroLayout': 'split',
    'featureLayout': 'photoSide',
    'bannerLayout': 'split',
    'equipmentLayout': 'mediaRow',
    'footerTogether': true,
    'showFeatureHeading': false,
    'showGalleryHeading': false,
    'showEquipmentHeading': false,
    'showFeatureIcon': false,
    'showDivider': true,
    'photoFraction': .4,
    'photoHeight': 122.0,
    'cardRadius': 9.0,
    'spacing': 14.0,
    'titleSize': 15.0,
    'galleryAspect': 2.0,
    'noteFontSize': 11.0,
    'heroBackdrop': 'builtin-env:cover-backdrop',
    'heroEyebrow': '像在家一樣安心',
    'heroLineBreak': 'punctuation',
    'heroFill': 0xff58452e,
    'heroTextColor': 0xffffffff,
    'bannerFill': 0xff718064,
    'bannerTextColor': 0xffffffff,
    'bannerFontFamily': 'KleeOne',
    'featureFill': 0xfff8f2e7,
    'equipmentFill': 0xffeff0e5,
    'noteTitle': '小提醒',
    'bannerSubtitle': '在這裡，可以更溫柔，讓貓咪用自己的步調，享受每一刻的安心。',
  };
  static const appearance = <String, dynamic>{
    'fontFamily': 'NotoSerifTC',
    'backgroundMode': 'solid',
    'backgroundColor': 0xfffdfaf3,
    'textColor': 0xff40382f,
    'secondaryTextColor': 0xff6b655d,
    'accentColor': 0xff718064,
    'cardColor': 0xfff8f2e7,
  };
  static EnvironmentPresentation presentation(
    EnvironmentPresentation current,
  ) => current.copyWith({
    'preset': 'warm',
    'customized': false,
    'layoutSettings': {...current.layout.toMap(), ...layout},
    'appearance': {...current.appearance.toMap(), ...appearance},
    'sectionOrder': ['hero', 'features', 'care', 'banner', 'gallery', 'note'],
    'hiddenSections': <String>[],
    'sectionGaps': {
      'hero': 0.0,
      'features': 20.0,
      'care': 14.0,
      'banner': 14.0,
      'gallery': 14.0,
      'note': 14.0,
    },
    'desktopColumns': 'auto',
    'desktopCardLayout': 'inherit',
    'contentMaxWidth': 1200.0,
  });
  static Map<String, dynamic> sampleIntro() => {
    'heroTitle': '讓貓咪，自在住一晚。',
    'heroSubtitle': '明亮、舒適、專屬的貓咪旅宿空間，\n讓每一次停留，都是溫柔的日常。',
    'bannerTitle': '慢一點，也很好。',
    'heroImageUrl': EnvironmentBuiltinPhotos.url('warm-hero'),
    'bannerImageUrl': EnvironmentBuiltinPhotos.url('warm-hero'),
    'heroImageStoragePath': '',
    'bannerImageStoragePath': '',
    'environmentFeatureCardLayout': 'horizontal',
    'features': [
      {
        'icon': 'home',
        'title': '窗邊貓窩',
        'subtitle': '享受日光的溫柔角落',
        'description': '精心設計的舒適貓窩，\n讓貓咪可以曬曬陽光、\n靜靜觀察窗外的世界。',
        'layout': 'imageLeft',
        'imageUrl': EnvironmentBuiltinPhotos.url('warm-room'),
        'imageStoragePath': '',
      },
      {
        'icon': 'pets',
        'title': '垂直貓跳台',
        'subtitle': '滿足天性的探索樂趣',
        'description': '豐富又貼心的設計，\n讓貓咪自在攀爬、探索，\n活動身心、保持愉快心情。',
        'layout': 'imageLeft',
        'imageUrl': EnvironmentBuiltinPhotos.url('warm-climb'),
        'imageStoragePath': '',
      },
    ],
    'facilityKeys': <String>[],
    'galleryImages': [
      {
        'imageUrl': EnvironmentBuiltinPhotos.url('warm-about'),
        'imageStoragePath': '',
      },
      {
        'imageUrl': EnvironmentBuiltinPhotos.url('warm-room'),
        'imageStoragePath': '',
      },
    ],
    'bottomNote':
        '• 為維護所有貓咪的舒適與安全，進房前皆會進行清潔與消毒。\n• 每間貓房皆為獨立空間，並設有新鮮飲水與舒適休憩區。\n• 我們會依貓咪個性，安排合適的環境與照顧方式。\n• 如有特殊飲食或照護需求，歡迎提前告知我們。\nAI 示意照片，非實景；測試店請勿預約。',
  };
  static List<Map<String, dynamic>> sampleServices() => [
    {
      'id': 'sample-water',
      'title': '獨立飲水',
      'description': '全天提供新鮮溫潤飲水，\n讓貓咪隨時補充水分。',
      'icon': 'water',
      'category': 'environment',
      'visible': true,
      'imageUrl': EnvironmentBuiltinPhotos.url('water'),
    },
    {
      'id': 'sample-sun',
      'title': '自然日照',
      'description': '大面採光設計，\n享受溫暖的自然光線。',
      'icon': 'sun',
      'category': 'environment',
      'visible': true,
      'imageUrl': EnvironmentBuiltinPhotos.url('sun'),
    },
    {
      'id': 'sample-jump',
      'title': '探索跳台',
      'description': '多層跳台與趣味空間，\n滿足好奇心與活動需求。',
      'icon': 'climb',
      'category': 'environment',
      'visible': true,
      'imageUrl': EnvironmentBuiltinPhotos.url('jump'),
    },
  ];
}
