// lib/features/shop/widgets/booking/booking_addons_helper.dart
// 🔥 前台預約加值服務 helper：整理送出訂單用的 addons 資料

class BookingAddonsHelper {
  static List<Map<String, dynamic>> buildAddonsData({
    required Map<String, dynamic>? selectedTimeAddon,
    required List<Map<String, dynamic>> selectedValueServices,
    required Map<String, List<String>> selectedCustomServices,
    required Map<String, Map<String, Map<String, List<String>>>>
    selectedDailyTimedServices,
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
        'id': item['id'],
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
        'useInventory': item['useInventory'] == true,
        'inventoryBindings': item['inventoryBindings'] ?? <dynamic>[],
      });
    }

    for (final entry in selectedCustomServices.entries) {
      final name = entry.key;
      final petList = entry.value;

      final service = (addonData?['customServices'] ?? []).firstWhere(
        (e) => e['name'] == name,
        orElse: () => {},
      );

      final price = service['price'] ?? 0;

      addons.add({
        'id': service['id'],
        'name': name,
        'price': price,
        'count': petList.length,
        'total': price * petList.length,
        'petNames': petList.map((petId) {
          final pet = pets.where((p) => p['petId'] == petId).toList();

          if (pet.isEmpty) return petId;

          return (pet.first['name'] ?? petId).toString();
        }).toList(),
        'type': 'custom',
        'useInventory': service['useInventory'] == true,
        'inventoryBindings': service['inventoryBindings'] ?? <dynamic>[],
      });
    }
    final dailyTimedServices = List<Map<String, dynamic>>.from(
      addonData?['dailyTimedServices'] ?? [],
    );

    for (final entry in dailyTimedServices.asMap().entries) {
      final serviceIndex = entry.key;
      final service = entry.value;

      final rawServiceId = service['id']?.toString().trim() ?? '';
      final serviceName = service['name']?.toString().trim() ?? '';

      final serviceId = rawServiceId.isNotEmpty
          ? rawServiceId
          : serviceName.isNotEmpty
          ? 'daily_timed_$serviceName'
          : 'daily_timed_$serviceIndex';

      final serviceSelections = selectedDailyTimedServices[serviceId];

      if (serviceSelections == null || serviceSelections.isEmpty) {
        continue;
      }

      final price = (service['price'] as num?)?.toInt() ?? 0;

      final timeSlots = List<Map<String, dynamic>>.from(
        service['timeSlots'] ?? [],
      );

      final slotLabels = <String, String>{};

      for (final slot in timeSlots) {
        final slotId = slot['id']?.toString().trim() ?? '';
        final slotLabel = slot['label']?.toString().trim() ?? '';

        if (slotId.isNotEmpty) {
          slotLabels[slotId] = slotLabel.isNotEmpty ? slotLabel : slotId;
        }
      }

      final selections = <Map<String, dynamic>>[];
      var count = 0;

      for (final petEntry in serviceSelections.entries) {
        final petId = petEntry.key;

        final pet = pets.firstWhere((item) {
          final itemPetId =
              item['petId']?.toString() ?? item['id']?.toString() ?? '';

          return itemPetId == petId;
        }, orElse: () => <String, dynamic>{});

        final petName = pet['name']?.toString().trim().isNotEmpty == true
            ? pet['name'].toString().trim()
            : petId;

        final dates = <Map<String, dynamic>>[];

        final sortedDateEntries = petEntry.value.entries.toList()
          ..sort((a, b) => a.key.compareTo(b.key));

        for (final dateEntry in sortedDateEntries) {
          final slotIds = dateEntry.value;

          if (slotIds.isEmpty) {
            continue;
          }

          count += slotIds.length;

          dates.add({
            'date': dateEntry.key,
            'slotIds': List<String>.from(slotIds),
            'slotLabels': slotIds
                .map((slotId) => slotLabels[slotId] ?? slotId)
                .toList(),
          });
        }

        if (dates.isNotEmpty) {
          selections.add({'petId': petId, 'petName': petName, 'dates': dates});
        }
      }

      if (count == 0) {
        continue;
      }

      addons.add({
        'serviceId': serviceId,
        'name': serviceName.isNotEmpty ? serviceName : '每日分時段服務',
        'price': price,
        'count': count,
        'total': price * count,
        'selections': selections,
        'type': 'daily_timed',
        'useInventory': service['useInventory'] == true,
        'inventoryBindings': service['inventoryBindings'] ?? <dynamic>[],
      });
    }

    return addons;
  }
}
