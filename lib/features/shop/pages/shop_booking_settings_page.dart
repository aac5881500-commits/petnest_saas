// 檔案名稱：lib/features/shop/pages/shop_booking_settings_page.dart
// 功能說明：預約管理頁（店家後台）
// 功能：
// - 預約設定區
// - 共用月曆顯示
// - 點日期可關閉 / 開放

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/action_log_service.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/shared/widgets/booking_calendar.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/services/shop_plan_service.dart';
import 'package:petnest_saas/core/services/operator_display.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/shop/widgets/unsaved_booking_settings_dialog.dart';

class ShopBookingSettingsPage extends StatefulWidget {
  const ShopBookingSettingsPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<ShopBookingSettingsPage> createState() =>
      _ShopBookingSettingsPageState();
}

class _ShopBookingSettingsPageState extends State<ShopBookingSettingsPage> {
  final _maxAdvanceBookingDaysController = TextEditingController();

  bool _bookingEnabled = true;
  bool _daycareEnabled = false;
  bool _settingsInitialized = false;
  bool _savingSettings = false;
  Set<String> _draftBlockedDates = <String>{};
  Set<String> _savedBlockedDates = <String>{};
  bool _savedBookingEnabled = true;
  bool _savedDaycareEnabled = false;
  String _savedMaxAdvanceDays = '30';

  String? _currentUserRole;
  bool _roleLoaded = false;
  Map<String, dynamic>? _memberData;

  DateTime? _selectedCalendarDate;

  @override
  void initState() {
    super.initState();
    _loadRole();
  }

  @override
  void dispose() {
    _maxAdvanceBookingDaysController.dispose();
    super.dispose();
  }

  bool get _dirty {
    if (!_settingsInitialized) {
      return false;
    }
    final String days = _maxAdvanceBookingDaysController.text.trim();
    return _bookingEnabled != _savedBookingEnabled ||
        _daycareEnabled != _savedDaycareEnabled ||
        days != _savedMaxAdvanceDays ||
        !_sameSet(_draftBlockedDates, _savedBlockedDates);
  }

  bool _sameSet(Set<String> a, Set<String> b) {
    if (a.length != b.length) {
      return false;
    }
    return a.containsAll(b);
  }

  Future<bool> _handleLeave() async {
    if (!_dirty) {
      return true;
    }
    final UnsavedBookingSettingsAction? action =
        await showUnsavedBookingSettingsDialog(context);
    if (action == UnsavedBookingSettingsAction.discard) {
      return true;
    }
    if (action == UnsavedBookingSettingsAction.saveAndLeave) {
      return _saveSettings();
    }
    return false;
  }

