// 檔案名稱 lib/features/auth/pages/shop_booking_manage_page.dart
//
// 預約管理頁（店家後台）
//
// 功能：
// - 預約設定區
// - 共用月曆顯示
// - 點日期可關閉 / 開放

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/action_log_service.dart';
import 'package:petnest_saas/core/services/booking_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/shared/widgets/booking_calendar.dart';

class ShopBookingManagePage extends StatefulWidget {
  const ShopBookingManagePage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  State<ShopBookingManagePage> createState() => _ShopBookingManagePageState();
}

class _ShopBookingManagePageState extends State<ShopBookingManagePage> {
  String _selectedStatus = 'all';

  final _maxAdvanceBookingDaysController = TextEditingController();


  bool _bookingEnabled = true;
  bool _settingsInitialized = false;
  bool _savingSettings = false;

  String? _currentUserRole;
  bool _roleLoaded = false;

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
      final role = await ShopService.instance.getUserRoleInShop(
        shopId: widget.shopId,
        uid: user.uid,
      );

      if (!mounted) return;
      setState(() {
        _currentUserRole = role;
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_currentUserRole == null) {
      return const Scaffold(
        body: Center(
          child: Text('查無店家權限'),
        ),
      );
    }

    if (!ShopService.instance.canManageShop(_currentUserRole)) {
      return const Scaffold(
        body: Center(
          child: Text('你沒有管理權限'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('預約管理'),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: ShopService.instance.streamShop(widget.shopId),
        builder: (context, shopSnapshot) {
          if (shopSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (shopSnapshot.hasError) {
            return Center(
              child: Text('店家資料載入失敗：${shopSnapshot.error}'),
            );
          }

          final shop = shopSnapshot.data;
          if (shop == null) {
            return const Center(child: Text('找不到店家資料'));
          }

          if (!_settingsInitialized) {
  _initSettingsIfNeeded(shop);
}

          final today = _dateOnly(DateTime.now());
          final maxAdvanceBookingDays =
              _toInt(shop['maxAdvanceBookingDays'], fallback: 30);
          final lastDate = today.add(Duration(days: maxAdvanceBookingDays));

          final selectedDate = _selectedCalendarDate ?? today;
          final normalizedSelectedDate = _dateOnly(selectedDate);
          final selectedDateKey =
              ShopService.instance.formatDateKey(normalizedSelectedDate);

          return FutureBuilder<_CalendarPayload>(
            future: _buildCalendarPayload(
              shop: shop,
              firstDate: today,
              lastDate: lastDate,
            ),
            builder: (context, calendarSnapshot) {
              final payload = calendarSnapshot.data;

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
                  ],
                ),
              );
            },
          );
        },
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
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
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

            const SizedBox(height: 12),
            TextFormField(
              controller: _maxAdvanceBookingDaysController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '最遠可預約天數',
                hintText: '例如 30 / 60',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _savingSettings ? null : _saveSettings,
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
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '紅色代表關閉或不可預約。點日期可切換開放/關閉並設定原因。',
          style: TextStyle(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(
                child: CircularProgressIndicator(),
              ),
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
            onDayTap: (date) async {
  final selected = _dateOnly(date);

  await _toggleBlockedDate(
    shop: shop,
    date: selected,
  );

  if (!mounted) return;

  setState(() {
    _selectedCalendarDate = selected;
  });
},
          ),
      ],
    );
  }


  Widget _buildFilterBar() {
    return Row(
      children: [
        const Text(
          '篩選狀態：',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: _selectedStatus,
            items: const [
              DropdownMenuItem(value: 'all', child: Text('全部')),
              DropdownMenuItem(value: 'pending', child: Text('待確認')),
              DropdownMenuItem(value: 'confirmed', child: Text('已確認')),
              DropdownMenuItem(value: 'completed', child: Text('已完成')),
              DropdownMenuItem(value: 'cancelled', child: Text('已取消')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedStatus = value;
              });
            },
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBookingList(
    AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
  ) {
    if (snapshot.connectionState == ConnectionState.waiting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (snapshot.hasError) {
      return Center(
        child: Text('載入失敗：${snapshot.error}'),
      );
    }

    final bookings = snapshot.data ?? [];

    if (bookings.isEmpty) {
      return Container(
        alignment: Alignment.topCenter,
        padding: const EdgeInsets.only(top: 24),
        child: const Text('目前沒有預約資料'),
      );
    }

    return ListView.separated(
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final booking = bookings[index];

        final Timestamp? startTimestamp = booking['startDate'];
        final Timestamp? endTimestamp = booking['endDate'];

        final DateTime? startDate = startTimestamp?.toDate();
        final DateTime? endDate = endTimestamp?.toDate();

        final int nights = _toInt(booking['nights']);

        final pets = (booking['pets'] as List?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ??
      [];

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  booking['customerName'] ?? '未填姓名',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text('電話：${booking['customerPhone'] ?? '-'}'),
              
Text(
  '寵物：${pets.isEmpty ? '-' : pets.map((p) => p['name']).join(', ')}',
),
                Text('服務類型：${booking['serviceType'] ?? '-'}'),
                Text('入住日：${_formatDateNullable(startDate)}'),
                Text('退房日：${_formatDateNullable(endDate)}'),
                Text('晚數：$nights 晚'),
                Text('總價：NT\$ ${_toInt(booking['totalPrice'])}'),
                Text('備註：${booking['note'] ?? ''}'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      '目前狀態：',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: _statusColor(booking['status']).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _statusText(booking['status']),
                        style: TextStyle(
                          color: _statusColor(booking['status']),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _updateStatus(
                        bookingId: booking['bookingId'],
                        status: 'pending',
                      ),
                      child: const Text('待確認'),
                    ),
                    OutlinedButton(
                      onPressed: () => _updateStatus(
                        bookingId: booking['bookingId'],
                        status: 'confirmed',
                      ),
                      child: const Text('確認'),
                    ),
                    OutlinedButton(
                      onPressed: () => _updateStatus(
                        bookingId: booking['bookingId'],
                        status: 'completed',
                      ),
                      child: const Text('完成'),
                    ),
                    OutlinedButton(
                      onPressed: () => _updateStatus(
                        bookingId: booking['bookingId'],
                        status: 'cancelled',
                      ),
                      child: const Text('取消'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<_CalendarPayload> _buildCalendarPayload({
    required Map<String, dynamic> shop,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {
    final blockedDateKeys = List<String>.from(shop['blockedDates'] ?? [])
        .map((e) => e.toString())
        .toSet();

    final Map<String, int> remainingRoomsMap = {};
    final Map<String, int> occupiedRoomsMap = {};
    final Set<String> unbookableDateKeys = {};

    DateTime cursor = _dateOnly(firstDate);
    final last = _dateOnly(lastDate);

    while (!cursor.isAfter(last)) {
  final key = ShopService.instance.formatDateKey(cursor);


// 🔥 後台月曆不再算房間（統一用前台邏輯）
occupiedRoomsMap[key] = 0;
remainingRoomsMap[key] = 0;

  cursor = cursor.add(const Duration(days: 1));
}

    return _CalendarPayload(
      blockedDateKeys: blockedDateKeys,
      unbookableDateKeys: unbookableDateKeys,
      remainingRoomsMap: remainingRoomsMap,
      occupiedRoomsMap: occupiedRoomsMap,
    );
  }

  void _initSettingsIfNeeded(Map<String, dynamic> shop) {
  if (_settingsInitialized) return;

  _bookingEnabled = shop['bookingEnabled'] ?? true;

  _maxAdvanceBookingDaysController.text =
      _toInt(shop['maxAdvanceBookingDays'], fallback: 30).toString();

  _selectedCalendarDate = _dateOnly(DateTime.now());

  _settingsInitialized = true;

  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted) setState(() {});
  });
}

  Future<void> _saveSettings() async {

    final maxAdvanceBookingDays =
        int.tryParse(_maxAdvanceBookingDaysController.text.trim()) ?? 0;


    if (maxAdvanceBookingDays <= 0) {
      _showSnackBar('最遠可預約天數至少要 1');
      return;
    }


    setState(() {
      _savingSettings = true;
    });

    try {
      await ShopService.instance.updateBookingSettings(
        shopId: widget.shopId,
        bookingEnabled: _bookingEnabled,
        maxAdvanceBookingDays: maxAdvanceBookingDays,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _currentUserRole != null) {
        await ActionLogService.instance.logAction(
          shopId: widget.shopId,
          targetType: 'shop_booking_settings',
          targetId: widget.shopId,
          action: 'update_booking_settings',
          operatorUid: user.uid,
          operatorRole: _currentUserRole!,
          payload: {
            'bookingEnabled': _bookingEnabled,
            'maxAdvanceBookingDays': maxAdvanceBookingDays,
          },
        );
      }

      if (!mounted) return;
      _showSnackBar('預約設定已儲存');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('儲存失敗：$e');
    } finally {
      if (mounted) {
        setState(() {
          _savingSettings = false;
        });
      }
    }
  }

  Future<void> _toggleBlockedDate({
    required Map<String, dynamic> shop,
    required DateTime date,
  }) async {
    final dateKey = ShopService.instance.formatDateKey(date);
    final blocked = ShopService.instance.isBlockedDate(shop, date);

String? reason;

if (!blocked) {
  final controller = TextEditingController();

  reason = await showDialog<String>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: Text('設定關閉原因：$dateKey'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: '原因（例如：店休 / 清潔 / 客滿）',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context, controller.text.trim());
            },
            child: const Text('確認'),
          ),
        ],
      );
    },
  );

  if (reason == null || reason.isEmpty) return;
}

    try {
      final user = FirebaseAuth.instance.currentUser;

      if (blocked) {
        await ShopService.instance.removeBlockedDate(
          shopId: widget.shopId,
          dateKey: dateKey,
        );

        if (user != null && _currentUserRole != null) {
          await ActionLogService.instance.logAction(
            shopId: widget.shopId,
            targetType: 'shop_calendar_date',
            targetId: dateKey,
            action: 'unblock_date',
            operatorUid: user.uid,
            operatorRole: _currentUserRole!,
            payload: {
              'dateKey': dateKey,
            },
          );
        }

        if (!mounted) return;
        _showSnackBar('已改成開放：$dateKey');
      } else {
  await FirebaseFirestore.instance
      .collection('shops')
      .doc(widget.shopId)
      .update({
    'blockedDates': FieldValue.arrayUnion([dateKey]),
    'blockedDateReasons.$dateKey': reason,
  });


        if (user != null && _currentUserRole != null) {
          await ActionLogService.instance.logAction(
            shopId: widget.shopId,
            targetType: 'shop_calendar_date',
            targetId: dateKey,
            action: 'block_date',
            operatorUid: user.uid,
            operatorRole: _currentUserRole!,
            payload: {
              'dateKey': dateKey,
            },
          );
        }

        if (!mounted) return;
        _showSnackBar('已改成關閉：$dateKey');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('更新失敗：$e');
    }
  }

  Future<void> _updateStatus({
    required String bookingId,
    required String status,
  }) async {
    try {
      await BookingService.instance.updateBookingStatus(
        bookingId: bookingId,
        status: status,
      );

      final user = FirebaseAuth.instance.currentUser;
      if (user != null && _currentUserRole != null) {
        await ActionLogService.instance.logAction(
          shopId: widget.shopId,
          targetType: 'booking',
          targetId: bookingId,
          action: 'update_booking_status',
          operatorUid: user.uid,
          operatorRole: _currentUserRole!,
          payload: {
            'bookingId': bookingId,
            'status': status,
          },
        );
      }

      if (!mounted) return;
      _showSnackBar('狀態已更新為：${_statusText(status)}');
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('更新失敗：$e');
    }
  }

  Widget _infoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
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

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String _formatDateNullable(DateTime? date) {
    if (date == null) return '-';
    return _formatDate(date);
  }

  String _statusText(String? status) {
    switch (status) {
      case 'pending':
        return '待確認';
      case 'confirmed':
        return '已確認';
      case 'completed':
        return '已完成';
      case 'cancelled':
        return '已取消';
      default:
        return '未知狀態';
    }
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
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