// 功能：關於我們範本的內建示意照片識別，不接受任意 asset 路徑。
class AboutBuiltinPhotos {
  static const atlas = 'assets/images/about_daylight_photos_v1.png';
  static const names = {
    'daylight-cover': '日光貓旅封面',
    'daylight-space': '窗邊貓咪',
    'daylight-rest': '安靜休息',
    'daylight-care': '溫柔陪伴',
    'daylight-story': '窗邊故事',
    'daylight-room': '明亮空間',
  };
  static int cell(String id) => names.keys.toList().indexOf(id);
}