  Future<void> _loadRole() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _currentUserRole = null;
        _roleLoaded = true;
      });
      return;
    }

    try {
      final memberData = await ShopService.instance.getUserMemberInShop(
        shopId: widget.shopId,
        uid: user.uid,
      );

      final role = memberData?['role']?.toString();

      if (!mounted) return;
      setState(() {
        _currentUserRole = role;
        _memberData = memberData;
        _roleLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentUserRole = null;
        _roleLoaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_roleLoaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_currentUserRole == null) {
      return const Scaffold(body: Center(child: Text('查無店家權限')));
    }

    final canManageBookings = ShopService.instance.hasPermission(
      _memberData,
      ShopPermissionKeys.manageBookingSettings,
    );

    if (!canManageBookings) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('權限限制'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
          ),
        ),
        body: const Center(child: Text('你沒有管理權限')),
      );
    }
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        final bool leave = await _handleLeave();
        if (leave && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('預約管理'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              final bool leave = await _handleLeave();
              if (leave && mounted) {
                Navigator.of(context).maybePop();
              }
            },
          ),
          actions: <Widget>[ShopTaskCenterButton(shopId: widget.shopId)],
        ),
        body: StreamBuilder<Map<String, dynamic>?>(
          stream: ShopService.instance.streamShop(widget.shopId),
          builder: (context, shopSnapshot) {
            if (shopSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (shopSnapshot.hasError) {
              return Center(child: Text('店家資料載入失敗：${shopSnapshot.error}'));
            }

            final shop = shopSnapshot.data;
            if (shop == null) {
              return const Center(child: Text('找不到店家資料'));
            }

            if (!_settingsInitialized) {
              _initSettingsIfNeeded(shop);
            }

            final today = _dateOnly(DateTime.now());
            final savedMaxAdvanceBookingDays = _toInt(
              shop['maxAdvanceBookingDays'],
              fallback: 30,
            );

            final planLimit = ShopPlanService.bookingOpenDaysLimit(shop);
            final draftDays = _toInt(
              _maxAdvanceBookingDaysController.text,
              fallback: savedMaxAdvanceBookingDays,
            );
            final maxAdvanceBookingDays = draftDays > planLimit
                ? planLimit
                : (draftDays <= 0 ? savedMaxAdvanceBookingDays : draftDays);

            final lastDate = today.add(Duration(days: maxAdvanceBookingDays));
            final _CalendarPayload payload = _CalendarPayload(
              blockedDateKeys: Set<String>.from(_draftBlockedDates),
              unbookableDateKeys: <String>{},
              remainingRoomsMap: const <String, int>{},
              occupiedRoomsMap: const <String, int>{},
            );

            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildBookingSettingsCard(),
                  const SizedBox(height: 16),
                  _buildCalendarSection(
                    shop: shop,
                    firstDate: today,
                    lastDate: lastDate,
                    payload: payload,
                  ),
                  const SizedBox(height: 16),
                  _buildBookingActionLogs(),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBookingSettingsCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '預約設定',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('開放前台預約'),
              subtitle: Text(_bookingEnabled ? '目前可預約' : '目前已關閉'),
              value: _bookingEnabled,
              onChanged: (value) {
                setState(() {
                  _bookingEnabled = value;
                });
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('開放安親服務'),
              subtitle: const Text(
                '關閉後，客戶端與店家後台的安親入口、設定與新增功能將暫時隱藏；既有安親訂單仍可查看及完成處理。',
              ),
              value: _daycareEnabled,
              onChanged: (bool value) {
                setState(() {
                  _daycareEnabled = value;
                });
              },
            ),

            const SizedBox(height: 12),
            TextFormField(
              controller: _maxAdvanceBookingDaysController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '最遠可預約天數',
                hintText: '免費版30天｜999方案365天',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _savingSettings
                    ? null
                    : () {
                        _saveSettings();
                      },
                child: _savingSettings
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('儲存預約設定'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCalendarSection({
    required Map<String, dynamic> shop,
    required DateTime firstDate,
    required DateTime lastDate,
    required _CalendarPayload? payload,
  }) {
    final loading = payload == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '日期管理月曆',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Text(
          '1. 可開啟或關閉前台預約功能。\n'
          '2. 可設定客戶最遠可預約天數。\n'
          '3. 可點擊日期關閉單日預約（先留在本機，儲存後才生效）。\n'
          '4. 關閉日期後，前台將無法選擇該日期預約。\n'
          '5. 若只是單一房間維修或臨時關閉，請至房務管理設定個別房間日期。',
          style: TextStyle(
            color: Colors.red,
            fontSize: 13,
            height: 1.6,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else
          BookingCalendar(
            initialMonth: _selectedCalendarDate ?? firstDate,
            firstDate: firstDate,
            lastDate: lastDate,
            allowBlockedTap: true,
            blockedDateKeys: payload.blockedDateKeys,
            unbookableDateKeys: payload.unbookableDateKeys,
            onDayTap: (date) {
              final selected = _dateOnly(date);
              _toggleDraftBlockedDate(date: selected);
              setState(() {
                _selectedCalendarDate = selected;
              });
            },
          ),
      ],
    );
  }

  Widget _buildBookingActionLogs() {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: ActionLogService.instance.streamShopLogs(widget.shopId),
      builder: (context, snapshot) {
        final logs = (snapshot.data ?? [])
            .where((log) {
              final action = log['action']?.toString() ?? '';

              return [
                'update_booking_settings',
                'block_date',
                'unblock_date',
              ].contains(action);
            })
            .take(20)
            .toList();

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '預約管理操作紀錄',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                if (logs.isEmpty) const Text('目前沒有預約管理操作紀錄'),

                ...logs.map((log) {
                  final action = log['action']?.toString() ?? '';

                  final payload = Map<String, dynamic>.from(
                    log['payload'] ?? {},
                  );

                  final dateKey = payload['dateKey']?.toString() ?? '-';

                  final createdAt = log['createdAt'];

                  String formattedTime = '-';

                  if (createdAt is Timestamp) {
                    formattedTime = DateFormat(
                      'yyyy-MM-dd HH:mm',
                    ).format(createdAt.toDate());
                  }

                  String title = action;

                  String settingDetail = '';

                  if (action == 'update_booking_settings') {
                    title = '更新預約設定';

                    final bookingEnabled = payload['bookingEnabled'] == true;

                    final maxDays = payload['maxAdvanceBookingDays'];

                    settingDetail =
                        '前台預約：${bookingEnabled ? '開啟' : '關閉'}\n'
                        '最遠預約天數：$maxDays 天';
                  } else if (action == 'block_date') {
                    title = '關閉預約日期';
                  } else if (action == 'unblock_date') {
                    title = '恢復預約日期';
                  }

                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.history),
                    title: Text(title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (settingDetail.isNotEmpty) Text(settingDetail),
                        Text('異動日期：$dateKey'),
                        Text('操作時間：$formattedTime'),
                        OperatorActorLabel(
                          shopId: widget.shopId,
                          log: log,
                          prefix: '操作人：',
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  void _initSettingsIfNeeded(Map<String, dynamic> shop) {
    if (_settingsInitialized) return;

    _bookingEnabled = DaycareBool.parse(shop['bookingEnabled'], fallback: true);
    _daycareEnabled = DaycareBool.parse(shop['daycareEnabled']);
    _savedBookingEnabled = _bookingEnabled;
    _savedDaycareEnabled = _daycareEnabled;

    _maxAdvanceBookingDaysController.text = _toInt(
      shop['maxAdvanceBookingDays'],
      fallback: 30,
    ).toString();
    _savedMaxAdvanceDays = _maxAdvanceBookingDaysController.text;

    _draftBlockedDates = List<String>.from(shop['blockedDates'] ?? <dynamic>[])
        .map((dynamic e) => e.toString())
        .where((String e) => e.isNotEmpty)
        .toSet();
    _savedBlockedDates = Set<String>.from(_draftBlockedDates);

    _selectedCalendarDate = _dateOnly(DateTime.now());

    _settingsInitialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    if (!shop.containsKey('daycareEnabled')) {
      _loadLegacyDaycareEnabled();
    }
  }

  Future<void> _loadLegacyDaycareEnabled() async {
    try {
      final settings = await DaycareSettingsService.instance.get(widget.shopId);
      if (!mounted || _dirty || _daycareEnabled) {
        return;
      }
      if (settings.enabled) {
        setState(() {
          _daycareEnabled = true;
          _savedDaycareEnabled = true;
        });
      }
    } catch (_) {}
  }

  void _toggleDraftBlockedDate({required DateTime date}) {
    final String dateKey = ShopService.instance.formatDateKey(date);
    setState(() {
      if (_draftBlockedDates.contains(dateKey)) {
        _draftBlockedDates.remove(dateKey);
      } else {
        _draftBlockedDates.add(dateKey);
      }
    });
  }

  Future<bool> _saveSettings() async {
    final maxAdvanceBookingDays =
        int.tryParse(_maxAdvanceBookingDaysController.text.trim()) ?? 0;

    final shopDoc = await FirebaseFirestore.instance
        .collection('shops')
        .doc(widget.shopId)
        .get();

    final shop = shopDoc.data() ?? {};

    final maxLimit = ShopPlanService.bookingOpenDaysLimit(shop);

    if (maxAdvanceBookingDays > maxLimit) {
      _showSnackBar('目前方案最多只能設定 $maxLimit 天');
      return false;
    }

    if (maxAdvanceBookingDays <= 0) {
      _showSnackBar('最遠可預約天數至少要 1');
      return false;
    }

    setState(() {
      _savingSettings = true;
    });

    try {
      await ShopService.instance.updateBookingSettings(
        shopId: widget.shopId,
        bookingEnabled: _bookingEnabled,
        daycareEnabled: _daycareEnabled,
        maxAdvanceBookingDays: maxAdvanceBookingDays,
      );
      await ShopService.instance.updateBlockedDates(
        shopId: widget.shopId,
        blockedDates: _draftBlockedDates.toList(),
      );
      await DaycareSettingsService.instance.syncEnabledFlag(
        shopId: widget.shopId,
        enabled: _daycareEnabled,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _currentUserRole != null) {
        final bool settingsChanged =
            _bookingEnabled != _savedBookingEnabled ||
            _daycareEnabled != _savedDaycareEnabled ||
            _maxAdvanceBookingDaysController.text.trim() !=
                _savedMaxAdvanceDays;
        if (settingsChanged) {
          await ActionLogService.instance.logAction(
            shopId: widget.shopId,
            targetType: 'shop_booking_settings',
            targetId: widget.shopId,
            action: 'update_booking_settings',
            operatorUid: user.uid,
            operatorRole: _currentUserRole!,
            payload: {
              'bookingEnabled': _bookingEnabled,
              'daycareEnabled': _daycareEnabled,
              'maxAdvanceBookingDays': maxAdvanceBookingDays,
            },
          );
        }
        final Set<String> added = _draftBlockedDates.difference(
          _savedBlockedDates,
        );
        final Set<String> removed = _savedBlockedDates.difference(
          _draftBlockedDates,
        );
        for (final String dateKey in added) {
          await ActionLogService.instance.logAction(
            shopId: widget.shopId,
            targetType: 'shop_calendar_date',
            targetId: dateKey,
            action: 'block_date',
            operatorUid: user.uid,
            operatorRole: _currentUserRole!,
            payload: {'dateKey': dateKey},
          );
        }
        for (final String dateKey in removed) {
          await ActionLogService.instance.logAction(
            shopId: widget.shopId,
            targetType: 'shop_calendar_date',
            targetId: dateKey,
            action: 'unblock_date',
            operatorUid: user.uid,
            operatorRole: _currentUserRole!,
            payload: {'dateKey': dateKey},
          );
        }
      }

      if (!mounted) {
        return false;
      }
      setState(() {
        _savedBookingEnabled = _bookingEnabled;
        _savedDaycareEnabled = _daycareEnabled;
        _savedMaxAdvanceDays = _maxAdvanceBookingDaysController.text.trim();
        _savedBlockedDates = Set<String>.from(_draftBlockedDates);
        _savingSettings = false;
      });
      _showSnackBar('預約設定已儲存');
      return true;
    } catch (e) {
      if (!mounted) {
        return false;
      }
      setState(() {
        _savingSettings = false;
      });
      _showSnackBar('儲存失敗：$e');
      return false;
    }
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class _CalendarPayload {
  const _CalendarPayload({
    required this.blockedDateKeys,
    required this.unbookableDateKeys,
    required this.remainingRoomsMap,
    required this.occupiedRoomsMap,
  });

  final Set<String> blockedDateKeys;
  final Set<String> unbookableDateKeys;
  final Map<String, int> remainingRoomsMap;
  final Map<String, int> occupiedRoomsMap;
}
