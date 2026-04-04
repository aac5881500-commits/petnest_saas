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

import 'package:petnest_saas/features/member/pages/member_page.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/booking_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/shared/widgets/booking_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/services/pet_service.dart';
import 'package:petnest_saas/features/pet/pages/add_pet_page.dart';
import 'package:flutter/foundation.dart';
import 'package:petnest_saas/core/services/member_service.dart';
import 'package:petnest_saas/features/booking/pages/booking_form_page.dart';
import 'package:petnest_saas/features/booking/pages/booking_success_page.dart';


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

@override
void initState() {
  super.initState();
  _loadMemberData();
}
  final _formKey = GlobalKey<FormState>();

  final _customerNameController = TextEditingController();
  final _customerPhoneController = TextEditingController();
  final _petNameController = TextEditingController();
  final _petTypeController = TextEditingController();
  final _noteController = TextEditingController();

  bool _submitting = false;
  bool _checkingRange = false;
  bool _isBlacklisted = false;

  DateTime? _startDate;
  DateTime? _endDate;
  DateTime? _tempStartDate;
  DateTime? _tempEndDate;
  String? _selectedServiceType;
  Map<String, dynamic>? _selectedRoomType;

  bool _rangeChecked = false;
  bool _rangeBookable = false;
  String _rangeMessage = '';

  int _rangeTotalPrice = 0;
  int _rangeMinRemainingRooms = 0;


List<String> _selectedPetIds = [];

Future<void> _loadMemberData() async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return;

  final doc = await FirebaseFirestore.instance
      .collection('user_profiles')
      .doc(user.uid)
      .get();

  final data = doc.data();
  if (data == null) return;

final tags = List<String>.from(data['tags'] ?? []);

setState(() {
  _customerNameController.text = data['name'] ?? '';
  _customerPhoneController.text = data['phone'] ?? '';
  _isBlacklisted = tags.contains('blacklist'); // 🔥關鍵
});
}



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

drawer: Drawer(
  child: Column(
    children: [

      const DrawerHeader(
        child: Text('會員中心'),
      ),

      ListTile(
        leading: const Icon(Icons.login),
        title: const Text('登入會員'),
        onTap: () {
          Navigator.pop(context);

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const MemberPage(),
            ),
          );
        },
      ),

    ],
  ),
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

