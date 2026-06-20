// lib/features/shop/widgets/booking/booking_addon_section.dart
// 🔥 前台預約加值服務區塊：顯示營業時間外入住、加值服務、客製化服務
// ✅ 防呆版：避免 addonData 缺少欄位時 Unexpected null value

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
    final bool addonEnabled = addonData?['enabled'] == true;

    final timeOptions = List<Map<String, dynamic>>.from(
      addonData?['timeOptions'] ?? [],
    );

    final valueServices = List<Map<String, dynamic>>.from(
      addonData?['valueServices'] ?? [],
    );

    final customServices = List<Map<String, dynamic>>.from(
      addonData?['customServices'] ?? [],
    );

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

              if (addonLoading)
                const Center(child: CircularProgressIndicator()),

              if (!addonLoading && addonData == null)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    '目前尚未設定加值服務',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),

              if (!addonLoading && addonData != null) ...[
                if (!addonEnabled)
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

                if (addonEnabled && timeOptions.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  const Text(
                    '營業時間外入住',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),

                  const SizedBox(height: 6),

                  ...timeOptions.map((item) {
                    final label = item['label']?.toString() ?? '';
                    final isSelected =
                        selectedTimeAddon?['label'] == item['label'];

                    return GestureDetector(
                      onTap: () => onSelectTimeAddon(item),
                      child: AddonItemCard(
                        item: {...item, 'name': label},
                        isSelected: isSelected,
                      ),
                    );
                  }),
                ],

                if (valueServices.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '加值服務',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),

                  ...valueServices.map((item) {
                    final itemName = item['name']?.toString() ?? '';

                    final isSelected = selectedValueServices.any(
                      (e) => e['name'] == itemName,
                    );

                    return GestureDetector(
                      onTap: () => onToggleValueService(item),
                      child: AddonItemCard(item: item, isSelected: isSelected),
                    );
                  }),
                ],

                if (customServices.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '客製化服務',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),

                  ...customServices.map((item) {
                    final serviceName = item['name']?.toString() ?? '';

                    if (serviceName.isEmpty) {
                      return const SizedBox.shrink();
                    }

                    final isSelected = selectedCustomServices.containsKey(
                      serviceName,
                    );

                    return GestureDetector(
                      onTap: () => onToggleCustomService(item),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AddonItemCard(item: item, isSelected: isSelected),

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

                                  final petName =
                                      pet['name']?.toString() ?? petId;

                                  final selectedList =
                                      selectedCustomServices[serviceName] ?? [];

                                  final selected = selectedList.contains(petId);

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
            ],
          ),
      ],
    );
  }
}
