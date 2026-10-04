import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_quick_booking_section_setting.dart';
import 'package:petnest_saas/core/models/home_information_sections_setting.dart';
import 'package:petnest_saas/core/models/home_news_section_setting.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/home_room_section_setting.dart';

/// 新版首頁區塊占幾排。後續小卡只要回傳 [half]，就能走同一套並排。
enum HomeSectionSpan { full, half }

class HomeSectionRow {
  const HomeSectionRow({required this.sectionIds, required this.span});

  final List<String> sectionIds;
  final HomeSectionSpan span;

  bool get isPair => sectionIds.length == 2;
}

/// 依順序把相鄰的 half 合成一排，full 自己一排。單一 half 不會被拉成全寬。
List<HomeSectionRow> packHomeSections(
  List<String> sectionIds,
  HomeSectionSpan Function(String sectionId) spanOf,
) {
  final List<HomeSectionRow> rows = <HomeSectionRow>[];
  String? pendingHalf;
  for (final String sectionId in sectionIds) {
    final HomeSectionSpan span = spanOf(sectionId);
    if (span == HomeSectionSpan.half) {
      if (pendingHalf == null) {
        pendingHalf = sectionId;
        continue;
      }
      rows.add(
        HomeSectionRow(
          sectionIds: <String>[pendingHalf, sectionId],
          span: HomeSectionSpan.half,
        ),
      );
      pendingHalf = null;
      continue;
    }
    if (pendingHalf != null) {
      rows.add(
        HomeSectionRow(
          sectionIds: <String>[pendingHalf],
          span: HomeSectionSpan.half,
        ),
      );
      pendingHalf = null;
    }
    rows.add(
      HomeSectionRow(
        sectionIds: <String>[sectionId],
        span: HomeSectionSpan.full,
      ),
    );
  }
  if (pendingHalf != null) {
    rows.add(
      HomeSectionRow(
        sectionIds: <String>[pendingHalf],
        span: HomeSectionSpan.half,
      ),
    );
  }
  assert(() {
    final Set<String> seen = <String>{};
    for (final String sectionId in sectionIds) {
      assert(seen.add(sectionId), 'visible sectionIds 不可重複: $sectionId');
    }
    final Set<String> packed = <String>{};
    int count = 0;
    for (final HomeSectionRow row in rows) {
      assert(row.sectionIds.length <= 2, '每個 HomeSectionRow 最多兩個 sectionId');
      assert(
        row.sectionIds.toSet().length == row.sectionIds.length,
        '同一個 HomeSectionRow 不可重複 sectionId',
      );
      if (row.span == HomeSectionSpan.full) {
        assert(row.sectionIds.length == 1, 'full row 只能有一個 sectionId');
      }
      for (final String sectionId in row.sectionIds) {
        assert(packed.add(sectionId), 'pack 不可重複 sectionId: $sectionId');
      }
      count += row.sectionIds.length;
    }
    assert(count == sectionIds.length, 'pack 完成後 section 數量必須與輸入一致');
    return true;
  }());
  return rows;
}

/// 沒有獨立 span 欄位。小卡由目前的卡片尺寸推導，其餘區塊預設整排。
HomeSectionSpan homeSectionSpan({
  required String sectionId,
  required HomeRoomSectionSetting rooms,
  required HomeEnvironmentSectionSetting environment,
  HomeAboutSectionSetting? about,
  HomeNewsSectionSetting? news,
  HomeInformationSectionsSetting? information,
  HomeQuickBookingSectionSetting? quickBooking,
}) {
  switch (sectionId) {
    case 'rooms':
      final bool small =
          rooms.layout == HomeRoomSectionLayouts.simpleEntry &&
          HomeRoomSimpleCardSizes.migrate(rooms.simple.cardSize) ==
              HomeRoomSimpleCardSizes.small;
      return small ? HomeSectionSpan.half : HomeSectionSpan.full;
    case 'facilities':
      final bool small =
          environment.layout == HomeEnvironmentLayouts.simpleEntry &&
          HomeEnvironmentCardSizes.migrate(environment.simpleCardSize) ==
              HomeEnvironmentCardSizes.small;
      return small ? HomeSectionSpan.half : HomeSectionSpan.full;
    case 'about':
      return about?.isHalf == true
          ? HomeSectionSpan.half
          : HomeSectionSpan.full;
    case 'announcements':
      return news?.isHalf == true ? HomeSectionSpan.half : HomeSectionSpan.full;
    case 'policy':
      return (information?.policy ?? const HomePolicySectionSetting()).isHalf
          ? HomeSectionSpan.half
          : HomeSectionSpan.full;
    case 'faq':
      return (information?.faq ?? const HomeFaqSectionSetting()).isHalf
          ? HomeSectionSpan.half
          : HomeSectionSpan.full;
    case 'reviews':
      return (information?.reviews ?? const HomeReviewSectionSetting()).isHalf
          ? HomeSectionSpan.half
          : HomeSectionSpan.full;
    case 'quickBooking':
      return quickBooking?.isHalf == true
          ? HomeSectionSpan.half
          : HomeSectionSpan.full;
    default:
      return HomeSectionSpan.full;
  }
}
