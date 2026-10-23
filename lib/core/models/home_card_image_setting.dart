/// 首頁入口裝飾圖片；只保存平台素材識別，不複製內容照片。
class HomeCardImageSetting {
  const HomeCardImageSetting({this.source = 'icon', this.assetId = ''});
  final String source;
  final String assetId;
  bool get usesLibrary => source == 'platformCard';
  HomeCardImageSetting copyWith({String? source, String? assetId}) =>
      HomeCardImageSetting(
        source: source ?? this.source,
        assetId: assetId ?? this.assetId,
      );
  Map<String, dynamic> toMap() => {
    'source': usesLibrary ? 'platformCard' : 'icon',
    'assetId': assetId,
  };
  static HomeCardImageSetting fromMap(Object? raw) {
    if (raw is! Map) return const HomeCardImageSetting();
    final id = (raw['assetId'] ?? '').toString().trim();
    return HomeCardImageSetting(
      source: raw['source'] == 'platformCard' ? 'platformCard' : 'icon',
      assetId: id.length <= 128 && !id.contains('/') ? id : '',
    );
  }
}
