// lib/features/admin/widgets/admin_create_booking_addon_section.dart
// 🎁 後台手動新增訂單：加值服務選擇區塊
// 功能：顯示時間加購、一般加值服務、客製化服務

import 'package:flutter/material.dart';

class AdminCreateBookingAddonSection extends StatelessWidget {
  const AdminCreateBookingAddonSection({
    super.key,
    required this.addonLoading,
    required this.addonData,
    required this.pets,
    required this.selectedTimeAddon,
    required this.selectedAddonNames,
    required this.selectedCustomServices,
    required this.onSelectTimeAddon,
    required this.onToggleValueService,
    required this.onToggleCustomPet,
  });

  final bool addonLoading;
  final Map<String, dynamic>? addonData;
  final List<Map<String, dynamic>> pets;
  final Map<String, dynamic>? selectedTimeAddon;
  final Set<String> selectedAddonNames;
  final Map<String, List<String>> selectedCustomServices;

  final void Function(Map<String, dynamic> item) onSelectTimeAddon;
  final void Function(Map<String, dynamic> item, bool selected)
      onToggleValueService;
  final void Function({
    required String serviceName,
    required String petId,
    required bool selected,
  }) onToggleCustomPet;

  @override
  Widget build(BuildContext context) {
    final valueServices = List<Map<String, dynamic>>.from(
      addonData?['valueServices'] ?? [],
    );

    final timeOptions = List<Map<String, dynamic>>.from(
      addonData?['timeOptions'] ?? [],
    );

    final customServices = List<Map<String, dynamic>>.from(
      addonData?['customServices'] ?? [],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '第五步：加值服務',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),

        const SizedBox(height: 8),

        const Text(
          '可選擇本次訂單需要的加值服務。',
          style: TextStyle(color: Colors.grey),
        ),

        const SizedBox(height: 16),

        if (timeOptions.isNotEmpty) ...[
          const Text(
            '時間加購（單選）',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 8),

          ...timeOptions.map((item) {
            final label = item['label']?.toString() ?? '';
            final price = item['price'] ?? 0;

            return RadioListTile<String>(
              value: label,
              groupValue: selectedTimeAddon?['label'],
              title: Text(label),
              subtitle: Text('NT\$ $price'),
              onChanged: (_) => onSelectTimeAddon(item),
            );
          }),

          const SizedBox(height: 16),
        ],

        if (customServices.isNotEmpty) ...[
          const Text(
            '客製化服務',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),

          const SizedBox(height: 8),

          ...customServices.map((service) {
            final serviceName = service['name']?.toString() ?? '';
            final price = service['price'] ?? 0;

            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$serviceName / NT\$ $price',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Wrap(
                      spacing: 8,
                      children: pets.map((pet) {
                        final petId = pet['petId']?.toString() ?? '';
                        final petName = pet['name']?.toString() ?? '';

                        final selected =
                            (selectedCustomServices[serviceName] ?? [])
                                .contains(petId);

                        return FilterChip(
                          label: Text(petName),
                          selected: selected,
                          onSelected: (value) {
                            onToggleCustomPet(
                              serviceName: serviceName,
                              petId: petId,
                              selected: value,
                            );
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],

        if (addonLoading)
          const Center(child: CircularProgressIndicator())
        else if (valueServices.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.orange.shade200),
            ),
            child: const Text('目前店家沒有設定加值服務，可直接下一步。'),
          )
        else
          Column(
            children: valueServices.map((item) {
              final name = item['name']?.toString() ?? '';
              final price = item['price'] ?? 0;
              final selected = selectedAddonNames.contains(name);

              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: CheckboxListTile(
                  value: selected,
                  title: Text(name),
                  subtitle: Text('NT\$ $price'),
                  onChanged: (value) {
                    onToggleValueService(
                      item,
                      value == true,
                    );
                  },
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}