StreamBuilder<List<Map<String, dynamic>>>(
  stream: PetService.instance.streamMyPets(),
  builder: (context, snapshot) {
    final pets = snapshot.data ?? [];

    final isLimitReached = pets.length >= 5;

    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: isLimitReached
            ? null
            : () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const AddPetPage(),
                  ),
                );

                setState(() {});
              },
        child: Text(
          isLimitReached ? '已達上限（5隻）' : '+ 新增寵物',
          style: TextStyle(
            color: isLimitReached ? Colors.grey : null,
          ),
        ),
      ),
    );
  },
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
  avatar: CircleAvatar(
    backgroundColor: Colors.grey.shade200,
    backgroundImage: (pet['photoUrl'] != null &&
            pet['photoUrl'].toString().isNotEmpty)
        ? NetworkImage(pet['photoUrl'])
        : null,
    child: (pet['photoUrl'] == null ||
            pet['photoUrl'].toString().isEmpty)
        ? const Icon(Icons.pets, size: 16)
        : null,
  ),
  label: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        pet['name'] ?? '未命名',
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
      Text(
        '性別：${pet['gender'] ?? '-'} ｜ 貓砂：${pet['litterType'] ?? '-'}',
        style: const TextStyle(fontSize: 11),
      ),
      Text(
        '社交：${pet['canSocial'] == true ? '可' : '不可'} ｜ 用藥：${pet['canMedicate'] == true ? '可' : '不可'}',
        style: const TextStyle(fontSize: 11),
      ),
    ],
  ),
  selected: selected,
  onSelected: (value) {
    setState(() {
      if (value) {
        _selectedPetIds.add(petId);
      } else {
        _selectedPetIds.remove(petId);
      }

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

// 🔥 加在這裡
if (_selectedRoomType != null && _startDate != null && _endDate != null) ...[
  const SizedBox(height: 16),
  _buildBookingSummary(),
],

if (_canShowFormFields) ...[
  const SizedBox(height: 20),
  const Divider(),
  const SizedBox(height: 20),

  SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: (_canSubmit(serviceTypes) && !_isBlacklisted)
          ? () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => BookingFormPage(
                    formKey: _formKey,
                    customerNameController: _customerNameController,
                    customerPhoneController: _customerPhoneController,
                    noteController: _noteController,
                    serviceTypes: serviceTypes,
                    selectedServiceType: _selectedServiceType,
                    onServiceChanged: (value) {
                      setState(() {
                        _selectedServiceType = value;
                      });
                    },
                    onSubmitWithData: (
  address,
  emergencyName,
  emergencyPhone,
  relation,
  emergencyAddress,
  phone2,
) {
  _submitBooking(
    shop,
    address: address,
    emergencyName: emergencyName,
    emergencyPhone: emergencyPhone,
    relation: relation,
    emergencyAddress: emergencyAddress,
    phone2: phone2,
  );
},
                    onSubmit: () {},
                    isSubmitting: _submitting,
                    canSubmit: _canSubmit(serviceTypes),
                    isBlacklisted: _isBlacklisted,
                  ),
                ),
              );
            }
          : null,
      child: const Text('下一步：填寫資料'),
    ),
  ),
],

                        if (_canShowFormFields) ...[
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 20),
                        ],
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

    final Map<String, String> blockedDateReasons =
    Map<String, dynamic>.from(shop['blockedDateReasons'] ?? {})
        .map((key, value) => MapEntry(key, value.toString()));

    final Map<String, int> priceMap = {};
    final Map<String, int> remainingRoomsMap = {};
    final Set<String> unbookableDateKeys = {};

    DateTime cursor = _dateOnly(firstDate);
    final last = _dateOnly(lastDate);

final monthStart = _dateOnly(firstDate);
final monthEnd = _dateOnly(lastDate);

final snapshot = await FirebaseFirestore.instance
    .collection('bookings')
    .where('shopId', isEqualTo: shop['shopId'])
    .where('status', whereIn: ['pending', 'confirmed'])
    .get();

final bookings = snapshot.docs.map((doc) {
  final data = doc.data();

  final start = (data['startDate'] as Timestamp).toDate();
  final end = (data['endDate'] as Timestamp).toDate();

  // 🔥 用 Dart 自己過濾（關鍵）
  if (end.isBefore(monthStart) || start.isAfter(monthEnd)) {
    return null;
  }

  return data;
}).where((e) => e != null).cast<Map<String, dynamic>>().toList();

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

    if (end.isBefore(monthStart) || start.isAfter(monthEnd)) {
  continue;
}



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
  blockedDateReasons: blockedDateReasons,
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
    if (!tapped.isAfter(_tempStartDate!)) {

  /// 🔥 同一天 → 自動+1天（安全寫法）
  final sameDay =
      tapped.year == _tempStartDate!.year &&
      tapped.month == _tempStartDate!.month &&
      tapped.day == _tempStartDate!.day;

  if (sameDay) {

  final nextDay = _tempStartDate!.add(const Duration(days: 1));
  final payload = await _calendarFuture;

  if (payload != null) {
    final key = ShopService.instance.formatDateKey(nextDay);

    /// ❌ 隔天是關閉日
    if (payload.blockedDateKeys.contains(key)) {
      _showSnackBar('隔天為休息日，請重新選擇');

      setState(() {
        _tempStartDate = null;
        _tempEndDate = null;
      });

      return;
    }

    /// ❌ 隔天滿房
    if (payload.unbookableDateKeys.contains(key)) {
      _showSnackBar('隔天已滿房，請重新選擇');

      setState(() {
        _tempStartDate = null;
        _tempEndDate = null;
      });

      return;
    }
  }

  /// ✅ 正常才走這裡
  setState(() {
  _tempEndDate = nextDay;
  _rangeMessage = ''; // 🔥 清掉錯誤訊息
});

  print('👉 同一天自動+1天');
  return;
}

  /// 🔥 比開始早 → 重選開始
  setState(() {
  _tempStartDate = tapped;
  _tempEndDate = null;
  _rangeMessage = ''; // 🔥 清掉
});

  print('👉 重新選開始: $tapped');
  return;
}

