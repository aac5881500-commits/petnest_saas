// 檔案名稱 lib/features/shop/pages/shop_booking_page.dart
//
// 前台預約頁（共用月曆版）
//
// 功能：
// - 第一眼先顯示月曆
// - 顯示每日價格 / 剩餘房數 / 不可預約狀態
// - 先選入住與退房
// - 再填預約資料
// - 送出前再次驗證區間
//
// 規則：
// - 第一次點：入住日
// - 第二次點：退房日
// - 若第二次點的日期 <= 入住日，則重新選入住日
// - 顯示區間晚數 / 總價 / 最少剩餘房數

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/booking_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/shared/widgets/booking_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/pet_service.dart';
import 'package:petnest_saas/features/pet/pages/add_pet_page.dart';
import 'package:flutter/foundation.dart';


class ShopBookingPage extends StatefulWidget {
  const ShopBookingPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  State<ShopBookingPage> createState() => _ShopBookingPageState();
}

class _ShopBookingPageState extends State<ShopBookingPage> {
  final _formKey = GlobalKey<FormState>();

  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _petNameController = TextEditingController();
  final _petTypeController = TextEditingController();
  final _noteController = TextEditingController();

  bool _submitting = false;
  bool _checkingRange = false;

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;
  String? _selectedServiceType;
  Map<String, dynamic>? _selectedRoomType;

  bool _rangeChecked = false;
  bool _rangeBookable = false;
  String _rangeMessage = '請先在月曆選擇入住與退房日期';

  int _rangeTotalPrice = 0;
  int _rangeMinRemainingRooms = 0;


List<String> _selectedPetIds = [];

DateTime _calendarMonth = DateTime.now();
Future<_FrontCalendarPayload>? _calendarFuture;

