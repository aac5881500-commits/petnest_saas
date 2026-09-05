// 檔案名稱：lib/features/shop/pages/shop_daycare_date_override_page.dart
// 功能說明：安親可預約日期：預設開放，僅逐日關閉／恢復

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/daycare_date_override_model.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/daycare_date_availability.dart';
import 'package:petnest_saas/core/services/daycare_date_override_service.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/services/daycare_time_helper.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/shared/widgets/booking_calendar.dart';

class ShopDaycareDateOverridePage extends StatefulWidget {
  const ShopDaycareDateOverridePage({
    super.key,
    required this.shopId,
    required this.settings,
  });

  final String shopId;
  final DaycareSettingsModel settings;

  @override
  State<ShopDaycareDateOverridePage> createState() =>
      _ShopDaycareDateOverridePageState();
}

class _ShopDaycareDateOverridePageState
    extends State<ShopDaycareDateOverridePage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  DateTime get _today {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _firstDate => DateTime(_today.year, _today.month, 1);

  DateTime get _lastDate => _today.add(const Duration(days: 366));

  DaycareDateOverrideModel? _find(
    List<DaycareDateOverrideModel> list,
    DateTime day,
  ) {
    final String id = DaycareTimeHelper.overrideDocId(day);
    for (final DaycareDateOverrideModel item in list) {
      if (item.id == id) {
        return item;
      }
    }
    return null;
  }

  Future<void> _editDay(
    DateTime day,
    DaycareDateOverrideModel? existing,
  ) async {
    final bool currentlyOpen = DaycareDateAvailability.isDateOpen(
      settings: widget.settings,
      date: day,
      override: existing,
    );
    bool isOpen = currentlyOpen;
    final TextEditingController note = TextEditingController(
      text: existing?.note ?? '',
    );
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      DaycareTimeHelper.dateKey(day),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioListTile<bool>(
                      title: const Text('正常可預約'),
                      value: true,
                      groupValue: isOpen,
                      onChanged: (bool? value) {
                        setDialogState(() => isOpen = value ?? true);
                      },
                    ),
                    RadioListTile<bool>(
                      title: const Text('關閉／店休'),
                      value: false,
                      groupValue: isOpen,
                      onChanged: (bool? value) {
                        setDialogState(() => isOpen = value ?? false);
                      },
                    ),
                    TextField(
                      controller: note,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '店主備註（客戶看不到）',
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: <Widget>[
                        const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(context, false),
                          child: const Text('取消'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: const Text('儲存'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (saved != true) {
      note.dispose();
      return;
    }
    if (isOpen) {
      await DaycareDateOverrideService.instance.delete(
        shopId: widget.shopId,
        date: day,
      );
      note.dispose();
      return;
    }
    await DaycareDateOverrideService.instance.save(
      shopId: widget.shopId,
      override: DaycareDateOverrideModel(
        id: DaycareTimeHelper.overrideDocId(day),
        date: DaycareTimeHelper.dateKey(day),
        isOpen: false,
        note: note.text.trim(),
        maxPets: existing?.maxPets ?? 0,
        openTime: existing?.openTime ?? '',
        closeTime: existing?.closeTime ?? '',
        latestDropoffTime: existing?.latestDropoffTime ?? '',
        latestPickupTime: existing?.latestPickupTime ?? '',
      ),
    );
    note.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DateTime monthStart = DateTime(_month.year, _month.month, 1);
    final DateTime monthEnd = DateTime(_month.year, _month.month + 1, 0);
    return Scaffold(
      appBar: AppBar(title: const Text('管理可預約日期')),
      body: StreamBuilder<List<DaycareDateOverrideModel>>(
        stream: DaycareDateOverrideService.instance.streamRange(
          shopId: widget.shopId,
          start: monthStart,
          end: monthEnd,
        ),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<List<DaycareDateOverrideModel>> snapshot,
            ) {
              final List<DaycareDateOverrideModel> overrides =
                  snapshot.data ?? const <DaycareDateOverrideModel>[];
              return FutureBuilder<Map<String, int>>(
                future: DaycareOccupancyService.instance.usedPetsByDate(
                  shopId: widget.shopId,
                  start: monthStart,
                  end: monthEnd,
                ),
                builder:
                    (
                      BuildContext context,
                      AsyncSnapshot<Map<String, int>> usedSnap,
                    ) {
                      final Map<String, int> used =
                          usedSnap.data ?? const <String, int>{};
                      final Set<String> blocked = <String>{};
                      final Set<String> full = <String>{};
                      final int dailyMax = DaycareDateAvailability.dailyMaxPets(
                        settings: widget.settings,
                      );
                      DateTime cursor = monthStart;
                      while (!cursor.isAfter(monthEnd)) {
                        final String key = ShopService.instance.formatDateKey(
                          cursor,
                        );
                        final DaycareDateOverrideModel? override = _find(
                          overrides,
                          cursor,
                        );
                        final bool open = DaycareDateAvailability.isDateOpen(
                          settings: widget.settings,
                          date: cursor,
                          override: override,
                        );
                        if (!open) {
                          blocked.add(key);
                        } else if (dailyMax > 0) {
                          final int left = (dailyMax - (used[key] ?? 0)).clamp(
                            0,
                            dailyMax,
                          );
                          if (left <= 0) {
                            full.add(key);
                          }
                        }
                        cursor = cursor.add(const Duration(days: 1));
                      }
                      return ListView(
                        padding: const EdgeInsets.all(16),
                        children: <Widget>[
                          const Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              _Legend(color: Colors.white, label: '可預約'),
                              _Legend(color: Color(0xFFEEEEEE), label: '店休'),
                              _Legend(color: Color(0xFFFFF3E0), label: '額滿'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          BookingCalendar(
                            allowBlockedTap: true,
                            compactCells: true,
                            initialMonth: _month,
                            firstDate: _firstDate,
                            lastDate: _lastDate,
                            blockedDateKeys: blocked,
                            unbookableDateKeys: full,
                            onMonthChanged: (DateTime month) {
                              setState(() => _month = month);
                            },
                            onDayTap: (DateTime date) {
                              _editDay(date, _find(overrides, date));
                            },
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '所有日期預設可預約。點選日期可改為店休，或刪除例外恢復正常。額滿由訂單自動計算，無法手動設定。',
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                        ],
                      );
                    },
              );
            },
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: Colors.grey.shade400),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
