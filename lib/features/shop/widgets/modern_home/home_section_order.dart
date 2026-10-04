/// 新版首頁可排序區塊。header、店家資訊、footer 與浮動按鈕不在這份順序裡。
class HomeSectionOrder {
  const HomeSectionOrder._();

  static const List<String> defaultOrder = <String>[
    'banners',
    'quickBooking',
    'facilities',
    'announcements',
    'dailyCare',
    'rooms',
    'featured',
    'storeEntrance',
    'about',
    'services',
    'policy',
    'faq',
    'reviews',
  ];

  static List<String> normalize(Object? raw) {
    final List<String> kept = <String>[];
    if (raw is List) {
      for (final Object? item in raw) {
        final String id = item.toString().trim();
        if (defaultOrder.contains(id) && !kept.contains(id)) {
          kept.add(id);
        }
      }
    }
    if (raw == null) {
      return List<String>.from(defaultOrder);
    }
    for (int index = 0; index < defaultOrder.length; index++) {
      final String id = defaultOrder[index];
      if (kept.contains(id)) {
        continue;
      }
      int insertAt = kept.length;
      bool anchored = false;
      for (int previous = index - 1; previous >= 0; previous--) {
        final int found = kept.indexOf(defaultOrder[previous]);
        if (found >= 0) {
          insertAt = found + 1;
          anchored = true;
          break;
        }
      }
      if (!anchored) {
        for (int next = index + 1; next < defaultOrder.length; next++) {
          final int found = kept.indexOf(defaultOrder[next]);
          if (found >= 0) {
            insertAt = found;
            break;
          }
        }
      }
      kept.insert(insertAt, id);
    }
    return kept;
  }

  /// 關閉的區塊先從畫面上拿掉，儲存順序仍保留原位置。
  static List<String> visible(
    List<String> order, {
    required bool showAnnouncements,
    bool showAbout = true,
    bool showPolicy = false,
    bool showFaq = false,
    bool showReviews = true,
    bool showFacilities = true,
    bool showQuickBooking = false,
  }) {
    return order.where((String id) {
      if (id == 'announcements' && !showAnnouncements) {
        return false;
      }
      if (id == 'facilities' && !showFacilities) {
        return false;
      }
      if (id == 'about' && !showAbout) {
        return false;
      }
      if (id == 'policy' && !showPolicy) {
        return false;
      }
      if (id == 'faq' && !showFaq) {
        return false;
      }
      if (id == 'reviews' && !showReviews) {
        return false;
      }
      if (id == 'quickBooking' && !showQuickBooking) {
        return false;
      }
      return defaultOrder.contains(id);
    }).toList();
  }

  /// [newIndex] 使用 ReorderableListView 的原始索引，往下移時會先減 1。
  static List<String> reorderVisible({
    required List<String> saved,
    required List<String> visible,
    required int oldIndex,
    required int newIndex,
  }) {
    if (oldIndex < 0 || oldIndex >= visible.length || visible.isEmpty) {
      return List<String>.from(saved);
    }
    int target = newIndex;
    if (target > oldIndex) {
      target -= 1;
    }
    if (target < 0) {
      target = 0;
    }
    if (target > visible.length - 1) {
      target = visible.length - 1;
    }
    if (target == oldIndex) {
      return List<String>.from(saved);
    }
    final List<String> nextVisible = List<String>.from(visible);
    final String moved = nextVisible.removeAt(oldIndex);
    nextVisible.insert(target, moved);
    final List<String> queue = List<String>.from(nextVisible);
    return saved.map((String id) {
      if (!visible.contains(id)) {
        return id;
      }
      return queue.removeAt(0);
    }).toList();
  }
}

/// 編排畫布與外觀預覽不建立店家選單。正式前台維持原權限。
bool showHomeShopMenu({required bool layoutCanvas, required bool isPreview}) {
  return !layoutCanvas && !isPreview;
}
