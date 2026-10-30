import 'package:petnest_saas/core/models/shop_map_location.dart';

class PublicMapShop {
  const PublicMapShop({
    required this.id,
    required this.name,
    required this.address,
    required this.area,
    required this.imageUrl,
    required this.services,
    required this.isOpen,
    required this.isPublic,
    this.location,
  });
  final String id, name, address, area, imageUrl;
  final List<String> services;
  final bool isOpen, isPublic;
  final ShopMapLocation? location;
}

List<PublicMapShop> filterMapShops(
  List<PublicMapShop> shops, {
  String search = '',
  String category = '全部',
  bool openOnly = false,
  List<double>? bounds,
}) {
  final keyword = search.trim().toLowerCase();
  return shops
      .where(
        (shop) =>
            shop.isPublic &&
            (!openOnly || shop.isOpen) &&
            (category == '全部' || shop.services.contains(category)) &&
            (keyword.isEmpty ||
                '${shop.name} ${shop.address} ${shop.area} ${shop.services.join(' ')}'
                    .toLowerCase()
                    .contains(keyword)) &&
            (bounds == null ||
                shop.location?.within(
                      bounds[0],
                      bounds[1],
                      bounds[2],
                      bounds[3],
                    ) ==
                    true),
      )
      .toList();
}
