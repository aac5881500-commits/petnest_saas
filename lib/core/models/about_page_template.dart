// 功能：日光簡約完整排版配方；只作用於草稿，示範資料由店主明確選擇後才補空白。
import 'about_page_setting.dart';

class AboutPageTemplate {
  static const title = '關於我們';
  static const subtitle = '安心入住，細心陪伴';
  static const description = '以溫暖的環境與細心陪伴，讓貓咪安心度過每一次暫時的分離。';
  static const order = [
    'principles',
    'stories',
    'highlights',
    'services',
    'team',
    'credentials',
    'message',
    'contact',
  ];
  static const appearance = <String, dynamic>{
    'coverLayout': 'centered',
    'principleLayout': 'photoSide',
    'storyLayout': 'imageLeft',
    'contactLayout': 'strip',
    'sectionSpacing': 'compact',
    'textScale': 1.0,
    'fontSource': 'custom',
    'fontFamily': 'jfOpenHuninn',
    'colorsSource': 'custom',
    'accentColor': 0xFFD08A35,
    'titleColor': 0xFF302A25,
    'bodyColor': 0xFF514B44,
    'secondaryTextColor': 0xFF635B52,
    'iconColor': 0xFFAA6622,
    'buttonColor': 0xFFAA6622,
    'backgroundSource': 'color',
    'backgroundColor': 0xFFFFFFFF,
    'cardsSource': 'custom',
    'cardColor': 0xFFFFF9F1,
    'cardOpacity': 1.0,
    'radius': 12.0,
    'borderWidth': 0.0,
    'shadow': 0.0,
    'padding': 12.0,
    'gap': 16.0,
    'cardImage': {'source': 'icon'},
    'storiesTitle': '我們的故事',
    'imageRatio': 'wide',
  };
  static bool hasPhoto(AboutMedia image, Map<String, dynamic> shop) =>
      const ['builtin', 'platform'].contains(image.source)
      ? image.assetId.isNotEmpty
      : image.resolveShop(shop).isNotEmpty;

  static AboutPageSetting apply(
    AboutPageSetting current, {
    Map<String, dynamic> shop = const {},
    bool fillEmpty = false,
  }) {
    var next = current
        .copyWith({
          'layout': 'daylight',
          'quickTemplate': 'daylight-v1',
          'sectionOrder': order,
          'coverFrame': {
            'aboutImageFit': 'cover',
            'aboutImageAlignment': 'center',
          },
        })
        .withAppearance(appearance);
    if (!fillEmpty) return next;
    if (next.coverSubtitle.isEmpty) {
      next = next.withAppearance({'coverSubtitle': subtitle});
    }
    if (!hasPhoto(next.cover, shop)) {
      next = next.copyWith({
        'cover': const AboutMedia(
          source: 'builtin',
          assetId: 'daylight-cover',
        ).toMap(),
      });
    }
    if (!next.items('principles').any((i) => i.hasContent)) {
      next = next.withItems('principles', [
        ...next.items('principles'),
        const AboutContentItem(
          id: 'daylight-principle-space',
          title: '貓咪優先',
          text: '從貓咪的角度出發，打造舒適、安心的生活空間。',
          icon: 'heart',
          image: AboutMedia(source: 'builtin', assetId: 'daylight-space'),
        ),
        const AboutContentItem(
          id: 'daylight-principle-rest',
          title: '自然舒適',
          text: '柔和採光與舒適角落，讓貓咪依自己的步調休息。',
          icon: 'leaf',
          image: AboutMedia(source: 'builtin', assetId: 'daylight-rest'),
        ),
        const AboutContentItem(
          id: 'daylight-principle-care',
          title: '細心陪伴',
          text: '用耐心與溫柔的互動，陪伴每一位入住的貓咪。',
          icon: 'people',
          image: AboutMedia(source: 'builtin', assetId: 'daylight-care'),
        ),
      ]);
    }
    if (!next.items('stories').any((i) => i.hasContent)) {
      next = next.withItems('stories', [
        ...next.items('stories'),
        const AboutContentItem(
          id: 'daylight-story',
          title: '從喜愛貓咪，到打造一個安心的家',
          text: '我們希望打造一個讓貓咪自在、也讓家長放心的環境。\n從日常休息的角落，到每一次溫柔的陪伴，讓短暫的分離也能保有熟悉與安心。',
          image: AboutMedia(source: 'builtin', assetId: 'daylight-story'),
        ),
      ]);
    }
    return next;
  }

  // 整份範本：示意圖與文字一起套入草稿，不刪除其他區塊資料或原圖。
  static AboutPageSetting complete(AboutPageSetting current) {
    final sample = apply(AboutPageSetting(), fillEmpty: true);
    var next = apply(current)
        .copyWith({'cover': sample.cover.toMap()})
        .withItems('principles', sample.items('principles'))
        .withItems('stories', sample.items('stories'))
        .withAppearance({
          'coverSubtitle': subtitle,
          'sectionBackgrounds': <String, dynamic>{},
        });
    for (final section in order) {
      if (section == 'services') continue; // 服務使用同一個顯示開關，範本不另行隱藏。
      next = next.setVisible(
        section,
        const ['principles', 'stories', 'contact'].contains(section),
      );
    }
    return next;
  }

  static Map<String, dynamic> previewShop(Map<String, dynamic> shop) => {
    ...shop,
    'aboutTitle': title,
    'aboutDescription': description,
  };
}
