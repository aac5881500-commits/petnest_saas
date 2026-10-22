// 檔案：lib/core/models/home_section_visibility.dart
// 功能：首頁獨立展示開關與舊小卡連動的單一相容入口；讀取不寫回。
import 'home_room_section_setting.dart';
import 'home_shared_entry_section_setting.dart';

class HomeSectionVisibility {
  HomeSectionVisibility(this.values);
  static const mapKey = 'sectionVisibility';
  final Map<String, bool> values;
  bool shows(String id) => values[id] ?? true;
  HomeSectionVisibility withValue(String id, bool value) =>
      HomeSectionVisibility({...values, id: value});
  Map<String, dynamic> toMap() => Map.of(values);

  static ({
    HomeSectionVisibility visibility,
    HomeSharedEntrySectionSetting shared,
  })
  read(Map<String, dynamic> modern) {
    var shared = HomeSharedEntrySectionSetting.fromMap(
      modern[HomeSharedEntrySectionSetting.mapKey],
    );
    final raw = modern[mapKey];
    final explicit = raw is Map ? raw : const {};
    final room = HomeRoomSectionSetting.fromMap(modern['roomSection']);
    // 只在尚未採用獨立開關的舊設定載入時還原舊 placement 的實際小卡。
    if (raw is! Map && roomSimpleUsesSharedZone(room)) {
      shared = shared.including(HomeSharedEntrySources.rooms, when: true);
    }
    if (raw is! Map &&
        shared.isJoined(HomeSharedEntrySources.rooms) &&
        !shared.cards.containsKey(HomeSharedEntrySources.rooms)) {
      final fallback = HomeSharedEntryCardSetting.fallback(
        HomeSharedEntrySources.rooms,
      );
      shared = shared.updateCard(
        HomeSharedEntrySources.rooms,
        fallback.copyWith(
          title: room.title.trim().isEmpty ? fallback.title : room.title.trim(),
          subtitle: room.simple.subtitle,
          showSubtitle: room.simple.showSubtitle,
        ),
      );
    }
    final joined = shared.enabled ? shared.cardOrder.toSet() : <String>{};
    final result = <String, bool>{};
    for (final id in HomeSharedEntrySources.joinable) {
      if (explicit[id] is bool) {
        result[id] = explicit[id] as bool;
        continue;
      }
      var visible = true;
      if (joined.contains(id)) {
        final sectionKey = switch (id) {
          'rooms' => 'roomSection',
          'facilities' => 'environmentSection',
          'about' => 'aboutSection',
          _ => '',
        };
        if (sectionKey.isEmpty) {
          visible = false;
        } else {
          final section = modern[sectionKey];
          visible = !(section is Map && section['layout'] == 'simpleEntry');
        }
      }
      result[id] = visible;
    }
    return (visibility: HomeSectionVisibility(result), shared: shared);
  }
}
