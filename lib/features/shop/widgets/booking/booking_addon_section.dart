// lib/features/shop/widgets/booking/booking_addon_section.dart
// 🔥 前台預約加值服務區塊
// 功能：顯示營業時間外入住、一般加值服務、客製化服務、每日分時段服務
// ✅ 防呆版：避免 addonData 缺少欄位時出現 Unexpected null value

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';
import 'package:petnest_saas/features/shop/widgets/booking/addon_item_card.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_addons_helper.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_step_widgets.dart';

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
    this.startDate,
    this.endDate,
    this.selectedDailyTimedServices = const {},
    this.theme = HomeThemeModel.classicDefault,
    this.addonTotal = 0,
    required this.onToggleShowAddons,
    required this.onSelectTimeAddon,
    required this.onToggleValueService,
    required this.onToggleCustomService,
    required this.onToggleCustomPet,
    required this.onDailyTimedServicesChanged,
  });

  /// 舊版整區展開參數仍由外層傳入，實際改為分類折疊。
  // ignore: unused_field
  final bool showAddons;
  final bool addonLoading;
  final Map<String, dynamic>? addonData;
  final List<String> selectedPetIds;
  final List<Map<String, dynamic>> pets;

  final Map<String, dynamic>? selectedTimeAddon;
  final List<Map<String, dynamic>> selectedValueServices;
  final Map<String, List<String>> selectedCustomServices;

  /// 入住日期
  final DateTime? startDate;

  /// 退房日期
  ///
  /// 每日服務不包含退房當天。
  final DateTime? endDate;

  /// 每日分時段服務選擇結果
  ///
  /// 結構：
  /// serviceId → petId → yyyy-MM-dd → 時段 ID 清單
  final Map<String, Map<String, Map<String, List<String>>>>
  selectedDailyTimedServices;

  final HomeThemeModel theme;
  final int addonTotal;

  /// 舊版整區展開回呼仍由外層傳入。
  // ignore: unused_field
  final VoidCallback onToggleShowAddons;
  final ValueChanged<Map<String, dynamic>> onSelectTimeAddon;
  final ValueChanged<Map<String, dynamic>> onToggleValueService;
  final ValueChanged<Map<String, dynamic>> onToggleCustomService;

  final void Function(String serviceName, String petId, bool selected)
  onToggleCustomPet;

  /// 每日分時段服務資料改變後，通知外層重新整理畫面。
  final VoidCallback onDailyTimedServicesChanged;

  /// 取得每日分時段服務的穩定識別 ID。
  ///
  /// 優先使用 Firestore 中的 id；
  /// 尚未有 id 時，暫時以服務名稱建立識別值。
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
  ///
  /// 相容目前專案可能使用 petId 或 id 的資料格式。
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

  /// 產生住宿期間的服務日期。
  ///
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

  /// 將日期轉成儲存用格式。
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
  ///
  /// 相容新版 Map 格式，也避免舊資料造成畫面錯誤。
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
    final bool addonEnabled = BookingAddonsHelper.parseBool(
      addonData?['enabled'],
    );

    final timeOptions = List<Map<String, dynamic>>.from(
      addonData?['timeOptions'] ?? [],
    );

    final valueServices = List<Map<String, dynamic>>.from(
      addonData?['valueServices'] ?? [],
    );

    final customServices = List<Map<String, dynamic>>.from(
      addonData?['customServices'] ?? [],
    );

    final dailyTimedServices = List<Map<String, dynamic>>.from(
      addonData?['dailyTimedServices'] ?? [],
    );
    final serviceDates = _buildServiceDates();
    final int selectedCount = BookingAddonsHelper.selectedItemCount(
      selectedTimeAddon: selectedTimeAddon,
      selectedValueServices: selectedValueServices,
      selectedCustomServices: selectedCustomServices,
      selectedDailyTimedServices: selectedDailyTimedServices,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '加值服務',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: theme.textColor,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '依分類展開選擇，不會一次展開全部表單。',
          style: TextStyle(
            fontSize: 12,
            color: theme.textColor.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 10),
        if (addonLoading) const Center(child: CircularProgressIndicator()),
        if (!addonLoading && addonData == null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              '目前尚未設定加值服務',
              style: TextStyle(
                fontSize: 14,
                color: theme.textColor.withValues(alpha: 0.7),
              ),
            ),
          ),
        if (!addonLoading && addonData != null) ...[
          if (!addonEnabled || timeOptions.isNotEmpty)
            _AddonCategoryCard(
              theme: theme,
              title: '入退房時間',
              selectedCount: selectedTimeAddon == null ? 0 : 1,
              children: <Widget>[
                if (!addonEnabled)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Text(
                      '目前未開放營業時間外入住',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                if (addonEnabled)
                  ...timeOptions.map((item) {
                    final label = item['label']?.toString() ?? '';
                    final isSelected =
                        selectedTimeAddon?['label'] == item['label'];
                    return GestureDetector(
                      onTap: () {
                        onSelectTimeAddon(item);
                      },
                      child: AddonItemCard(
                        item: {...item, 'name': label},
                        isSelected: isSelected,
                      ),
                    );
                  }),
              ],
            ),
          if (valueServices.isNotEmpty)
            _AddonCategoryCard(
              theme: theme,
              title: '加值服務',
              selectedCount: selectedValueServices.length,
              children: <Widget>[
                ...valueServices.map((item) {
                  final itemName = item['name']?.toString() ?? '';

                  final isSelected = selectedValueServices.any((selectedItem) {
                    return selectedItem['name'] == itemName;
                  });

                  return GestureDetector(
                    onTap: () {
                      onToggleValueService(item);
                    },
                    child: AddonItemCard(item: item, isSelected: isSelected),
                  );
                }),
              ],
            ),
          if (customServices.isNotEmpty)
            _AddonCategoryCard(
              theme: theme,
              title: '客製服務',
              selectedCount: selectedCustomServices.length,
              children: <Widget>[
                ...customServices.map((item) {
                  final serviceName = item['name']?.toString() ?? '';

                  if (serviceName.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final isSelected = selectedCustomServices.containsKey(
                    serviceName,
                  );

                  return GestureDetector(
                    onTap: () {
                      onToggleCustomService(item);
                    },
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AddonItemCard(item: item, isSelected: isSelected),

                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(left: 30, top: 6),
                            child: Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: selectedPetIds.map((petId) {
                                final pet = pets.firstWhere(
                                  (pet) {
                                    return _petId(pet) == petId;
                                  },
                                  orElse: () {
                                    return <String, dynamic>{};
                                  },
                                );

                                final petName = _petName(pet, petId);

                                final selectedList =
                                    selectedCustomServices[serviceName] ??
                                    <String>[];

                                final selected = selectedList.contains(petId);

                                return FilterChip(
                                  label: Text('🐱 $petName'),
                                  selected: selected,
                                  showCheckmark: false,
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
            ),
          if (dailyTimedServices.isNotEmpty)
            _AddonCategoryCard(
              theme: theme,
              title: '每日分時段服務',
              selectedCount: selectedDailyTimedServices.values.where((
                Map<String, Map<String, List<String>>> pets,
              ) {
                return pets.values.any((Map<String, List<String>> dates) {
                  return dates.values.any(
                    (List<String> slots) => slots.isNotEmpty,
                  );
                });
              }).length,
              children: <Widget>[
                Text(
                  '請先選擇需要服務的寵物，再依住宿期間每天選擇服務時段。',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.textColor.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 10),
                ...dailyTimedServices.asMap().entries.map((entry) {
                  final serviceIndex = entry.key;
                  final service = entry.value;

                  final serviceId = _dailyTimedServiceId(service, serviceIndex);

                  final serviceName = service['name']?.toString().trim() ?? '';

                  if (serviceName.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final serviceDesc = service['desc']?.toString().trim() ?? '';

                  final servicePrice = (service['price'] as num?)?.toInt() ?? 0;
                  final bool allowMultiplePetsPerSlot =
                      BookingAddonsHelper.parseBool(
                        service['allowMultiplePetsPerSlot'],
                        fallback: true,
                      );

                  final selectedServicePets =
                      selectedDailyTimedServices[serviceId] ??
                      <String, Map<String, List<String>>>{};

                  final availablePets = pets.where((pet) {
                    final petId = _petId(pet);

                    return petId.isNotEmpty && selectedPetIds.contains(petId);
                  }).toList();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 0,
                    color: Colors.white,
                    surfaceTintColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: Colors.grey.shade300),
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                              const SizedBox(width: 10),
                              Text(
                                '\$$servicePrice / 次',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),

                          if (serviceDesc.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              serviceDesc,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                          if (!allowMultiplePetsPerSlot) ...[
                            const SizedBox(height: 6),
                            Text(
                              '同一時段僅能選擇一隻寵物',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.textColor.withValues(alpha: 0.7),
                              ),
                            ),
                          ],

                          const Divider(height: 24),

                          const Text(
                            '選擇服務寵物',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),

                          const SizedBox(height: 6),

                          if (selectedPetIds.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                '請先在前面選擇入住寵物。',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange,
                                ),
                              ),
                            )
                          else if (availablePets.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: Text(
                                '找不到已選擇的寵物資料。',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.orange,
                                ),
                              ),
                            )
                          else
                            ...availablePets.map((pet) {
                              final petId = _petId(pet);
                              final petName = _petName(pet, petId);

                              final isSelected = selectedServicePets
                                  .containsKey(petId);

                              final timeSlots = _serviceTimeSlots(service);

                              final petDateSelections =
                                  selectedServicePets[petId] ??
                                  <String, List<String>>{};

                              return Container(
                                margin: const EdgeInsets.only(bottom: 10),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.grey.shade50,
                                  border: Border.all(
                                    color: isSelected
                                        ? Colors.blueGrey.shade300
                                        : Colors.grey.shade200,
                                    width: isSelected ? 1.2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  children: [
                                    CheckboxListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                          ),
                                      dense: true,
                                      controlAffinity:
                                          ListTileControlAffinity.leading,
                                      title: Text('🐱 $petName'),
                                      subtitle: isSelected
                                          ? const Text(
                                              '請選擇每天需要的服務時段',
                                              style: TextStyle(fontSize: 12),
                                            )
                                          : null,
                                      value: isSelected,
                                      onChanged: (value) {
                                        if (value == null || petId.isEmpty) {
                                          return;
                                        }

                                        if (value) {
                                          selectedDailyTimedServices
                                              .putIfAbsent(serviceId, () {
                                                return <
                                                  String,
                                                  Map<String, List<String>>
                                                >{};
                                              })
                                              .putIfAbsent(petId, () {
                                                return <String, List<String>>{};
                                              });
                                        } else {
                                          selectedDailyTimedServices[serviceId]
                                              ?.remove(petId);

                                          final serviceSelection =
                                              selectedDailyTimedServices[serviceId];

                                          if (serviceSelection == null ||
                                              serviceSelection.isEmpty) {
                                            selectedDailyTimedServices.remove(
                                              serviceId,
                                            );
                                          }
                                        }

                                        onDailyTimedServicesChanged();
                                      },
                                    ),

                                    if (isSelected)
                                      Padding(
                                        padding: const EdgeInsets.fromLTRB(
                                          12,
                                          0,
                                          12,
                                          12,
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (startDate == null ||
                                                endDate == null)
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 8,
                                                ),
                                                child: Text(
                                                  '請先選擇入住與退房日期。',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.orange,
                                                  ),
                                                ),
                                              )
                                            else if (serviceDates.isEmpty)
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 8,
                                                ),
                                                child: Text(
                                                  '目前沒有可設定的住宿日期。',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.orange,
                                                  ),
                                                ),
                                              )
                                            else if (timeSlots.isEmpty)
                                              const Padding(
                                                padding: EdgeInsets.symmetric(
                                                  vertical: 8,
                                                ),
                                                child: Text(
                                                  '店家尚未設定此服務的可選時段。',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.orange,
                                                  ),
                                                ),
                                              )
                                            else
                                              ...serviceDates.map((date) {
                                                final dateKey = _dateKey(date);

                                                final selectedSlotIds =
                                                    petDateSelections[dateKey] ??
                                                    <String>[];

                                                return Container(
                                                  width: double.infinity,
                                                  margin: const EdgeInsets.only(
                                                    top: 8,
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    10,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.grey.shade50,
                                                    border: Border.all(
                                                      color:
                                                          Colors.grey.shade200,
                                                    ),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        _dateLabel(date),
                                                        style: const TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 8),
                                                      Wrap(
                                                        spacing: 8,
                                                        runSpacing: 8,
                                                        children: timeSlots.map((
                                                          slot,
                                                        ) {
                                                          final slotId =
                                                              slot['id']
                                                                  ?.toString() ??
                                                              '';

                                                          final slotLabel =
                                                              slot['label']
                                                                  ?.toString() ??
                                                              '';

                                                          final selected =
                                                              selectedSlotIds
                                                                  .contains(
                                                                    slotId,
                                                                  );

                                                          return FilterChip(
                                                            label: Text(
                                                              slotLabel,
                                                              style: TextStyle(
                                                                fontSize: 13,
                                                                fontWeight:
                                                                    selected
                                                                    ? FontWeight
                                                                          .w600
                                                                    : FontWeight
                                                                          .normal,
                                                              ),
                                                            ),
                                                            selected: selected,
                                                            showCheckmark:
                                                                false,
                                                            visualDensity:
                                                                VisualDensity
                                                                    .compact,
                                                            materialTapTargetSize:
                                                                MaterialTapTargetSize
                                                                    .shrinkWrap,
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal: 8,
                                                                  vertical: 6,
                                                                ),
                                                            backgroundColor:
                                                                Colors.white,
                                                            selectedColor:
                                                                Colors
                                                                    .blueGrey
                                                                    .shade100,
                                                            side: BorderSide(
                                                              color: selected
                                                                  ? Colors
                                                                        .blueGrey
                                                                        .shade400
                                                                  : Colors
                                                                        .grey
                                                                        .shade300,
                                                            ),
                                                            shape: RoundedRectangleBorder(
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    8,
                                                                  ),
                                                            ),
                                                            onSelected: (value) {
                                                              final serviceSelections =
                                                                  selectedDailyTimedServices.putIfAbsent(
                                                                    serviceId,
                                                                    () {
                                                                      return <
                                                                        String,
                                                                        Map<
                                                                          String,
                                                                          List<
                                                                            String
                                                                          >
                                                                        >
                                                                      >{};
                                                                    },
                                                                  );

                                                              final petSelections =
                                                                  serviceSelections.putIfAbsent(
                                                                    petId,
                                                                    () {
                                                                      return <
                                                                        String,
                                                                        List<
                                                                          String
                                                                        >
                                                                      >{};
                                                                    },
                                                                  );

                                                              final dateSelections =
                                                                  petSelections
                                                                      .putIfAbsent(
                                                                        dateKey,
                                                                        () {
                                                                          return <
                                                                            String
                                                                          >[];
                                                                        },
                                                                      );

                                                              if (value) {
                                                                if (!dateSelections
                                                                    .contains(
                                                                      slotId,
                                                                    )) {
                                                                  dateSelections
                                                                      .add(
                                                                        slotId,
                                                                      );
                                                                }
                                                              } else {
                                                                dateSelections
                                                                    .remove(
                                                                      slotId,
                                                                    );

                                                                if (dateSelections
                                                                    .isEmpty) {
                                                                  petSelections
                                                                      .remove(
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
                                              }),
                                          ],
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
            ),
        ],
        const SizedBox(height: 4),
        BookingThemedCard(
          theme: theme,
          margin: EdgeInsets.zero,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '已選 $selectedCount 項加值服務',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
              ),
              Text(
                '加購 ${ShopReportFormat.money(addonTotal)}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AddonCategoryCard extends StatelessWidget {
  const _AddonCategoryCard({
    required this.theme,
    required this.title,
    required this.children,
    this.selectedCount = 0,
  });

  final HomeThemeModel theme;
  final String title;
  final int selectedCount;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selectedCount > 0
              ? const Color(0xFF2E8B47)
              : theme.cardBorderColor,
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: selectedCount > 0,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
          title: Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: theme.textColor,
                  ),
                ),
              ),
              if (selectedCount > 0)
                Text(
                  '已選 $selectedCount',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E8B47),
                  ),
                ),
            ],
          ),
          children: children,
        ),
      ),
    );
  }
}