  @override
  void dispose() {
    _customerNameController.dispose();
    _customerPhoneController.dispose();
    _petNameController.dispose();
    _petTypeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _nights {
    if (_startDate == null || _endDate == null) return 0;
    return BookingService.instance.calculateNights(
      startDate: _startDate!,
      endDate: _endDate!,
    );
  }

  bool get _canShowFormFields {
    return _startDate != null && _endDate != null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('我要預約'),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        stream: ShopService.instance.streamShop(widget.shopId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('讀取店家資料失敗：${snapshot.error}'),
            );
          }

          final shop = snapshot.data;
          if (shop == null) {
            return const Center(
              child: Text('找不到店家資料'),
            );
          }

          final List<dynamic> rawServiceTypes = shop['serviceTypes'] ?? [];
          final List<String> serviceTypes =
              rawServiceTypes.map((e) => e.toString()).toList();

          if (_selectedServiceType == null && serviceTypes.isNotEmpty) {
            _selectedServiceType = serviceTypes.first;
          }

          final today = _dateOnly(DateTime.now());
          final bookingEnabled = shop['bookingEnabled'] ?? true;
          final maxAdvanceBookingDays =
              _toInt(shop['maxAdvanceBookingDays'], fallback: 30);
          final lastDate = today.add(Duration(days: maxAdvanceBookingDays));

          return SingleChildScrollView(
  padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          shop['name'] ?? '未命名店家',
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        Text(
                          bookingEnabled ? '請先從月曆選擇日期區間' : '目前店家暫停開放預約',
                          style: TextStyle(
                            color: bookingEnabled ? null : Colors.red,
                          ),
                        ),

ElevatedButton(
  onPressed: () async {

  await _openCalendarDialog(shop);
},
  child: const Text('選擇日期'),
),

                        const SizedBox(height: 16),

if (_startDate != null && _endDate != null) ...[
  const SizedBox(height: 16),

  /// 👇 選擇寵物
  Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text(
  '選擇入住寵物（已選 ${_selectedPetIds.length} 隻）',
  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
),

const SizedBox(height: 8),

// 👇👇👇 插在這裡（新增按鈕）
Align(
  alignment: Alignment.centerRight,
  child: TextButton(
    onPressed: () async {
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const AddPetPage(),
        ),
      );

      setState(() {}); // 🔥 回來刷新
    },
    child: const Text('+ 新增寵物'),
  ),
),

const SizedBox(height: 8),

    StreamBuilder<List<Map<String, dynamic>>>(
  stream: PetService.instance.streamMyPets(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return const CircularProgressIndicator();
    }

    final pets = snapshot.data!;

    if (pets.isEmpty) {
      return const Text('尚未新增寵物');
    }

    return Wrap(
      spacing: 8,
      children: pets.map((pet) {
        final petId = pet['petId'];
        final selected = _selectedPetIds.contains(petId);

        return FilterChip(
          label: Text(pet['name'] ?? '未命名'),
          selected: selected,
          onSelected: (value) {
            setState(() {
              if (value) {
                _selectedPetIds.add(petId);
              } else {
                _selectedPetIds.remove(petId);
              }

              // 🔥 重選房型
              _selectedRoomType = null;
            });
          },
        );
      }).toList(),
    );
  },
),
  ],
), 
  _buildRoomTypeSection(),
],


                        if (_canShowFormFields) ...[
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 20),
                          const Text(
                            '預約資料',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          Form(
                            key: _formKey,
                            child: Column(
                              children: [
                                Padding(
  padding: const EdgeInsets.all(12),
  child: Text(
    (_tempStartDate != null && _tempEndDate != null)
        ? '已選：${_formatDate(_tempStartDate!)} ～ ${_formatDate(_tempEndDate!)}'
        : '請選擇入住與退房日期',
    style: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.bold,
    ),
  ),
),
                                TextFormField(
                                  controller: _customerNameController,
                                  decoration: const InputDecoration(
                                    labelText: '聯絡人姓名',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (!_canSubmit(serviceTypes)) return null;
                                    if (value == null || value.trim().isEmpty) {
                                      return '請輸入聯絡人姓名';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _customerPhoneController,
                                  keyboardType: TextInputType.phone,
                                  decoration: const InputDecoration(
                                    labelText: '聯絡電話',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (!_canSubmit(serviceTypes)) return null;
                                    if (value == null || value.trim().isEmpty) {
                                      return '請輸入聯絡電話';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _petNameController,
                                  decoration: const InputDecoration(
                                    labelText: '寵物名字',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (!_canSubmit(serviceTypes)) return null;
                                    if (value == null || value.trim().isEmpty) {
                                      return '請輸入寵物名字';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _petTypeController,
                                  decoration: const InputDecoration(
                                    labelText: '寵物類型（例如：貓 / 狗）',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (!_canSubmit(serviceTypes)) return null;
                                    if (value == null || value.trim().isEmpty) {
                                      return '請輸入寵物類型';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),

                                DropdownButtonFormField<String>(
                                  value: _selectedServiceType,
                                  items: serviceTypes.map((service) {
                                    return DropdownMenuItem<String>(
                                      value: service,
                                      child: Text(_serviceTypeText(service)),
                                    );
                                  }).toList(),
                                  onChanged: serviceTypes.isEmpty
                                      ? null
                                      : (value) {
                                          setState(() {
                                            _selectedServiceType = value;
                                          });
                                        },
                                  decoration: const InputDecoration(
                                    labelText: '服務類型',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (!_canSubmit(serviceTypes)) return null;
                                    if (serviceTypes.isNotEmpty &&
                                        (value == null || value.isEmpty)) {
                                      return '請選擇服務類型';
                                    }
                                    return null;
                                  },
                                ),

                                if (serviceTypes.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  const Align(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '此店家尚未設定服務項目，暫時無法預約。',
                                      style: TextStyle(color: Colors.red),
                                    ),
                                  ),
                                ],

                                const SizedBox(height: 16),

                                TextFormField(
                                  controller: _noteController,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                    labelText: '備註',
                                    border: OutlineInputBorder(),
                                    alignLabelWithHint: true,
                                  ),
                                ),

                                const SizedBox(height: 24),


                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    onPressed: _canSubmit(serviceTypes)
                                        ? () => _submitBooking(shop)
                                        : null,
                                    child: _submitting
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('送出預約'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
      ),
    );
  }


  Widget _buildRangeResultCard() {
    final Color color;
    if (!_rangeChecked) {
      color = Colors.grey;
    } else if (_rangeBookable) {
      color = Colors.green;
    } else {
      color = Colors.red;
    }

    return Card(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '第二步：確認可預約狀態',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Icon(
                  _rangeChecked
                      ? (_rangeBookable ? Icons.check_circle : Icons.cancel)
                      : Icons.info,
                  color: color,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _rangeMessage,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            if (_rangeChecked && _rangeBookable && _selectedPetIds.isNotEmpty)...[
              const SizedBox(height: 12),
              _infoRow('入住日', _formatDate(_startDate!)),
              const SizedBox(height: 8),
              _infoRow('退房日', _formatDate(_endDate!)),
              const SizedBox(height: 8),
              _infoRow('晚數', '$_nights 晚'),
              const SizedBox(height: 8),
              _infoRow('區間總價', 'NT\$ $_rangeTotalPrice'),
              const SizedBox(height: 8),
              _infoRow('區間內最少剩餘房數', '$_rangeMinRemainingRooms'),
            ],
          ],
        ),
      ),
    );
  }

  Future<_FrontCalendarPayload> _buildFrontCalendarPayload({
    required Map<String, dynamic> shop,
    required DateTime firstDate,
    required DateTime lastDate,
  }) async {

    if (kDebugMode) {
  print('🔥 抓資料了：$firstDate ~ $lastDate');
}

    final blockedDateKeys =
        List<String>.from(shop['blockedDates'] ?? []).map((e) => e.toString()).toSet();

    final Map<String, int> priceMap = {};
    final Map<String, int> remainingRoomsMap = {};
    final Set<String> unbookableDateKeys = {};

    DateTime cursor = _dateOnly(firstDate);
    final last = _dateOnly(lastDate);

final bookings = <Map<String, dynamic>>[];

while (!cursor.isAfter(last)) {
  final key = ShopService.instance.formatDateKey(cursor);

  priceMap[key] = ShopService.instance.getPriceForDate(
    shop,
    cursor,
  );

  int occupied = 0;

  for (final booking in bookings) {
    final start = (booking['startDate'] as Timestamp).toDate();
    final end = (booking['endDate'] as Timestamp).toDate();



    DateTime temp = DateTime(start.year, start.month, start.day);

    while (!temp.isAfter(end.subtract(const Duration(days: 1)))) {
      final dKey = ShopService.instance.formatDateKey(temp);

      if (dKey == key) {
        occupied++;
        break;
      }

      temp = temp.add(const Duration(days: 1));
    }
  }

  final totalRooms = _toInt(shop['totalRooms']);
  final cleaning = _toInt(shop['cleaningRooms']);
  final maintenance = _toInt(shop['maintenanceRooms']);

  final remaining = totalRooms - cleaning - maintenance - occupied;

  remainingRoomsMap[key] = remaining;

  if (remaining <= 0) {
    unbookableDateKeys.add(key);
  }

  cursor = cursor.add(const Duration(days: 1));
}

    return _FrontCalendarPayload(
      blockedDateKeys: blockedDateKeys,
      unbookableDateKeys: unbookableDateKeys,
      priceMap: priceMap,
      remainingRoomsMap: remainingRoomsMap,
    );
  }

  Future<void> _handleCalendarTap({
  required Map<String, dynamic> shop,
  required DateTime date,
}) async {
  final tapped = _dateOnly(date);

  if (_checkingRange || _submitting) return;

  /// 第一次點 or 重選
  if (_tempStartDate == null || (_tempStartDate != null && _tempEndDate != null)) {
    setState(() {
      _tempStartDate = tapped;
      _tempEndDate = null;
    });

    print('👉 第一次點: $tapped');
    return;
  }

  /// 第二次點
  if (_tempEndDate == null) {
    /// 點到比開始早 → 重設開始
    if (tapped.isBefore(_tempStartDate!)) {
      setState(() {
        _tempStartDate = tapped;
        _tempEndDate = null;
      });

      print('👉 重新選開始: $tapped');
      return;
    }

    /// 正常設定結束
    setState(() {
      _tempEndDate = tapped;
    });

    print('👉 設定區間: $_tempStartDate ~ $_tempEndDate');
    return;
  }
}

  bool _canSubmit(List<String> serviceTypes) {
    return !_submitting &&
        !_checkingRange &&
        _rangeChecked &&
        _rangeBookable &&
        _startDate != null &&
        _endDate != null &&
        serviceTypes.isNotEmpty;
  }

  Future<void> _submitBooking(Map<String, dynamic> shop) async {
    if (!_formKey.currentState!.validate()) return;

    if (_startDate == null || _endDate == null) {
      _showSnackBar('請先選擇入住與退房日期');
      return;
    }

    if (_nights <= 0) {
      _showSnackBar('退房日必須晚於入住日');
      return;
    }

    if (_selectedServiceType == null || _selectedServiceType!.isEmpty) {
  _showSnackBar('請選擇服務類型');
  return;
}

// 👇 加在這裡🔥
if (_selectedRoomType == null) {
  _showSnackBar('請先選擇房型');
  return;
}

    // 🔥 容量檢查（先簡單版）
if (_selectedPetIds.isEmpty) {
  _showSnackBar('請選擇入住寵物');
  return;
}



    setState(() {
      _submitting = true;
    });

    try {
      // 🔒 檢查房間是否已被預約（最終防線🔥）

      final totalPrice = BookingService.instance.calculateTotalPrice(
        roomType: _selectedRoomType!,
        startDate: _startDate!,
        endDate: _endDate!,
      );

      final pricePerNight = _nights > 0 ? (totalPrice ~/ _nights) : 0;

      final bookingId = await BookingService.instance.createBooking(
  shopId: widget.shopId,
  customerName: _customerNameController.text,
  customerPhone: _customerPhoneController.text,
  petIds: _selectedPetIds,
  serviceType: _selectedServiceType!,
  roomId: _selectedRoomType!['roomTypeId'], 
  roomName: _selectedRoomType!['name'],     
  startDate: _startDate!,
  endDate: _endDate!,
  nights: _nights,
  note: _noteController.text,
);
      await BookingService.instance.updateBooking(
        bookingId: bookingId,
        totalPrice: totalPrice,
        pricePerNight: pricePerNight,
      );


      if (!mounted) return;

      _showSnackBar('預約已送出');
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('送出失敗：$e');
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
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

  String _serviceTypeText(String value) {
    switch (value) {
      case 'overnight':
        return '住宿';
      case 'daycare':
        return '日托';
      case 'grooming':
        return '美容';
      case 'training':
        return '訓練';
      default:
        return value;
    }
  }

  Future<void> _openCalendarDialog(Map<String, dynamic> shop) async {
  final today = _dateOnly(DateTime.now());
  final maxDays = _toInt(shop['maxAdvanceBookingDays'], fallback: 30);

  _tempStartDate = _startDate;
  _tempEndDate = _endDate;


  // 🔥 當前月份範圍
  final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
  final lastDay = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);

  // 🔥 只抓一次
  _calendarFuture ??= _buildFrontCalendarPayload(
    shop: shop,
    firstDate: firstDay,
    lastDate: lastDay,
  );

  showDialog(
  context: context,
  builder: (_) {
    return StatefulBuilder(
      builder: (context, setInnerState) {
        return FutureBuilder<_FrontCalendarPayload>(
          future: _calendarFuture,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            final payload = snapshot.data!;

            return Dialog(
  insetPadding: const EdgeInsets.symmetric(horizontal: 100, vertical: 40),
  child: SafeArea(
    child: SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [

          /// 🔥 日曆
          Flexible(
            child: BookingCalendar(
              key: ValueKey('${_tempStartDate}_${_tempEndDate}'),

              initialMonth: _calendarMonth,
              firstDate: today,
              lastDate: today.add(Duration(days: maxDays)),

              rangeStart: _tempStartDate,
              rangeEnd: _tempEndDate,

              blockedDateKeys: payload.blockedDateKeys,
              unbookableDateKeys: payload.unbookableDateKeys,

              onMonthChanged: (newMonth) {
                if (!mounted) return;

                final firstDay = DateTime(newMonth.year, newMonth.month, 1);
                final lastDay = DateTime(newMonth.year, newMonth.month + 1, 0);

                setState(() {
                  _calendarMonth = newMonth;

                  _calendarFuture = _buildFrontCalendarPayload(
                    shop: shop,
                    firstDate: firstDay,
                    lastDate: lastDay,
                  );
                });
              },

              onDayTap: (date) async {
                await _handleCalendarTap(
                  shop: shop,
                  date: date,
                );

                if (!mounted) return;

                setInnerState(() {}); // 🔥 更新UI
              },
            ),
          ),

          /// 🔥 底部按鈕
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [

                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text('取消'),
                  ),
                ),

                const SizedBox(width: 12),

                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _startDate = _tempStartDate;
                        _endDate = _tempEndDate;
                      });

                      Navigator.pop(context);
                    },
                    child: const Text('確認'),
                  ),
                ),

              ],
            ),
          ),

        ],
      ),
    ),
  ),
);
          },
        );
      },
    );
  },
);
}
/// ===============================
/// 第三步：房型
/// ===============================
Widget _buildRoomTypeSection() {
  if (_startDate == null || _endDate == null) {
    return const SizedBox();
  }

  return FutureBuilder<List<Map<String, dynamic>>>(
    future: ShopService.instance.getAvailableRoomTypes(
      shopId: widget.shopId,
      startDate: _startDate!,
      endDate: _endDate!,
    ),
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.waiting) {
        return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()),
        );
      }

      final roomTypes = (snapshot.data ?? [])
    .where((type) {
      final capacity = (type['capacity'] ?? 1) as int;
      final availableRooms = (type['availableRooms'] ?? 0) as int;

      // 🔥 三重條件
      if (capacity < _selectedPetIds.length) return false;
      if (availableRooms <= 0) return false;

      return true;
    })
    .toList();
    
      if (roomTypes.isEmpty) {
        return const Text('此區間沒有可用房型');
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '第三步：選擇房型',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          ...roomTypes.map((type) {
            return Card(
              child: ListTile(
                title: Text(type['name'] ?? ''),
                subtitle: Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    Text('容量：${type['capacity']}'),

    const SizedBox(height: 4),

    Builder(
      builder: (_) {
        final rooms = type['availableRooms'] ?? 0;

        if (rooms <= 1) {
          return const Text(
            '🔥 剩 1 間',
            style: TextStyle(color: Colors.red),
          );
        }

        return Text('剩 $rooms 間');
      },
    ),
  ],
),
                trailing: Text('NT\$ ${type['price']}'),
                onTap: () => _onSelectRoomType(type),
              ),
            );
          }).toList(),
        ],
      );
    },
  );
}


/// ===============================
/// 點房型
/// ===============================
void _onSelectRoomType(Map<String, dynamic> type) {
  setState(() {
    _selectedRoomType = type;
  });
}

/// ✅ 關閉 _ShopBookingPageState
}

class _FrontCalendarPayload {
  const _FrontCalendarPayload({
    required this.blockedDateKeys,
    required this.unbookableDateKeys,
    required this.priceMap,
    required this.remainingRoomsMap,
  });

  final Set<String> blockedDateKeys;
  final Set<String> unbookableDateKeys;
  final Map<String, int> priceMap;
  final Map<String, int> remainingRoomsMap;

  
}