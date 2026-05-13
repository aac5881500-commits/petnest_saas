// lib/features/shop/widgets/booking/booking_addon_section.dart
// 🔥 前台預約加值服務區塊：顯示營業時間外入住、加值服務、客製化服務

import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/booking/addon_item_card.dart';

class BookingAddonSection extends StatelessWidget {
  const BookingAddonSection({
    super.key,
    required this.showAddons,
    required this.addonLoading,
    required this.addonData,
    required this.selectedPetIds,
    required this.pets,
    required this.selectedTimeAddon,
    required this.selectedValueServices,
    required this.selectedCustomServices,
    required this.onToggleShowAddons,
    required this.onSelectTimeAddon,
    required this.onToggleValueService,
    required this.onToggleCustomService,
    required this.onToggleCustomPet,
  });

  final bool showAddons;
  final bool addonLoading;
  final Map<String, dynamic>? addonData;
  final List<String> selectedPetIds;
  final List<Map<String, dynamic>> pets;

  final Map<String, dynamic>? selectedTimeAddon;
  final List<Map<String, dynamic>> selectedValueServices;
  final Map<String, List<String>> selectedCustomServices;

  final VoidCallback onToggleShowAddons;
  final ValueChanged<Map<String, dynamic>> onSelectTimeAddon;
  final ValueChanged<Map<String, dynamic>> onToggleValueService;
  final ValueChanged<Map<String, dynamic>> onToggleCustomService;
  final void Function(String serviceName, String petId, bool selected)
      onToggleCustomPet;

  @override
Widget build(BuildContext context) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),

      GestureDetector(
        onTap: onToggleShowAddons,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '加值服務',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Icon(
                showAddons
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
              ),
            ],
          ),
        ),
      ),

      if (showAddons)
  Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [

      const SizedBox(height: 10),

      /// 🔥 載入中
      if (addonLoading)
        const Center(
          child: CircularProgressIndicator(),
        ),

      if (!addonLoading && addonData != null) ...[
  if (addonData?['enabled'] == false)
    const Padding(
      padding: EdgeInsets.only(top: 10),
      child: Text(
        '目前未開放營業時間外入住',
        style: TextStyle(
          color: Colors.red,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),

  if (addonData?['enabled'] == true &&
      (addonData!['timeOptions'] ?? []).isNotEmpty) ...[
    const SizedBox(height: 10),

    const Text(
      '營業時間外入住',
      style: TextStyle(fontWeight: FontWeight.bold),
    ),

    const SizedBox(height: 4),

    const Text(
      '※ 正常營業時間入住不需勾選',
      style: TextStyle(
        color: Colors.red,
        fontSize: 12,
      ),
    ),

    const SizedBox(height: 6),

    ...List<Map<String, dynamic>>.from(
      addonData!['timeOptions'],
    ).map((item) {
      final isSelected =
          selectedTimeAddon?['label'] == item['label'];

      return GestureDetector(
        onTap: () => onSelectTimeAddon(item),
        child: AddonItemCard(
          item: {
            ...item,
            'name': item['label'],
          },
          isSelected: isSelected,
        ),
      );
    }),
  ],
],
if ((addonData!['valueServices'] ?? []).isNotEmpty) ...[
  const SizedBox(height: 16),

  const Text(
    '加值服務',
    style: TextStyle(fontWeight: FontWeight.bold),
  ),

  const SizedBox(height: 6),

  ...List<Map<String, dynamic>>.from(
    addonData!['valueServices'],
  ).map((item) {
    final isSelected = selectedValueServices.any(
      (e) => e['name'] == item['name'],
    );

    return GestureDetector(
      onTap: () => onToggleValueService(item),
      child: AddonItemCard(
        item: item,
        isSelected: isSelected,
      ),
    );
  }),
],
if ((addonData!['customServices'] ?? []).isNotEmpty) ...[
  const SizedBox(height: 16),

  const Text(
    '客製化服務',
    style: TextStyle(fontWeight: FontWeight.bold),
  ),

  const SizedBox(height: 6),

  ...List<Map<String, dynamic>>.from(
    addonData!['customServices'],
  ).map((item) {
    final serviceName = item['name'];
    final isSelected =
        selectedCustomServices.containsKey(serviceName);

    return GestureDetector(
      onTap: () => onToggleCustomService(item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AddonItemCard(
            item: item,
            isSelected: isSelected,
          ),

          if (isSelected)
            Padding(
              padding: const EdgeInsets.only(left: 30, top: 6),
              child: Wrap(
                spacing: 6,
                children: selectedPetIds.map((petId) {
                  final pet = pets.firstWhere(
                    (p) => p['petId'] == petId,
                    orElse: () => {},
                  );

                  final petName = pet['name'] ?? petId;

                  final selectedList =
                      selectedCustomServices[serviceName] ?? [];

                  final selected =
                      selectedList.contains(petId);

                  return FilterChip(
                    label: Text('🐱 $petName'),
                    selected: selected,
                    onSelected: (value) {
                      onToggleCustomPet(
                        serviceName,
                        petId,
                        value,
                      );
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }),
],

    ],
  ),
    ],
  );
}
}