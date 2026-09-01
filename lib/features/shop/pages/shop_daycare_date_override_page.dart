// lib/features/shop/pages/shop_daycare_date_override_page.dart
// 🐾 臨托日期開放管理：單日／批次開放或關閉

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
  DateTime? _rangeStart;
  DateTime? _rangeEnd;
  bool _batchMode = false;
  bool _saving = false;

  DateTime get _today {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  DateTime get _firstDate => DateTime(_today.year, _today.month, 1);

  DateTime get _lastDate => _today.add(const Duration(days: 366));

  Future<void> _onDayTap(DateTime date, List<DaycareDateOverrideModel> list) {
    final DateTime day = DateTime(date.year, date.month, date.day);
    if (_batchMode) {
      setState(() {
        if (_rangeStart == null || (_rangeStart != null && _rangeEnd != null)) {
          _rangeStart = day;
          _rangeEnd = null;
        } else if (day.isBefore(_rangeStart!)) {
          _rangeEnd = _rangeStart;
          _rangeStart = day;
        } else {
          _rangeEnd = day;
        }
      });
      return Future<void>.value();
    }
    final DaycareDateOverrideModel? existing = _find(list, day);
    return _editDay(day, existing);
  }

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
    final bool weekdayOpen = widget.settings.weekdays.contains(
      DaycareTimeHelper.weekdayTaiwan(day),
    );
    bool isOpen = existing?.isOpen ?? weekdayOpen;
    final TextEditingController maxPets = TextEditingController(
      text: existing != null && existing.maxPets > 0
          ? '${existing.maxPets}'
          : '',
    );
    final TextEditingController openTime = TextEditingController(
      text: existing?.openTime ?? '',
    );
    final TextEditingController closeTime = TextEditingController(
      text: existing?.closeTime ?? '',
    );
    final TextEditingController latestDropoff = TextEditingController(
      text: existing?.latestDropoffTime ?? '',
    );
    final TextEditingController latestPickup = TextEditingController(
      text: existing?.latestPickupTime ?? '',
    );
    final TextEditingController note = TextEditingController(
      text: existing?.note ?? '',
    );
    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setDialogState) {
            return AlertDialog(
              title: Text(DaycareTimeHelper.dateKey(day)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('開放臨托'),
                      subtitle: Text(weekdayOpen ? '平日規則：開放' : '平日規則：不開放'),
                      value: isOpen,
                      onChanged: (bool value) {
                        setDialogState(() => isOpen = value);
                      },
                    ),
                    TextField(
                      controller: maxPets,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '當日最大接待寵物數',
                        hintText: '留空沿用平日名額',
                      ),
                    ),
                    TextField(
                      controller: openTime,
                      decoration: const InputDecoration(
                        labelText: '開放時間',
                        hintText: '例如 09:00，留空沿用平日',
                      ),
                    ),
                    TextField(
                      controller: closeTime,
                      decoration: const InputDecoration(
                        labelText: '結束時間',
                        hintText: '例如 18:00，留空沿用平日',
                      ),
                    ),
                    TextField(
                      controller: latestDropoff,
                      decoration: const InputDecoration(
                        labelText: '最晚送達',
                        hintText: '留空沿用平日',
                      ),
                    ),
                    TextField(
                      controller: latestPickup,
                      decoration: const InputDecoration(
                        labelText: '最晚接回',
                        hintText: '留空沿用平日',
                      ),
                    ),
                    TextField(
                      controller: note,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: '店主備註（客戶看不到）',
                        hintText: '例如：中秋節僅收熟客、店休、已額滿',
                      ),
                    ),
                  ],
                ),
              ),
              actions: <Widget>[
                if (existing != null)
                  TextButton(
                    onPressed: () async {
                      await DaycareDateOverrideService.instance.delete(
                        shopId: widget.shopId,
                        date: day,
                      );
                      if (context.mounted) {
                        Navigator.pop(context, true);
                      }
                    },
                    child: const Text('恢復平日規則'),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );
    if (saved != true) {
      maxPets.dispose();
      openTime.dispose();
      closeTime.dispose();
      latestDropoff.dispose();
      latestPickup.dispose();
      note.dispose();
      return;
    }
    await DaycareDateOverrideService.instance.save(
      shopId: widget.shopId,
      override: DaycareDateOverrideModel(
        id: DaycareTimeHelper.overrideDocId(day),
        date: DaycareTimeHelper.dateKey(day),
        isOpen: isOpen,
        maxPets: int.tryParse(maxPets.text.trim()) ?? 0,
        openTime: openTime.text.trim(),
        closeTime: closeTime.text.trim(),
        latestDropoffTime: latestDropoff.text.trim(),
        latestPickupTime: latestPickup.text.trim(),
        note: note.text.trim(),
      ),
    );
    maxPets.dispose();
    openTime.dispose();
    closeTime.dispose();
    latestDropoff.dispose();
    latestPickup.dispose();
    note.dispose();
  }

  List<DateTime> _selectedDates() {
    if (_rangeStart == null) {
      return const <DateTime>[];
    }
    final DateTime end = _rangeEnd ?? _rangeStart!;
    final List<DateTime> dates = <DateTime>[];
    DateTime cursor = _rangeStart!;
    while (!cursor.isAfter(end)) {
      dates.add(cursor);
      cursor = cursor.add(const Duration(days: 1));
    }
    return dates;
  }

  Future<void> _batchSet(bool isOpen) async {
    final List<DateTime> dates = _selectedDates();
    if (dates.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('請先點選日期範圍')));
      return;
    }
    setState(() => _saving = true);
    try {
      await DaycareDateOverrideService.instance.saveMany(
        shopId: widget.shopId,
        dates: dates,
        isOpen: isOpen,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _rangeStart = null;
        _rangeEnd = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isOpen ? '已批次開放所選日期' : '已批次關閉所選日期')),
      );
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
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
                      final Set<String> specialOpen = <String>{};
                      final Set<String> full = <String>{};
                      final Map<String, String> reasons = <String, String>{};
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
                        if (override != null && override.isOpen) {
                          specialOpen.add(key);
                        } else if (override != null && !override.isOpen) {
                          blocked.add(key);
                          reasons[key] = override.note.isEmpty
                              ? '關閉'
                              : override.note;
                        } else if (!open) {
                          blocked.add(key);
                          reasons[key] = '未開放';
                        }
                        if (open) {
                          final int maxPets =
                              DaycareDateAvailability.dailyMaxPets(
                                settings: widget.settings,
                                override: override,
                              );
                          final int left = (maxPets - (used[key] ?? 0)).clamp(
                            0,
                            maxPets,
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
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('批次選擇日期範圍'),
                            subtitle: const Text('開啟後可點選起迄日，再批次開放或關閉'),
                            value: _batchMode,
                            onChanged: (bool value) {
                              setState(() {
                                _batchMode = value;
                                _rangeStart = null;
                                _rangeEnd = null;
                              });
                            },
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: const <Widget>[
                              _Legend(color: Colors.white, label: '依每週規則開放'),
                              _Legend(color: Color(0xFFE8F5E9), label: '特別開放'),
                              _Legend(
                                color: Color(0xFFEEEEEE),
                                label: '特別關閉／店休',
                              ),
                              _Legend(color: Color(0xFFFFF3E0), label: '已滿額'),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 420,
                            child: BookingCalendar(
                              allowBlockedTap: true,
                              initialMonth: _month,
                              firstDate: _firstDate,
                              lastDate: _lastDate,
                              rangeStart: _rangeStart,
                              rangeEnd: _rangeEnd ?? _rangeStart,
                              blockedDateKeys: blocked,
                              blockedDateReasons: reasons,
                              unbookableDateKeys: full,
                              specialOpenDateKeys: specialOpen,
                              onMonthChanged: (DateTime month) {
                                setState(() => _month = month);
                              },
                              onDayTap: (DateTime date) {
                                _onDayTap(date, overrides);
                              },
                            ),
                          ),
                          if (_batchMode) ...<Widget>[
                            const SizedBox(height: 12),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: _saving
                                        ? null
                                        : () => _batchSet(false),
                                    child: const Text('批次關閉日期'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: _saving
                                        ? null
                                        : () => _batchSet(true),
                                    child: const Text('批次開放日期'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          const SizedBox(height: 12),
                          const Text(
                            '店主備註只給內部看，客戶端不會顯示。沒有例外設定的日期會繼續依可預約星期判斷。',
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
