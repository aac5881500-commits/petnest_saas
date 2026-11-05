import 'booking_editorial_design.dart';
import 'booking_appearance_scope.dart';
import 'booking_service_templates.dart';
// 檔案名稱：lib/features/shop/widgets/booking/booking_addon_section.dart
// 功能說明：顯示營業時間外入住、一般加值服務、客製化服務、每日分時段服務
// 🔥 前台預約加值服務區塊
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

  /// 舊版整區展開參數仍由外層傳入，各分類內容預設完整顯示。
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

  Widget _editorial(BuildContext context) {
    final cream = BookingAppearanceScope.of(context).style == 'cream';
    List<Map<String, dynamic>> items(String key) =>
        List<Map<String, dynamic>>.from(addonData?[key] ?? []);
    Widget row(
      String name,
      String desc,
      String price, {
      bool? selected,
      VoidCallback? toggle,
      Widget? controls,
    }) => Container(
      margin: cream ? const EdgeInsets.only(bottom: 12) : EdgeInsets.zero,
      padding: cream
          ? const EdgeInsets.all(15)
          : const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: cream ? BookingEditorial.theme(context).cardColor : null,
        borderRadius: cream ? BorderRadius.circular(24) : null,
        border: cream
            ? Border.all(color: BookingEditorial.theme(context).cardBorderColor)
            : Border(
                bottom: BorderSide(
                  color: BookingEditorial.theme(context).cardBorderColor,
                ),
              ),
      ),
      child: GestureDetector(
        onTap: toggle,
        behavior: HitTestBehavior.opaque,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 30,
              child: selected == null
                  ? Icon(
                      Icons.radio_button_checked,
                      color: BookingEditorial.theme(context).primaryColor,
                      size: 24,
                    )
                  : SizedBox(
                      height: 27,
                      child: Checkbox(
                        value: selected,
                        onChanged: toggle == null ? null : (_) => toggle(),
                        activeColor: BookingEditorial.theme(
                          context,
                        ).primaryColor,
                        side: BorderSide(
                          color: BookingEditorial.theme(context).primaryColor,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(name, style: BookingEditorial.title(19, context)),
                      Text(price, style: BookingEditorial.body(14, context)),
                    ],
                  ),
                  if (desc.isNotEmpty)
                    Text(desc, style: BookingEditorial.body(14, context)),
                  if (controls != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 9),
                      child: controls,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    final available = pets
        .where((p) => selectedPetIds.contains(_petId(p)))
        .toList();
    Widget chip(String label, bool selected, ValueChanged<bool> change) =>
        FilterChip(
          label: Text(label, style: BookingEditorial.body(14, context)),
          selected: selected,
          onSelected: change,
          selectedColor: BookingEditorial.tint(context),
          backgroundColor: BookingEditorial.theme(context).backgroundColor,
          checkmarkColor: BookingEditorial.theme(context).primaryColor,
          side: BorderSide(
            color: BookingEditorial.theme(context).cardBorderColor,
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        );
    final times = items('timeOptions');
    final selectedIndex = times.indexWhere(
      (v) => v['label'] == selectedTimeAddon?['label'],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(
          color: BookingEditorial.theme(context).cardBorderColor,
          height: 26,
        ),
        BookingEditorial.heading('加購服務', subtitle: '加購選填，讓住宿體驗更完整。'),
        if (addonLoading) const LinearProgressIndicator(),
        if (!addonLoading && addonData == null)
          Text('目前尚未設定加購服務', style: BookingEditorial.body(15, context)),
        if (BookingAddonsHelper.parseBool(addonData?['enabled']) &&
            times.isNotEmpty)
          row(
            '入退房時間',
            '選擇入住與退房方式。',
            'NT\$ ${selectedTimeAddon?['price'] ?? 0}／筆',
            controls: DropdownButtonFormField<int>(
              key: const ValueKey('editorial-time-choice'),
              initialValue: selectedIndex < 0 ? null : selectedIndex,
              isExpanded: true,
              style: BookingEditorial.body(15, context),
              dropdownColor: BookingEditorial.theme(context).backgroundColor,
              decoration: InputDecoration(
                hintText: '選擇時間方案',
                filled: true,
                fillColor: BookingEditorial.tint(context),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(9),
                  borderSide: BorderSide.none,
                ),
              ),
              items: [
                for (var i = 0; i < times.length; i++)
                  DropdownMenuItem(
                    value: i,
                    child: Text('${times[i]['label']}'),
                  ),
              ],
              onChanged: (i) {
                if (i != null) onSelectTimeAddon(times[i]);
              },
            ),
          ),
        for (final v in items('valueServices'))
          row(
            '${v['name']}',
            v['desc']?.toString() ?? '整筆預約收一次。',
            'NT\$ ${v['price']}／筆',
            selected: selectedValueServices.any((x) => x['name'] == v['name']),
            toggle: () => onToggleValueService(v),
          ),
        for (final v in items('customServices'))
          row(
            '${v['name']}',
            v['desc']?.toString() ?? '依每隻貓咪需求安排照護。',
            'NT\$ ${v['price']}／隻',
            selected: selectedCustomServices.containsKey(v['name']),
            toggle: () => onToggleCustomService(v),
            controls: Wrap(
              spacing: 8,
              runSpacing: 5,
              children: [
                for (final pet in available)
                  chip(
                    _petName(pet, _petId(pet)),
                    selectedCustomServices[v['name']]?.contains(_petId(pet)) ??
                        false,
                    (value) => onToggleCustomPet(
                      v['name'].toString(),
                      _petId(pet),
                      value,
                    ),
                  ),
              ],
            ),
          ),
        for (final entry in items('dailyTimedServices').asMap().entries)
          Builder(
            builder: (context) {
              final v = entry.value,
                  id = _dailyTimedServiceId(v, entry.key),
                  selection = selectedDailyTimedServices[id] ?? {};
              final slots = _serviceTimeSlots(v);
              return row(
                '${v['name']}',
                '先選貓咪，再選日期與時段；每隻分開安排。',
                'NT\$ ${v['price']}／時段',
                selected: selection.isNotEmpty,
                toggle: () {
                  if (selection.isNotEmpty) {
                    selectedDailyTimedServices.remove(id);
                  } else if (available.isNotEmpty) {
                    selectedDailyTimedServices[id] = {
                      _petId(available.first): {},
                    };
                  }
                  onDailyTimedServicesChanged();
                },
                controls: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 5,
                      children: [
                        for (final p in available)
                          chip(
                            _petName(p, _petId(p)),
                            selection.containsKey(_petId(p)),
                            (value) {
                              if (value) {
                                selectedDailyTimedServices
                                    .putIfAbsent(id, () => {})
                                    .putIfAbsent(_petId(p), () => {});
                              } else {
                                selectedDailyTimedServices[id]?.remove(
                                  _petId(p),
                                );
                                if (selectedDailyTimedServices[id]?.isEmpty ??
                                    false) {
                                  selectedDailyTimedServices.remove(id);
                                }
                              }
                              onDailyTimedServicesChanged();
                            },
                          ),
                      ],
                    ),
                    if (available.isEmpty)
                      Text(
                        '請先選擇入住貓咪。',
                        style: BookingEditorial.body(14, context),
                      ),
                    if (slots.isEmpty)
                      Text(
                        '店家尚未設定可選時段。',
                        style: BookingEditorial.body(14, context),
                      ),
                    for (final p in available.where(
                      (p) => selection.containsKey(_petId(p)),
                    )) ...[
                      if (selection.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            _petName(p, _petId(p)),
                            style: BookingEditorial.title(13, context),
                          ),
                        ),
                      if (_buildServiceDates().isEmpty)
                        Text(
                          '請先選擇入住與退房日期。',
                          style: BookingEditorial.body(14, context),
                        ),
                      for (final date in _buildServiceDates())
                        Padding(
                          padding: const EdgeInsets.only(top: 7),
                          child: Wrap(
                            spacing: 7,
                            runSpacing: 5,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: BookingEditorial.tint(context),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${date.month}/${date.day}',
                                  style: BookingEditorial.body(14, context),
                                ),
                              ),
                              for (final slot in slots)
                                chip(
                                  slot['label'].toString(),
                                  selection[_petId(p)]?[_dateKey(date)]
                                          ?.contains(slot['id']) ??
                                      false,
                                  (value) {
                                    final days = selectedDailyTimedServices
                                            .putIfAbsent(id, () => {})
                                            .putIfAbsent(_petId(p), () => {}),
                                        list = days.putIfAbsent(
                                          _dateKey(date),
                                          () => [],
                                        );
                                    if (value) {
                                      if (!list.contains(slot['id'])) {
                                        list.add(slot['id'].toString());
                                      }
                                    } else {
                                      list.remove(slot['id']);
                                      if (list.isEmpty) {
                                        days.remove(_dateKey(date));
                                      }
                                    }
                                    onDailyTimedServicesChanged();
                                  },
                                ),
                            ],
                          ),
                        ),
                    ],
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (BookingAppearanceScope.of(context).serviceStyle == 'editorial' ||
        BookingAppearanceScope.of(context).style == 'cream') {
      return _editorial(context);
    }
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
        if (BookingAppearanceScope.of(context).serviceStyle != 'original')
          BookingServiceTemplates.header(
            BookingAppearanceScope.of(context).serviceStyle,
            theme,
            '客製你的住宿體驗',
            '加購選填，依需求搭配服務',
            '02',
          ),
        if (BookingAppearanceScope.of(context).serviceStyle == 'original') ...[
          Text(
            '加購服務（選填）',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: theme.textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '依需要勾選即可，不加購也能繼續。各項計費方式不同，請參考分類說明。',
            style: TextStyle(
              fontSize: 12,
              color: theme.textColor.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 10),
        ],
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
              description: '單選一個時間方案，按所選方案計費。請依預計抵達或接回時間選擇。',
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
                        singleChoice: true,
                        priceUnit: '每筆預約',
                        accentColor: theme.primaryColor,
                      ),
                    );
                  }),
              ],
            ),
          if (valueServices.isNotEmpty)
            _AddonCategoryCard(
              theme: theme,
              title: '加值服務',
              description: '可複選；每項按整筆預約收費一次，不乘貓咪數與住宿晚數。',
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
                    child: AddonItemCard(
                      item: item,
                      isSelected: isSelected,
                      priceUnit: '每筆預約一次',
                      accentColor: theme.primaryColor,
                    ),
                  );
                }),
              ],
            ),
          if (customServices.isNotEmpty)
            _AddonCategoryCard(
              theme: theme,
              title: '客製服務',
              description: '先勾選服務，再選需要服務的貓咪；每隻收費一次，不乘住宿天數。',
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
                        AddonItemCard(
                          item: item,
                          isSelected: isSelected,
                          priceUnit: '每隻貓咪一次',
                          accentColor: theme.primaryColor,
                        ),

                        if (isSelected)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14, top: 4),
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
                                  selectedColor: theme.primaryColor.withValues(
                                    alpha: .12,
                                  ),
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
              description: '先選貓咪，再選每天的時段；每隻 × 日期 × 時段計費，服務日期不含退房日。',
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
                  '① 選擇貓咪　→　② 勾選日期下的時段。只計算實際勾選的時段。',
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
                          Text(
                            serviceName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'NT\$ $servicePrice',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                  color: theme.primaryColor,
                                ),
                              ),
                              const Text(
                                '每隻／每個日期時段',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF596574),
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
                                color: Color(0xFF596574),
                                height: 1.5,
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
                            '① 選擇服務貓咪',
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
                                        ? theme.primaryColor
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
                                              '② 在下方選擇日期與服務時段',
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
                                                            selectedColor: theme
                                                                .primaryColor
                                                                .withValues(
                                                                  alpha: .12,
                                                                ),
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

                                                            side: BorderSide(
                                                              color: selected
                                                                  ? theme
                                                                        .primaryColor
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
          child: Wrap(
            spacing: 16,
            runSpacing: 8,
            alignment: WrapAlignment.spaceBetween,
            children: <Widget>[
              Text(
                '已選 $selectedCount 項加值服務',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: theme.textColor,
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
    required this.description,
    this.selectedCount = 0,
  });
  final HomeThemeModel theme;
  final String title, description;
  final int selectedCount;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final style = BookingAppearanceScope.of(context).serviceStyle;
    return Container(
      key: ValueKey('booking-addon-category-$title'),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: style == 'editorial' ? Colors.transparent : theme.cardColor,
        borderRadius: BorderRadius.circular(style == 'premium' ? 6 : 16),
        border: style == 'editorial'
            ? Border(bottom: BorderSide(color: theme.cardBorderColor))
            : style == 'journal'
            ? Border(
                left: BorderSide(
                  color: theme.primaryColor.withValues(alpha: .4),
                  width: 3,
                ),
              )
            : Border.all(
                color: selectedCount > 0
                    ? theme.primaryColor
                    : theme.cardBorderColor,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 6,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: theme.textColor,
                ),
              ),
              if (selectedCount > 0)
                Text(
                  '已選 $selectedCount',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: theme.primaryColor,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              height: 1.5,
              color: theme.textColor.withValues(alpha: .8),
            ),
          ),
          const SizedBox(height: 14),
          if (style == 'premium' &&
              (title == '入退房時間' || title == '加值服務') &&
              children.length > 1)
            LayoutBuilder(
              builder: (context, constraints) {
                final columns =
                    constraints.maxWidth >= 420 &&
                        MediaQuery.textScalerOf(context).scale(14) <= 21
                    ? 2
                    : 1;
                return Wrap(
                  spacing: 10,
                  runSpacing: 4,
                  children: [
                    for (final child in children)
                      SizedBox(
                        width:
                            (constraints.maxWidth - (columns - 1) * 10) /
                            columns,
                        child: child,
                      ),
                  ],
                );
              },
            )
          else
            ...children,
        ],
      ),
    );
  }
}
