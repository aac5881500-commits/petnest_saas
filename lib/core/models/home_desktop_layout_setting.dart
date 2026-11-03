/// Desktop presentation only. All shop content stays in its original modules.
class HomeDesktopLayoutSetting {
  const HomeDesktopLayoutSetting({this.preset = standard});
  static const mapKey = 'desktopLayout';
  static const breakpoint = 900.0;
  static const standard = 'standard';
  static const showcase = 'showcase';
  static const compact = 'compact';
  static const labels = {standard: '置中標準', showcase: '大圖展示', compact: '精簡瀏覽'};
  static const descriptions = {
    standard: '適中海報、三欄房型，適合一般店家。',
    showcase: '加大海報、兩欄房型，突出空間照片。',
    compact: '較矮海報、四欄房型，快速瀏覽資訊。',
  };
  final String preset;
  double get maxWidth => switch (preset) {
    showcase => 1360,
    compact => 1080,
    _ => 1180,
  };
  double get bannerHeight => switch (preset) {
    showcase => 420,
    compact => 230,
    _ => 320,
  };
  int get roomColumns => switch (preset) {
    showcase => 2,
    compact => 4,
    _ => 3,
  };
  int columnsForWidth(double width) =>
      roomColumns.clamp(1, (width / 260).floor().clamp(1, 4));
  double get sectionGap => switch (preset) {
    showcase => 28,
    compact => 16,
    _ => 24,
  };
  double get cardScale => switch (preset) {
    showcase => .9,
    compact => .72,
    _ => .8,
  };
  double get aboutPhotoHeight => switch (preset) {
    showcase => 320,
    compact => 220,
    _ => 280,
  };
  Map<String, dynamic> toMap() => {'preset': preset};
  static HomeDesktopLayoutSetting fromMap(Object? raw) {
    final id = raw is Map ? raw['preset']?.toString() : null;
    return HomeDesktopLayoutSetting(
      preset: labels.containsKey(id) ? id! : standard,
    );
  }
}
