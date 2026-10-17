/// 新版外觀設定上方分頁。切換時用這裡的 index，避免各處寫死數字。
class ModernHomeAppearanceTabs {
  static const int appearance = 0;
  static const int rooms = 1;
  static const int facilities = 2;
  static const int about = 3;
  static const int news = 4;
  static const int quickBooking = 5;
  static const int policy = 6;
  static const int faq = 7;
  static const int reviews = 8;
  static const int navigation = 9;
  static const int length = 10;

  static int? sectionTab(String sectionId) {
    return switch (sectionId) {
      'rooms' => rooms,
      'facilities' => facilities,
      'about' => about,
      'announcements' => news,
      'quickBooking' => quickBooking,
      'policy' => policy,
      'faq' => faq,
      'reviews' => reviews,
      _ => null,
    };
  }
}
