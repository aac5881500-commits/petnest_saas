import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/home_appearance_preset.dart';
import 'package:petnest_saas/core/models/home_diary_setting.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_bottom_navigation.dart';
import 'home_diary_test.dart' show openShop;
import 'package:petnest_saas/core/models/home_news_section_setting.dart';
import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/review_model.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_diary_widgets.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_diary_reference_widgets.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_diary_settings_panel.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_news_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_room_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_about_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_policy_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_home_faq_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_review_section.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/modern_shop_footer.dart';
import 'home_storybook_test.dart' show fixture;

final draft = homeAppearancePresetById('catDiary')!.apply(fixture());
final theme = draft.theme;
final diary = theme.storybook.diary;
const photos = [
  'builtin-env:warm-room',
  'builtin-env:warm-climb',
  'builtin-env:warm-shop',
];
final rooms = [
  for (int i = 0; i < 3; i++)
    <String, dynamic>{
      'id': 'r$i',
      'name': ['日式景觀房', '森林套房', '陽光小窩'][i],
      'price': [800, 1200, 900][i],
      'images': [photos[i]],
      'isPublished': true,
    },
];
final news = [
  for (int i = 0; i < 2; i++)
    HomeNewsItem(
      id: 'n$i',
      sourceType: 'notices',
      title: ['入住前的小提醒', '貓咪環境優化完成，空間更舒適！'][i],
      summary: '',
      publishedAt: DateTime(2026, 11, 3 - i),
      pinned: false,
      iconType: 'normal',
    ),
];
const review = ReviewModel(
  reviewId: 'r',
  shopId: 'fixture',
  bookingId: 'b',
  userId: 'u',
  customerName: '貓家長',
  petNames: [],
  roomTypeName: '',
  startDate: null,
  endDate: null,
  nights: 2,
  rating: 5,
  environmentRating: 5,
  serviceRating: 5,
  priceRating: 5,
  content: '每天看見照護紀錄，出門也很安心。',
  imageUrls: [],
  reply: '',
  replyAt: null,
  replyBy: '',
  status: 'visible',
  createdAt: null,
  updatedAt: null,
);

Widget chapter(String id, Widget child) =>
    HomeDiaryChapter(sectionId: id, setting: diary, theme: theme, child: child);
