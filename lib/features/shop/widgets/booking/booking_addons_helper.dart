// lib/features/shop/widgets/booking/booking_addons_helper.dart
// 🔥 前台預約加值服務 helper：整理送出訂單用的 addons 資料

class BookingAddonsHelper {
  static List<Map<String, dynamic>> buildAddonsData({
    required Map<String, dynamic>? selectedTimeAddon,
    required List<Map<String, dynamic>> selectedValueServices,
    required Map<String, List<String>> selectedCustomServices,
    required Map<String, dynamic>? addonData,
    required List<String> selectedPetIds,
    required List<Map<String, dynamic>> pets,
  }) {
    final List<Map<String, dynamic>> addons = [];

    if (selectedTimeAddon != null) {
      addons.add({
        'name': selectedTimeAddon['label'],
        'price': selectedTimeAddon['price'],
        'type': 'time',
      });
    }

    for (final item in selectedValueServices) {
      addons.add({
        'name': item['name'],
        'price': item['price'],
        'type': 'value',
        'petIds': selectedPetIds,
        'petNames': selectedPetIds.map((petId) {
          final pet = pets.firstWhere(
            (p) => p['petId'] == petId,
            orElse: () => {},
          );

          return pet['name'] ?? petId;
        }).toList(),
      });
    }

    for (final entry in selectedCustomServices.entries) {
      final name = entry.key;
      final petList = entry.value;

      final service = (addonData?['customServices'] ?? [])
          .firstWhere(
            (e) => e['name'] == name,
            orElse: () => {},
          );

      final price = service['price'] ?? 0;

      addons.add({
        'name': name,
        'price': price,
        'count': petList.length,
        'total': price * petList.length,
        'petNames': petList.map((petId) {
          final pet = pets
              .where((p) => p['petId'] == petId)
              .toList();

          if (pet.isEmpty) return petId;

          return (pet.first['name'] ?? petId).toString();
        }).toList(),
        'type': 'custom',
      });
    }

    return addons;
  }
}