/// 🔥 檢查區間內是否有不可預約
final payload = await _calendarFuture;

if (payload != null) {
  DateTime temp = _tempStartDate!;

  while (!temp.isAfter(tapped.subtract(const Duration(days: 1)))) {
    final key = ShopService.instance.formatDateKey(temp);

    /// ❌ 有關閉日
    if (payload.blockedDateKeys.contains(key)) {
      _showSnackBar('區間包含關閉日期');
      return;
    }

    /// ❌ 房滿
    if (payload.unbookableDateKeys.contains(key)) {
      _showSnackBar('區間包含已滿日期');
      return;
    }

    temp = temp.add(const Duration(days: 1));
  }
}

    /// 正常設定結束
    setState(() {
  _tempEndDate = tapped;
  _rangeMessage = ''; // 🔥 清掉
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

  Future<void> _submitBooking(
  Map<String, dynamic> shop, {
  String address = '',
  String emergencyName = '',
  String emergencyPhone = '',
  String relation = '',
  String emergencyAddress = '',
  String phone2 = '',
}) async {

// 🔥 建立店家會員（關鍵）
await MemberService.instance.ensureMember(
  shopId: widget.shopId,
);

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

/// 🔥 取得使用者（統一檢查）
final user = FirebaseAuth.instance.currentUser;
if (user == null) return;

/// 🔥 一次查詢（避免重複打 Firestore🔥）
final snapshot = await FirebaseFirestore.instance
    .collection('bookings')
    .where('userId', isEqualTo: user.uid)
    .where('status', whereIn: ['pending', 'confirmed'])
    .get();

/// 🔥 防重複預約（同寵物 + 時間重疊）
for (final doc in snapshot.docs) {
  final data = doc.data();

  final List bookedPetIds =
      List<String>.from(data['petIds'] ?? []);

  final start = (data['startDate'] as Timestamp).toDate();
  final end = (data['endDate'] as Timestamp).toDate();

  /// 同一隻寵物
  final hasSamePet =
      _selectedPetIds.any((id) => bookedPetIds.contains(id));

  /// 日期重疊
  final isOverlap =
      _startDate!.isBefore(end) && _endDate!.isAfter(start);

  if (hasSamePet && isOverlap) {
    _showSnackBar('該寵物已有未完成訂單，無法重複預約');
    return;
  }
}

/// 🔥 防刷訂單（最多3筆）
if (snapshot.docs.length >= 3) {
  _showSnackBar('您已有多筆未完成訂單，請先完成或取消後再預約');
  return;
}

/// 🔥 回寫會員資料（姓名 / 電話）
await FirebaseFirestore.instance
    .collection('user_profiles')
    .doc(user.uid)
    .set({
  'name': _customerNameController.text,
  'phone': _customerPhoneController.text,
  'address': address,

  /// 🚨 緊急聯絡人（完整）
  'emergencyContact': {
    'name': emergencyName,
    'phone': emergencyPhone,
    'relation': relation,
    'address': emergencyAddress,
    'phone2': phone2,
  },

  'updatedAt': FieldValue.serverTimestamp(),
}, SetOptions(merge: true));


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

  /// 🔥 新增（先給空）
address: address,
emergencyName: emergencyName,
emergencyPhone: emergencyPhone,

/// 🔥 新增
emergencyRelation: relation,
emergencyAddress: emergencyAddress,
emergencyPhone2: phone2,
);
      await BookingService.instance.updateBooking(
        bookingId: bookingId,
        totalPrice: totalPrice,
        pricePerNight: pricePerNight,
      );


      if (!mounted) return;

      Navigator.pushReplacement(
  context,
  MaterialPageRoute(
    builder: (_) => BookingSuccessPage(
      shopName: shop['name'] ?? '',
    ),
  ),
);
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
  setState(() {
    _rangeMessage = text;
  });
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
  _calendarFuture = _buildFrontCalendarPayload(
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
            if (snapshot.connectionState == ConnectionState.waiting) {
  return const Center(
    child: CircularProgressIndicator(),
  );
}

if (snapshot.hasError) {
  return Center(
    child: Text('日曆載入失敗：${snapshot.error}'),
  );
}

if (!snapshot.hasData) {
  return const Center(
    child: Text('沒有資料'),
  );
}

            final payload = snapshot.data!;

            return Dialog(
  insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
  child: Center( //
    child: SizedBox(
  height: MediaQuery.of(context).size.height * 0.95,
  width: MediaQuery.of(context).size.width * 0.9,
  child: SingleChildScrollView( // 🔥加這個
    child: Column(
        children: [

          /// 🔥 日曆
          BookingCalendar(

              key: ValueKey('${_tempStartDate}_${_tempEndDate}'),

              initialMonth: _calendarMonth,
              firstDate: today,
              lastDate: today.add(Duration(days: maxDays)),

              rangeStart: _tempStartDate,
              rangeEnd: _tempEndDate,

              blockedDateKeys: payload.blockedDateKeys,
              blockedDateReasons: payload.blockedDateReasons,
              unbookableDateKeys: payload.unbookableDateKeys,
              remainingRoomsMap: payload.remainingRoomsMap,
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

          

/// 🔥 顯示訊息區（新增）
if (_rangeMessage.isNotEmpty)
  Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    margin: const EdgeInsets.only(top: 8),
    decoration: BoxDecoration(
      color: Colors.grey.shade100,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
  children: [
    const Text(
      '⚠️ ',
      style: TextStyle(fontSize: 18),
    ),
    Expanded(
      child: Text(
        _rangeMessage,
        style: const TextStyle(
          fontSize: 16, // 🔥變大
          color: Colors.red, // 🔥變紅
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  ],
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

    /// 🔥 加這三行（關鍵）
    _rangeChecked = true;
    _rangeBookable = true;
    _rangeMessage = '';
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
  ),
);
          },
        );
      },
    );
  },
);
}


Widget _buildBookingSummary() {
  final totalPrice = BookingService.instance.calculateTotalPrice(
    roomType: _selectedRoomType!,
    startDate: _startDate!,
    endDate: _endDate!,
  );

  return Card(
    color: Colors.grey.shade100,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '預約確認',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 12),

          _infoRow('入住日', _formatDate(_startDate!)),
          const SizedBox(height: 6),

          _infoRow('退房日', _formatDate(_endDate!)),
          const SizedBox(height: 6),

          _infoRow('晚數', '$_nights 晚'),
          const SizedBox(height: 6),

          _infoRow('寵物數量', '${_selectedPetIds.length} 隻'),
          const SizedBox(height: 6),

          _infoRow('房型', _selectedRoomType!['name'] ?? ''),
          const SizedBox(height: 6),

          _infoRow('總價', 'NT\$ $totalPrice'),
        ],
      ),
    ),
  );
}

/// ===============================
/// 第三步：房型
/// ===============================
Widget _buildRoomTypeSection() {
  if (_startDate == null || _endDate == null) {
    return const SizedBox();
  }

// ❌ 沒選寵物 → 不顯示房型
if (_selectedPetIds.isEmpty) {
  return const Padding(
    padding: EdgeInsets.symmetric(vertical: 16),
    child: Text(
      '請先選擇入住寵物',
      style: TextStyle(color: Colors.red),
    ),
  );
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
                trailing: Column(
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    Text('NT\$ ${type['price']} / 晚'),

    const SizedBox(height: 4),

    Text(
      '共 NT\$ ${BookingService.instance.calculateTotalPrice(
        roomType: type,
        startDate: _startDate!,
        endDate: _endDate!,
      )}',
      style: const TextStyle(
        fontWeight: FontWeight.bold,
      ),
    ),
  ],
),
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
required this.blockedDateReasons,
required this.unbookableDateKeys,
    required this.priceMap,
    required this.remainingRoomsMap,
  });

  final Set<String> blockedDateKeys;
final Map<String, String> blockedDateReasons; // 🔥 新增
final Set<String> unbookableDateKeys;
final Map<String, int> priceMap;
final Map<String, int> remainingRoomsMap;
}