Widget roomSection({
  ValueChanged<Map<String, dynamic>>? onRoom,
  VoidCallback? onAll,
}) => ModernHomeRoomSection(
  theme: theme,
  setting: draft.rooms,
  roomTypes: rooms,
  preview: false,
  onOpenRoom: onRoom,
  onOpenAllRooms: onAll,
);
Widget sections() => Column(
  crossAxisAlignment: CrossAxisAlignment.stretch,
  children: [
    const Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Text('C 實際元件預覽・以下為示意資料', style: TextStyle(fontSize: 10)),
    ),
    Wrap(
      children: [
        Icon(Icons.menu, size: 21, color: theme.textColor),
        const SizedBox(width: 14),
        Icon(Icons.pets, color: theme.primaryColor),
        const SizedBox(width: 7),
        Text(
          'PetNest 貓咪旅店',
          style: TextStyle(
            color: theme.textColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
    const SizedBox(height: 10),
    HomeDiaryCover(
      setting: diary,
      theme: theme,
      imageUrl: 'builtin-env:warm-room',
    ),
    const SizedBox(height: 9),
    HomeDiaryCareRibbon(
      theme: theme,
      petNames: '咪咪・奶茶',
      petPhotoUrl: 'builtin-env:warm-hero',
      progressText: '今日 1／3 場已更新',
      count: 3,
      completed: const {0},
      ready: true,
      onOpen: () {},
    ),
    const SizedBox(height: 6),
    chapter(
      'announcements',
      ModernHomeNewsSection(
        theme: theme,
        setting: draft.news,
        items: news,
        phase: HomeNewsSectionPhase.ready,
        preview: false,
        onOpen: (_) {},
      ),
    ),
    chapter(
      'facilities',
      HomeDiaryEnvironmentRows(
        theme: theme,
        onOpen: () {},
        items: const [
          {
            'imageUrl': 'builtin-env:rest',
            'title': '陽光・窗景與貓咪',
            'description': '自然光灑落的放鬆角落，讓貓咪自在發呆、觀景。',
          },
          {
            'imageUrl': 'builtin-env:warm-hero',
            'title': '玩耍・休息都自在',
            'description': '貓跳台、隧道與柔軟睡窩，在這裡找到舒服的節奏。',
          },
        ],
      ),
    ),
    chapter('rooms', roomSection()),
    chapter(
      'about',
      ModernHomeAboutSection(
        theme: theme,
        setting: const HomeAboutSectionSetting(
          layout: HomeAboutLayouts.diaryQuote,
          enabled: true,
          imageSource: 'legacy',
          imageUrl: 'builtin-env:warm-shop',
          summarySource: 'shop',
        ),
        shop: const {
          'aboutDescription': '把每一段分離，照顧成安心的日常。',
          'aboutCoverUrl': 'builtin-env:warm-shop',
        },
        environmentIntro: const {},
        shopName: 'PetNest',
        logoUrl: '',
        preview: false,
        onOpen: () {},
      ),
    ),
    chapter('services', HomeDiaryServices(theme: theme)),
    chapter(
      'policy',
      HomeDiaryPreparation(
        policy: ModernHomePolicySection(
          theme: theme,
          setting: draft.information.policy,
          snapshot: const HomePolicySnapshot(stayTitles: ['入住提醒']),
          phase: HomeInfoSectionPhase.ready,
          onOpen: (_) {},
        ),
        faq: ModernHomeFaqSection(
          theme: theme,
          setting: draft.information.faq,
          items: const [
            HomeFaqItem(
              id: 'f',
              question: '第一次入住要準備什麼？',
              answer: '請看店家須知。',
              sortOrder: 0,
            ),
          ],
          phase: HomeInfoSectionPhase.ready,
          onOpen: () {},
        ),
      ),
    ),
    chapter(
      'reviews',
      ModernReviewSection(
        theme: theme,
        setting: draft.information.reviews,
        reviews: const [review],
        phase: HomeInfoSectionPhase.ready,
        onOpen: () {},
      ),
    ),
    chapter(
      'featured',
      SizedBox(
        height: 100,
        child: HomeDiaryProductCard(
          theme: theme,
          name: '舒適睡窩',
          imageUrl: 'builtin-env:rest',
          price: const Text(r'NT$680'),
          onOpen: () {},
        ),
      ),
    ),
    chapter(
      'shopInfo',
      ModernShopFooter(
        shopId: 'fixture',
        shop: const {
          'businessHours': '10:00–20:00',
          'city': '台北市',
          'address': '示意地址',
          'phone': '0200000000',
          'lineUrl': 'https://example.com',
        },
        shopName: 'PetNest 貓咪旅店',
        setting: draft.shopInfo,
        primaryColor: theme.primaryColor,
        darkTextColor: theme.textColor,
        secondaryTextColor: theme.secondaryTextColor,
        cardColor: theme.cardColor,
        borderColor: theme.cardBorderColor,
        isPreview: true,
      ).buildInfoBody(_context!),
    ),
    const SizedBox(height: 8),
    ModernBottomNavigation(
      slots: draft.navigation.resolvedBottomSlots(openShop),
      theme: theme,
      selectedId: 'home',
      appearance: draft.navigation.bottomAppearance,
      surface: draft.navigation.bottomSurface,
      onSelect: (_) {},
    ),
  ],
);
BuildContext? _context;

Future<void> loadFonts() async {
  final icons = FontLoader('MaterialIcons')
    ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
  final brand = FontLoader('packages/font_awesome_flutter/FontAwesomeBrands')
    ..addFont(
      rootBundle.load(
        'packages/font_awesome_flutter/lib/fonts/Font-Awesome-7-Brands-Regular-400.otf',
      ),
    );
  await brand.load();
  for (final (family, path) in [
    ('KleeOne', 'KleeOne-Regular.ttf'),
    ('NotoSansTC', 'NotoSansTC-VariableFont_wght.ttf'),
  ]) {
    final loader = FontLoader(family)
      ..addFont(rootBundle.load('assets/fonts/$path'));
    await loader.load();
  }
}

final previewOutput = Platform.environment['PETNEST_DIARY_PREVIEW'] ?? '';
void main() {
  test('diary navigation appearance survives settings round trip', () {
    expect(
      draft.navigation.toMap()['bottomNavigationAppearance'],
      'diaryBooking',
    );
  });

  testWidgets('individual layout selection remains authoritative under C', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ModernHomeRoomSection(
            theme: theme,
            setting: draft.rooms.copyWith(
              layout: HomeRoomSectionLayouts.horizontalScroll,
            ),
            roomTypes: rooms.map((r) => {...r, 'images': <String>[]}).toList(),
            preview: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(HomeDiaryRoomRail), findsNothing);
    expect(tester.takeException(), isNull);
    expect(
      HomeRoomSectionSetting.fromMap(draft.rooms.toMap()).layout,
      HomeRoomSectionLayouts.diaryCards,
    );
    expect(
      HomeNewsSectionSetting.fromMap(draft.news.toMap()).layout,
      HomeNewsLayouts.diaryNotes,
    );
  });
  test(
    'reference visual settings persist, sanitize and remain backward compatible',
    () {
      final edited = diary.copyWith(
        reference: {
          ...diary.reference,
          'flowers': false,
          'roomFraction': .6,
          'markerColor': 0xFF123456,
          'service1': '每天整理',
          'aboutPhotoHeight': 160.0,
        },
      );
      final restored = HomeDiarySetting.fromMap(edited.toMap());
      expect(restored.toMap(), edited.toMap());
      expect(restored.flowers, false);
      expect(restored.refText('service1'), '每天整理');
      expect(
        HomeDiarySetting.fromMap({
          'reference': {'roomFraction': 999, 'roomPhotoHeight': -1},
        }).refNumber('roomFraction'),
        .7,
      );
      expect(HomeDiarySetting.fromMap({'enabled': true}).referenceCards, true);
    },
  );
  testWidgets(
    'reference room arrows scroll and real room/all links remain functional',
    (tester) async {
      var room = '', all = false;
      await tester.binding.setSurfaceSize(const Size(375, 500));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: roomSection(
              onRoom: (r) => room = r['id'],
              onAll: () => all = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('日式景觀房'));
      expect(room, 'r0');
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();
      final state = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(state.position.pixels, greaterThan(0));
      await tester.tap(find.text('全部房型 ›'));
      expect(all, true);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'new reference controls change and persist actual design settings',
    (tester) async {
      var s = diary;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (context, setState) => HomeDiarySettingsPanel(
                  setting: s,
                  onChanged: (v) => setState(() => s = v),
                  onOpenPhotos: () {},
                  onOpenEnvironment: () {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('花草角落裝飾'));
      await tester.pumpAndSettle();
      expect(s.flowers, false);
      await tester.ensureVisible(find.text('照護服務 1 名稱'));
      await tester.enterText(
        find.widgetWithText(TextFormField, '照護服務 1 名稱'),
        '每日整理',
      );
      expect(HomeDiarySetting.fromMap(s.toMap()).refText('service1'), '每日整理');
    },
  );
  testWidgets('real C modules render narrow and large text without overflow', (
    tester,
  ) async {
    await loadFonts();
    for (final (width, scale) in [(280.0, 1.7), (375.0, 1.0), (430.0, 1.0)]) {
      await tester.binding.setSurfaceSize(Size(width, 2800));
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'NotoSansTC'),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              backgroundColor: theme.backgroundColor,
              body: Builder(
                builder: (context) {
                  _context = context;
                  return SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: sections(),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'width=$width scale=$scale',
      );
    }
    await tester.binding.setSurfaceSize(null);
  });
  testWidgets('export actual C component reference preview', (tester) async {
    await loadFonts();
    await tester.binding.setSurfaceSize(const Size(390, 2600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final key = GlobalKey();
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(fontFamily: 'NotoSansTC'),
        home: Scaffold(
          backgroundColor: theme.backgroundColor,
          body: Builder(
            builder: (context) {
              _context = context;
              return SingleChildScrollView(
                child: RepaintBoundary(
                  key: key,
                  child: ColoredBox(
                    color: theme.backgroundColor,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: sections(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()!
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(previewOutput).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }, skip: previewOutput.isEmpty);
}
