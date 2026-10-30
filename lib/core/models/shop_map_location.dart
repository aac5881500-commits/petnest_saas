class ShopMapLocation {
  const ShopMapLocation(this.latitude, this.longitude);
  final double latitude, longitude;
  static ShopMapLocation? fromMap(Object? value) {
    if (value is! Map || value['confirmed'] != true) return null;
    return parse(value['latitude'], value['longitude']);
  }

  static ShopMapLocation? parse(Object? latitude, Object? longitude) {
    final lat = double.tryParse('$latitude');
    final lng = double.tryParse('$longitude');
    if (lat == null ||
        lng == null ||
        !lat.isFinite ||
        !lng.isFinite ||
        lat < -90 ||
        lat > 90 ||
        lng < -180 ||
        lng > 180) {
      return null;
    }
    return ShopMapLocation(lat, lng);
  }

  bool within(double south, double west, double north, double east) =>
      latitude >= south &&
      latitude <= north &&
      (west <= east
          ? longitude >= west && longitude <= east
          : longitude >= west || longitude <= east);
}
