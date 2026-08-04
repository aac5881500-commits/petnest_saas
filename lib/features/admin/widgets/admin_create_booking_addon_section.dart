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
    required this.startDate,
    required this.endDate,
    required this.selectedDailyTimedServices,
    required this.onDailyTimedServicesChanged,
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
  final DateTime? startDate;
  final DateTime? endDate;

  final Map<String, Map<String, Map<String, List<String>>>>
  selectedDailyTimedServices;

  final VoidCallback onDailyTimedServicesChanged;

  final void Function(Map<String, dynamic> item) onSelectTimeAddon;
  final void Function(Map<String, dynamic> item, bool selected)
  onToggleValueService;
  final void Function({
    required String serviceName,
    required String petId,
    required bool selected,
  })
  onToggleCustomPet;

  /// 取得每日分時段服務的固定識別 ID。
  String _dailyTimedServiceId(Map<String, dynamic> service, int index) {
    final id = service['id']?.toString().trim() ?? '';

    if (id.isNotEmpty) {
      return id;
    }

    final name = service['name']?.toString().trim() ?? '';

    if (name.isNotEmpty) {
      return 'daily_timed_$name';
    }

    return 'daily_timed_$index';
  }

  /// 取得寵物 ID。
  String _petId(Map<String, dynamic> pet) {
    final petId = pet['petId']?.toString().trim() ?? '';

    if (petId.isNotEmpty) {
      return petId;
    }

    return pet['id']?.toString().trim() ?? '';
  }

  /// 取得寵物名稱。
  String _petName(Map<String, dynamic> pet, String fallbackPetId) {
    final name = pet['name']?.toString().trim() ?? '';

    if (name.isNotEmpty) {
      return name;
    }

    return fallbackPetId.isNotEmpty ? fallbackPetId : '未命名寵物';
  }

  /// 產生入住期間每天的服務日期。
  /// 包含入住日，不包含退房日。
  List<DateTime> _buildServiceDates() {
    if (startDate == null || endDate == null) {
      return const [];
    }

    final normalizedStart = DateTime(
      startDate!.year,
      startDate!.month,
      startDate!.day,
    );

    final normalizedEnd = DateTime(endDate!.year, endDate!.month, endDate!.day);

    if (!normalizedEnd.isAfter(normalizedStart)) {
      return const [];
    }

    final dates = <DateTime>[];
    var currentDate = normalizedStart;

    while (currentDate.isBefore(normalizedEnd)) {
      dates.add(currentDate);
      currentDate = currentDate.add(const Duration(days: 1));
    }

    return dates;
  }

  /// 日期轉成 Firestore 使用格式。
  String _dateKey(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');

    return '${date.year}-$month-$day';
  }

  /// 顯示日期文字。
  String _dateLabel(DateTime date) {
    const weekdays = <String>['一', '二', '三', '四', '五', '六', '日'];

    return '${date.month}/${date.day}（週${weekdays[date.weekday - 1]}）';
  }

  /// 取得服務可選時段。
  List<Map<String, dynamic>> _serviceTimeSlots(Map<String, dynamic> service) {
    final rawSlots = service['timeSlots'];

    if (rawSlots is! List) {
      return const [];
    }

    final slots = <Map<String, dynamic>>[];

    for (var index = 0; index < rawSlots.length; index++) {
      final rawSlot = rawSlots[index];

      if (rawSlot is Map) {
        final slot = Map<String, dynamic>.from(rawSlot);
        final label = slot['label']?.toString().trim() ?? '';

        if (label.isEmpty) {
          continue;
        }

        final id = slot['id']?.toString().trim() ?? '';

        slots.add({'id': id.isNotEmpty ? id : 'slot_$index', 'label': label});
      } else {
        final label = rawSlot?.toString().trim() ?? '';

        if (label.isNotEmpty) {
          slots.add({'id': 'slot_$index', 'label': label});
        }
      }
    }

    return slots;
  }

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

    final dailyTimedServices = List<Map<String, dynamic>>.from(
      addonData?['dailyTimedServices'] ?? [],
    );

    final serviceDates = _buildServiceDates();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '第五步：加值服務',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
        ),

        const SizedBox(height: 8),

        const Text('可選擇本次訂單需要的加值服務。', style: TextStyle(color: Colors.grey)),

        const SizedBox(height: 16),

        if (timeOptions.isNotEmpty) ...[
          const Text(
            '時間加購（單選）',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
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
                      style: const TextStyle(fontWeight: FontWeight.bold),
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

        // ===============================
        // 🕐 每日分時段服務
        // ===============================
        if (dailyTimedServices.isNotEmpty) ...[
          const SizedBox(height: 16),

          const Text(
            '每日分時段服務',
            style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
          ),

          const SizedBox(height: 6),

          const Text(
            '請先選擇需要服務的寵物，再依每天選擇餵食或服務時段。',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),

          const SizedBox(height: 10),

          if (startDate == null || endDate == null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text('請先選擇入住日期與退房日期。'),
            )
          else if (pets.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text('請先選擇本次入住的寵物。'),
            )
          else
            ...dailyTimedServices.asMap().entries.map((entry) {
              final serviceIndex = entry.key;
              final service = entry.value;

              final serviceId = _dailyTimedServiceId(service, serviceIndex);

              final serviceName = service['name']?.toString().trim() ?? '';

              final serviceDescription =
                  service['desc']?.toString().trim() ?? '';

              final servicePrice = (service['price'] as num?)?.toInt() ?? 0;

              final timeSlots = _serviceTimeSlots(service);

              if (serviceName.isEmpty) {
                return const SizedBox.shrink();
              }

              final selectedServicePets =
                  selectedDailyTimedServices[serviceId] ??
                  <String, Map<String, List<String>>>{};

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              serviceName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          Text(
                            'NT\$ $servicePrice / 次',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),

                      if (serviceDescription.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          serviceDescription,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      ],

                      const Divider(height: 24),

                      const Text(
                        '選擇服務寵物',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),

                      const SizedBox(height: 8),

                      ...pets.map((pet) {
                        final petId = _petId(pet);
                        final petName = _petName(pet, petId);

                        if (petId.isEmpty) {
                          return const SizedBox.shrink();
                        }

                        final petSelected = selectedServicePets.containsKey(
                          petId,
                        );

                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: petSelected
                                ? Colors.blueGrey.shade50
                                : Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: petSelected
                                  ? Colors.blueGrey.shade300
                                  : Colors.grey.shade300,
                            ),
                          ),
                          child: Column(
                            children: [
                              CheckboxListTile(
                                value: petSelected,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: Text('🐱 $petName'),
                                subtitle: petSelected
                                    ? const Text('請選擇每天需要的服務時段')
                                    : null,
                                onChanged: (value) {
                                  if (value == true) {
                                    selectedDailyTimedServices
                                        .putIfAbsent(
                                          serviceId,
                                          () =>
                                              <
                                                String,
                                                Map<String, List<String>>
                                              >{},
                                        )
                                        .putIfAbsent(
                                          petId,
                                          () => <String, List<String>>{},
                                        );
                                  } else {
                                    selectedDailyTimedServices[serviceId]
                                        ?.remove(petId);

                                    if (selectedDailyTimedServices[serviceId]
                                            ?.isEmpty ==
                                        true) {
                                      selectedDailyTimedServices.remove(
                                        serviceId,
                                      );
                                    }
                                  }

                                  onDailyTimedServicesChanged();
                                },
                              ),

                              if (petSelected)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    12,
                                    0,
                                    12,
                                    12,
                                  ),
                                  child: Column(
                                    children: serviceDates.map((date) {
                                      final dateKey = _dateKey(date);

                                      final selectedSlotIds =
                                          selectedDailyTimedServices[serviceId]?[petId]?[dateKey] ??
                                          <String>[];

                                      return Container(
                                        width: double.infinity,
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _dateLabel(date),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),

                                            const SizedBox(height: 8),

                                            if (timeSlots.isEmpty)
                                              const Text(
                                                '此服務尚未設定時段。',
                                                style: TextStyle(
                                                  color: Colors.orange,
                                                ),
                                              )
                                            else
                                              Wrap(
                                                spacing: 8,
                                                runSpacing: 8,
                                                children: timeSlots.map((slot) {
                                                  final slotId =
                                                      slot['id']?.toString() ??
                                                      '';

                                                  final slotLabel =
                                                      slot['label']
                                                          ?.toString() ??
                                                      '';

                                                  final selected =
                                                      selectedSlotIds.contains(
                                                        slotId,
                                                      );

                                                  return FilterChip(
                                                    label: Text(slotLabel),
                                                    selected: selected,
                                                    showCheckmark: false,
                                                    onSelected: (value) {
                                                      final serviceMap =
                                                          selectedDailyTimedServices
                                                              .putIfAbsent(
                                                                serviceId,
                                                                () =>
                                                                    <
                                                                      String,
                                                                      Map<
                                                                        String,
                                                                        List<
                                                                          String
                                                                        >
                                                                      >
                                                                    >{},
                                                              );

                                                      final petMap = serviceMap
                                                          .putIfAbsent(
                                                            petId,
                                                            () =>
                                                                <
                                                                  String,
                                                                  List<String>
                                                                >{},
                                                          );

                                                      final dateList = petMap
                                                          .putIfAbsent(
                                                            dateKey,
                                                            () => <String>[],
                                                          );

                                                      if (value) {
                                                        if (!dateList.contains(
                                                          slotId,
                                                        )) {
                                                          dateList.add(slotId);
                                                        }
                                                      } else {
                                                        dateList.remove(slotId);

                                                        if (dateList.isEmpty) {
                                                          petMap.remove(
                                                            dateKey,
                                                          );
                                                        }
                                                      }

                                                      onDailyTimedServicesChanged();
                                                    },
                                                  );
                                                }).toList(),
                                              ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        );
                      }),
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
                    onToggleValueService(item, value == true);
                  },
                ),
              );
            }).toList(),
          ),
      ],
    );
  }
}
