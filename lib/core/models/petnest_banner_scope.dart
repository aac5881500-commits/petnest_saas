// lib/core/models/petnest_banner_scope.dart
// 首頁 / 商城海報共用 Editor、Renderer；資料與連結選項依 scope 分開。

enum PetNestBannerScope { home, store }

class HomeBannerActionTypes {
  static const String none = 'none';
  static const String booking = 'booking';
  static const String rooms = 'rooms';
  static const String policy = 'policy';
  static const String about = 'about';
  static const String reviews = 'reviews';
  static const String faq = 'faq';
  static const String store = 'store';
  static const String product = 'product';
  static const String url = 'url';

  static const List<String> editorTypes = <String>[
    none,
    booking,
    rooms,
    policy,
    about,
    reviews,
    faq,
    store,
    product,
  ];

  static const List<String> all = <String>[...editorTypes, url];

  static String label(String type) {
    switch (type) {
      case booking:
        return '我要預約';
      case rooms:
        return '全部房型';
      case policy:
        return '入住須知';
      case about:
        return '關於我們';
      case reviews:
        return '評價專區';
      case faq:
        return '常見問題';
      case store:
        return '寵物賣場';
      case product:
        return '指定商城商品';
      case url:
        return '外部網址';
      default:
        return '無';
    }
  }
}
