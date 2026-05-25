// lib/features/admin/pages/admin_create_booking_page.dart
// 🧾 後台手動新增訂單頁
// 功能：店家可搜尋會員，後續會接快速建立會員、建立寵物與建立訂單

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_calendar_dialog.dart';
import 'package:petnest_saas/features/shop/widgets/booking/front_calendar_helper.dart';
import 'package:petnest_saas/features/shop/widgets/booking/front_calendar_payload.dart';
import 'package:petnest_saas/features/shop/widgets/booking/booking_room_type_section.dart';
import 'package:petnest_saas/core/services/booking_service.dart';


class AdminCreateBookingPage extends StatefulWidget {
  const AdminCreateBookingPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  State<AdminCreateBookingPage> createState() => _AdminCreateBookingPageState();
}

class _AdminCreateBookingPageState extends State<AdminCreateBookingPage> {
  final TextEditingController _keywordController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  String _keyword = '';
  Map<String, dynamic>? _selectedMember;
  int _step = 0;
final Set<String> _selectedPetIds = <String>{};
DateTime? _startDate;
DateTime? _endDate;
DateTime? _tempStartDate;
DateTime? _tempEndDate;

DateTime _calendarMonth = DateTime.now();
Future<FrontCalendarPayload>? _calendarFuture;

String _rangeMessage = '';
String _adminOrderSource = '電話預約';
Map<String, dynamic>? _selectedRoomType;
bool _addonLoading = true;
Map<String, dynamic>? _addonData;

Map<String, dynamic>? _selectedTimeAddon;
List<Map<String, dynamic>> _selectedValueServices = [];
final Set<String> _selectedAddonNames = <String>{};
Map<String, List<String>> _selectedCustomServices = {};
List<Map<String, dynamic>> _pets = [];


@override
void initState() {
  super.initState();
  _loadAddons();
}

  @override
  void dispose() {
    _keywordController.dispose();
    _noteController.dispose();
    super.dispose();
  }

Future<void> _loadAddons() async {
  final doc = await FirebaseFirestore.instance
      .collection('shops')
      .doc(widget.shopId)
      .collection('addons')
.doc('main')
      .get();

  final data = doc.data();

  setState(() {
    _addonData = data;
    _addonLoading = false;
  });
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFCF7),
      appBar: AppBar(
        title: const Text('手動新增訂單'),
        backgroundColor: const Color(0xFFFFFCF7),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '第一步：選擇會員',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            '可輸入姓名或電話搜尋會員。沒有會員時，下一步會加入快速建立會員。',
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 16),

          TextField(
            controller: _keywordController,
            decoration: InputDecoration(
              hintText: '搜尋會員姓名 / 電話',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _keyword.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () async {
                        setState(() {
                          _keywordController.clear();
                          _keyword = '';
                          _selectedMember = null;
_selectedPetIds.clear();
_step = 0;
                        });
                      },
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onChanged: (value) {
              setState(() {
                _keyword = value.trim();
              });
            },
          ),

          const SizedBox(height: 12),

SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: _quickCreateMember,
    icon: const Icon(Icons.person_add_alt_1),
    label: const Text('沒有會員？快速建立會員'),
  ),
),

const SizedBox(height: 16),

if (_selectedMember != null) _selectedMemberCard(),
          const SizedBox(height: 16),

          if (_step == 0) _memberSearchResult(),

if (_step == 1) _petSection(),
if (_step == 2) _dateSection(),
if (_step == 3) _roomTypeSection(),
if (_step == 4) _addonSection(),
if (_step == 5) _confirmSection(),

const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
            onPressed: _selectedMember == null
    ? null
    : () {
        if (_step == 0) {
          setState(() {
            _step = 1;
          });
          return;
        }

        if (_step == 1) {
          if (_selectedPetIds.isEmpty) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('請至少選擇一隻寵物')),
            );
            return;
          }

          setState(() {
            _step = 2;
            _selectedRoomType = null;
          });
          return;
        }

        if (_step == 2) {
          if (_startDate == null || _endDate == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('請先選擇日期')),
            );
            return;
          }

          setState(() {
            _step = 3;
          });
          return;
        }

        if (_step == 3) {
  if (_selectedRoomType == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('請先選擇房型')),
    );
    return;
  }

  setState(() {
    _step = 4;
  });

  return;
}

if (_step == 4) {
  setState(() {
    _step = 5;
  });

  return;
}
if (_step == 5) {
  _submitBooking();
  return;
}
      },
              child: const Text('下一步'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selectedMemberCard() {
    final member = _selectedMember!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(16),
        
      ),
      child: Row(
        children: [
          const CircleAvatar(
            child: Icon(Icons.person),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member['name']?.toString().isNotEmpty == true
                      ? member['name'].toString()
                      : '未填姓名',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                  ),
                ),
                const SizedBox(height: 4),
                Text('電話：${member['phone'] ?? '未填'}'),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green),
        ],
      ),
    );
  }
Future<void> _quickCreateMember() async {
  final nameController = TextEditingController();
  final phoneController = TextEditingController(text: _keyword);
  final addressController = TextEditingController();
final emergencyNameController = TextEditingController();
final emergencyPhoneController = TextEditingController();
final emergencyRelationController = TextEditingController();
final emergencyAddressController = TextEditingController();

  final result = await showDialog<Map<String, String>>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('快速建立會員'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '會員姓名',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: '手機號碼',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),

TextField(
  controller: addressController,
  decoration: const InputDecoration(
    labelText: '地址',
    hintText: '例如：新竹縣新埔鎮...',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 12),

TextField(
  controller: emergencyNameController,
  decoration: const InputDecoration(
    labelText: '緊急聯絡人',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 12),

TextField(
  controller: emergencyPhoneController,
  keyboardType: TextInputType.phone,
  decoration: const InputDecoration(
    labelText: '緊急聯絡電話',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 12),

TextField(
  controller: emergencyRelationController,
  decoration: const InputDecoration(
    labelText: '關係',
    hintText: '例如：家人、朋友、配偶',
    border: OutlineInputBorder(),
  ),
),

const SizedBox(height: 12),

TextField(
  controller: emergencyAddressController,
  decoration: const InputDecoration(
    labelText: '緊急聯絡地址',
    border: OutlineInputBorder(),
  ),
),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
  onPressed: () async {
              final name = nameController.text.trim();
              final phone = phoneController.text.trim();
                            if (name.isEmpty || phone.isEmpty) return;
final exists = await FirebaseFirestore.instance
    .collection('user_profiles')
    .where('phone', isEqualTo: phone)
    .limit(1)
    .get();

if (exists.docs.isNotEmpty) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('此手機號碼已存在會員'),
      ),
    );
  }
  return;
}
              Navigator.pop(context, {
  'name': name,
  'phone': phone,
  'address': addressController.text.trim(),
  'emergencyName': emergencyNameController.text.trim(),
  'emergencyPhone': emergencyPhoneController.text.trim(),
  'emergencyRelation': emergencyRelationController.text.trim(),
  'emergencyAddress': emergencyAddressController.text.trim(),
});
            },
            child: const Text('建立'),
          ),
        ],
      );
    },
  );

  if (result == null) return;

  final doc = FirebaseFirestore.instance.collection('user_profiles').doc();

  await doc.set({
   'name': result['name'],
'phone': result['phone'],
'email': '',
'address': result['address'],
'emergencyContact': {
  'name': result['emergencyName'],
  'phone': result['emergencyPhone'],
  'relation': result['emergencyRelation'],
  'address': result['emergencyAddress'],
},
    'createdFrom': 'admin',
    'linkedAuthUid': null,
    'shopIds': [widget.shopId],
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

setState(() {
  _selectedMember = {
  'userId': doc.id,
  'name': result['name'],
  'phone': result['phone'],
  'email': '',
  'address': result['address'],
  'emergencyContact': {
    'name': result['emergencyName'],
    'phone': result['emergencyPhone'],
    'relation': result['emergencyRelation'],
    'address': result['emergencyAddress'],
  },
  };


    _keywordController.text = result['phone'] ?? '';
    _keyword = result['phone'] ?? '';
  });

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('已建立會員')),
  );
}

  Widget _memberSearchResult() {
    if (_keyword.isEmpty) {
      return const Text(
        '請先輸入姓名或電話搜尋會員',
        style: TextStyle(color: Colors.grey),
      );
    }

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('user_profiles')
          .limit(50)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.where((doc) {
  final data = doc.data() as Map<String, dynamic>;

  final name = data['name']?.toString() ?? '';
  final phone = data['phone']?.toString() ?? '';
  final linkedAuthUid =
      data['linkedAuthUid']?.toString() ?? '';

  final matched =
      name.contains(_keyword) || phone.contains(_keyword);

  /// 已綁定會員仍可顯示
  /// 但如果未來有 archived / merged 狀態，這裡會避開
  final isMerged =
      data['status'] == 'merged' ||
      data['isMerged'] == true;

  return matched && !isMerged;
}).toList();

        if (docs.isEmpty) {
          return const Text(
            '查無會員，下一步會加入快速建立會員',
            style: TextStyle(color: Colors.grey),
          );
        }

        return Column(
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              child: ListTile(
                leading: const CircleAvatar(
                  child: Icon(Icons.person),
                ),
                title: Text(
                  data['name']?.toString().isNotEmpty == true
                      ? data['name'].toString()
                      : '未填姓名',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Text('電話：${data['phone'] ?? '未填'}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() {
                    _selectedMember = {
  'userId': doc.id,
  ...data,
};
_selectedPetIds.clear();
_step = 0;
                  });
                },
              ),
            );
          }).toList(),
        );
      },
    );
  }
  Future<void> _quickCreatePet() async {
  final member = _selectedMember;
  if (member == null) return;

  final userId = member['userId']?.toString() ?? '';
  if (userId.isEmpty) return;

  final nameController = TextEditingController();
final breedController = TextEditingController();
final noteController = TextEditingController();

String type = 'cat';
String gender = '母貓';
String age = '未填';
String neuterStatus = '未結紮';
String medicalStatus = '未填';
String litterType = '未填';

  final result = await showDialog<Map<String, dynamic>>(
    context: context,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('快速建立寵物'),
            content: SingleChildScrollView(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    children: [
                TextField(
                  controller: nameController,
                  decoration: const InputDecoration(
                    labelText: '寵物名字',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),

TextField(
  controller: breedController,
  decoration: const InputDecoration(
    labelText: '品種',
    hintText: '例如：米克斯、英短、布偶',
    border: OutlineInputBorder(),
  ),
),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
  value: gender,
  decoration: const InputDecoration(
    labelText: '性別',
    border: OutlineInputBorder(),
  ),
  items: const [
    DropdownMenuItem(value: '公貓', child: Text('公貓')),
    DropdownMenuItem(value: '母貓', child: Text('母貓')),
    DropdownMenuItem(value: '未填', child: Text('未填')),
  ],
  onChanged: (value) {
    setDialogState(() {
      gender = value ?? '母貓';
    });
  },
),

const SizedBox(height: 12),

DropdownButtonFormField<String>(
  value: age,
  decoration: const InputDecoration(
    labelText: '年齡',
    border: OutlineInputBorder(),
  ),
  items: const [
    DropdownMenuItem(value: '未填', child: Text('未填')),
    DropdownMenuItem(value: '1歲以下', child: Text('1歲以下')),
    DropdownMenuItem(value: '1～3歲', child: Text('1～3歲')),
    DropdownMenuItem(value: '4～7歲', child: Text('4～7歲')),
    DropdownMenuItem(value: '8～11歲', child: Text('8～11歲')),
    DropdownMenuItem(value: '12歲以上', child: Text('12歲以上')),
  ],
  onChanged: (value) {
    setDialogState(() {
      age = value ?? '未填';
    });
  },
),

const SizedBox(height: 12),

DropdownButtonFormField<String>(
  value: neuterStatus,
  decoration: const InputDecoration(
    labelText: '結紮狀況',
    border: OutlineInputBorder(),
  ),
  items: const [
    DropdownMenuItem(value: '未結紮', child: Text('未結紮')),
    DropdownMenuItem(value: '已結紮', child: Text('已結紮')),
    DropdownMenuItem(value: '未填', child: Text('未填')),
  ],
  onChanged: (value) {
    setDialogState(() {
      neuterStatus = value ?? '未結紮';
    });
  },
),
const SizedBox(height: 12),

DropdownButtonFormField<String>(
  value: medicalStatus,
  decoration: const InputDecoration(
    labelText: '醫療狀況',
    border: OutlineInputBorder(),
  ),
  items: const [
    DropdownMenuItem(value: '未填', child: Text('未填')),
    DropdownMenuItem(value: '健康', child: Text('健康')),
    DropdownMenuItem(value: '糖尿病', child: Text('糖尿病')),
    DropdownMenuItem(value: '腎臟病', child: Text('腎臟病')),
    DropdownMenuItem(value: '需每日餵藥', child: Text('需每日餵藥')),
    DropdownMenuItem(value: '其他', child: Text('其他')),
  ],
  onChanged: (value) {
    setDialogState(() {
      medicalStatus = value ?? '未填';
    });
  },
),

const SizedBox(height: 12),

DropdownButtonFormField<String>(
  value: litterType,
  decoration: const InputDecoration(
    labelText: '貓砂種類',
    border: OutlineInputBorder(),
  ),
  items: const [
    DropdownMenuItem(value: '未填', child: Text('未填')),
    DropdownMenuItem(value: '豆腐砂', child: Text('豆腐砂')),
    DropdownMenuItem(value: '礦砂', child: Text('礦砂')),
    DropdownMenuItem(value: '木屑砂', child: Text('木屑砂')),
    DropdownMenuItem(value: '水晶砂', child: Text('水晶砂')),
  ],
  onChanged: (value) {
    setDialogState(() {
      litterType = value ?? '未填';
    });
  },
),

const SizedBox(height: 12),

TextField(
  controller: noteController,
  maxLines: 3,
  decoration: const InputDecoration(
    labelText: '其他備註',
    hintText: '例如：怕生、需注意飲食、固定餵藥時間...',
    border: OutlineInputBorder(),
  ),
),            
            ],
  ),
),
actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('取消'),
              ),
              ElevatedButton(
                onPressed: () {
                  final name = nameController.text.trim();

                  if (name.isEmpty) return;

                  Navigator.pop(context, {
  'name': name,
  'type': type,
  'breed': breedController.text.trim(),
  'gender': gender,
  'age': age,
  'isNeutered': neuterStatus == '已結紮',
  'vaccine': medicalStatus,
  'litterType': litterType,
  'note': noteController.text.trim(),
});
                },
                child: const Text('建立'),
              ),
            ],
          );
        },
      );
    },
  );

  if (result == null) return;

  final doc = FirebaseFirestore.instance
      .collection('user_profiles')
      .doc(userId)
      .collection('pets')
      .doc();

  await doc.set({
  'name': result['name'],
  'type': result['type'],
  'breed': result['breed'],
  'gender': result['gender'],
  'age': result['age'],
  'isNeutered': result['isNeutered'],
  'vaccine': result['vaccine'],
  'litterType': result['litterType'],
  'note': result['note'],
    'createdFrom': 'admin',
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  });

  setState(() {
  _selectedPetIds.add(doc.id);
  _pets.add({
  'petId': doc.id,
  'name': result['name'],
  'type': result['type'],
  'breed': result['breed'],
  'gender': result['gender'],
  'age': result['age'],
  'isNeutered': result['isNeutered'],
  'vaccine': result['vaccine'],
  'litterType': result['litterType'],
  'note': result['note'],
});
});

  if (!mounted) return;

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('已建立寵物')),
  );
}
  Widget _petSection() {
  final member = _selectedMember;
  if (member == null) return const SizedBox();

  final userId = member['userId']?.toString() ?? '';

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '第二步：選擇寵物',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),

      const SizedBox(height: 8),

      Text(
        '目前會員：${member['name'] ?? '未填姓名'}',
        style: const TextStyle(color: Colors.grey),
      ),

      const SizedBox(height: 16),

SizedBox(
  width: double.infinity,
  child: OutlinedButton.icon(
    onPressed: _quickCreatePet,
    icon: const Icon(Icons.add),
    label: const Text('新增寵物'),
  ),
),

const SizedBox(height: 12),

StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('user_profiles')
            .doc(userId)
            .collection('pets')
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final pets = snapshot.data!.docs;

          if (pets.isEmpty) {
            return Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: const Text('此會員目前沒有寵物，下一步會加入快速建立寵物。'),
            );
          }

          return Column(
            children: pets.map((doc) {
              final data = doc.data() as Map<String, dynamic>;

             final isSelected = _selectedPetIds.contains(doc.id);

return Card(
  margin: const EdgeInsets.only(bottom: 10),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
    side: BorderSide(
      color: isSelected ? Colors.green : Colors.transparent,
      width: 2,
    ),
  ),
  child: CheckboxListTile(
    value: isSelected,
    secondary: const CircleAvatar(
      child: Icon(Icons.pets),
    ),
    title: Text(data['name'] ?? '未命名寵物'),
    subtitle: Text(
      '${data['type'] ?? '未填種類'}｜${data['gender'] ?? '未填性別'}',
    ),
    onChanged: (value) {
  setState(() {
    if (value == true) {
      _selectedPetIds.add(doc.id);

      final exists = _pets.any(
        (p) => p['petId'] == doc.id,
      );

      if (!exists) {
        _pets.add({
          'petId': doc.id,
          ...data,
        });
      }
    } else {
      _selectedPetIds.remove(doc.id);
      _pets.removeWhere(
        (p) => p['petId'] == doc.id,
      );
    }
  });
},
  ),
);
            }).toList(),
          );
        },
      ),
    ],
  );
}
String _formatDate(DateTime date) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${date.year}-${two(date.month)}-${two(date.day)}';
}

DateTime _dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}

Future<FrontCalendarPayload> _buildFrontCalendarPayload({
  required Map<String, dynamic> shop,
  required DateTime firstDate,
  required DateTime lastDate,
}) {
  return FrontCalendarHelper.buildPayload(
    shopId: widget.shopId,
    shop: shop,
    firstDate: firstDate,
    lastDate: lastDate,
  );
}

Future<void> _openCalendarDialog(Map<String, dynamic> shop) async {
  final today = _dateOnly(DateTime.now());

  _tempStartDate = _startDate;
  _tempEndDate = _endDate;

  final firstDay = DateTime(_calendarMonth.year, _calendarMonth.month, 1);
  final lastDay = DateTime(_calendarMonth.year, _calendarMonth.month + 1, 0);

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
          return FutureBuilder<FrontCalendarPayload>(
            future: _calendarFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text('日曆載入失敗：${snapshot.error}'),
                );
              }

              if (!snapshot.hasData) {
                return const Center(child: Text('沒有資料'));
              }

              final payload = snapshot.data!;

              return BookingCalendarDialog(
                payload: payload,
                calendarMonth: _calendarMonth,
                today: today,
                maxDays: 365,
                tempStartDate: _tempStartDate,
                tempEndDate: _tempEndDate,
                rangeMessage: _rangeMessage,
                onMonthChanged: (newMonth) {
                  final firstDay = DateTime(
                    newMonth.year,
                    newMonth.month,
                    1,
                  );

                  final lastDay = DateTime(
                    newMonth.year,
                    newMonth.month + 1,
                    0,
                  );

                  setState(() {
                    _calendarMonth = newMonth;
                    _calendarFuture = _buildFrontCalendarPayload(
                      shop: shop,
                      firstDate: firstDay,
                      lastDate: lastDay,
                    );
                  });

                  setInnerState(() {});
                },
                onDayTap: (date) async {
                  _handleCalendarTap(date);
                  setInnerState(() {});
                },
                onCancel: () {
                  Navigator.pop(context);
                },
                onConfirm: () {
                  if (_tempStartDate == null || _tempEndDate == null) {
                    setState(() {
                      _rangeMessage = '請選擇入住日與退房日';
                    });
                    setInnerState(() {});
                    return;
                  }

                  setState(() {
                    _startDate = _tempStartDate;
                    _endDate = _tempEndDate;
                    _rangeMessage = '';
                  });

                  Navigator.pop(context);
                },
              );
            },
          );
        },
      );
    },
  );
}

void _handleCalendarTap(DateTime date) {
  final tapped = _dateOnly(date);

  if (_tempStartDate == null ||
      (_tempStartDate != null && _tempEndDate != null)) {
    setState(() {
      _tempStartDate = tapped;
      _tempEndDate = null;
      _rangeMessage = '';
    });
    return;
  }

  if (!tapped.isAfter(_tempStartDate!)) {
    setState(() {
      _tempStartDate = tapped;
      _tempEndDate = null;
      _rangeMessage = '';
    });
    return;
  }

  setState(() {
    _tempEndDate = tapped;
    _rangeMessage = '';
  });
}

Widget _dateSection() {
  return StreamBuilder<Map<String, dynamic>?>(
    stream: ShopService.instance.streamShop(widget.shopId),
    builder: (context, snapshot) {
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }

      final shop = snapshot.data;
      if (shop == null) {
        return const Text('找不到店家資料');
      }

      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '第三步：選擇日期',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 8),

          const Text(
            '使用前台同一套月曆，休假日、滿房、剩餘房數會一致。',
            style: TextStyle(color: Colors.grey),
          ),

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                _openCalendarDialog(shop);
              },
              icon: const Icon(Icons.calendar_month),
              label: Text(
                _startDate == null || _endDate == null
                    ? '選擇入住 / 退房日期'
                    : '${_formatDate(_startDate!)} ～ ${_formatDate(_endDate!)}',
              ),
            ),
          ),

          const SizedBox(height: 16),

          if (_startDate != null && _endDate != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Text(
                '已選擇：${_formatDate(_startDate!)} ～ ${_formatDate(_endDate!)}，共 ${_endDate!.difference(_startDate!).inDays} 晚',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      );
    },
  );
}
Widget _roomTypeSection() {
  if (_startDate == null || _endDate == null) {
    return const SizedBox();
  }

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      BookingRoomTypeSection(
        shopId: widget.shopId,
        startDate: _startDate,
        endDate: _endDate,
        selectedPetIds: _selectedPetIds.toList(),
        selectedRoomType: _selectedRoomType,
        onSelectRoomType: (roomType) {
          setState(() {
            _selectedRoomType = roomType;
          });
        },
      ),
    ],
  );
}

Widget _addonSection() {
  final valueServices = List<Map<String, dynamic>>.from(
    _addonData?['valueServices'] ?? [],
  );
  final timeOptions = List<Map<String, dynamic>>.from(
  _addonData?['timeOptions'] ?? [],
);
final customServices = List<Map<String, dynamic>>.from(
  _addonData?['customServices'] ?? [],
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
    final selected =
        _selectedTimeAddon?['label'] == label;

    return RadioListTile<String>(
      value: label,
      groupValue: _selectedTimeAddon?['label'],
      title: Text(label),
      subtitle: Text('NT\$ $price'),
      onChanged: (_) {
        setState(() {
          _selectedTimeAddon = {
            ...item,
            'name': label,
            'type': 'time',
            'count': 1,
            'total': price,
          };
        });
      },
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
    final serviceName =
        service['name']?.toString() ?? '';

    final price = service['price'] ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
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
              children: _pets.map((pet) {
                final petId = pet['petId']?.toString() ?? '';
final petName = pet['name']?.toString() ?? '';

                final selected =
                    (_selectedCustomServices[
                                serviceName] ??
                            [])
                        .contains(petId);

                return FilterChip(
                  label: Text(petName),
                  selected: selected,
                  onSelected: (value) {
                    setState(() {
                      _selectedCustomServices
                          .putIfAbsent(
                        serviceName,
                        () => [],
                      );

                      if (value) {
  if (!_selectedCustomServices[serviceName]!.contains(petId)) {
    _selectedCustomServices[serviceName]!.add(petId);
  }
} else {
                        _selectedCustomServices[
                                serviceName]!
                            .remove(petId);
                      }
                    });
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
      if (_addonLoading)
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
            final selected = _selectedAddonNames.contains(name);

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: CheckboxListTile(
                value: selected,
                title: Text(name),
                subtitle: Text('NT\$ $price'),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      _selectedAddonNames.add(name);
                      _selectedValueServices.add({
                        ...item,
                        'type': 'value',
                        'count': 1,
                        'total': price,
                      });
                    } else {
                      _selectedAddonNames.remove(name);
                      _selectedValueServices.removeWhere(
                        (e) => e['name'] == name,
                      );
                    }
                  });
                },
              ),
            );
          }).toList(),
        ),
    ],
  );
}

List<Map<String, dynamic>> _buildAdminAddons() {
  final addons = <Map<String, dynamic>>[];

if (_selectedTimeAddon != null) {
  addons.add({
    ..._selectedTimeAddon!,
  });
}

addons.addAll(
  _selectedValueServices.map((item) {
    final price = item['price'] ?? 0;

    return {
      'name': item['name'],
      'type': 'value',
      'price': price,
      'count': 1,
      'total': item['total'] ?? price,
    };
  }),
);

_selectedCustomServices.forEach((serviceName, petIds) {
  if (petIds.isEmpty) return;

  final service = List<Map<String, dynamic>>.from(
    _addonData?['customServices'] ?? [],
  ).firstWhere(
    (item) => item['name'] == serviceName,
    orElse: () => {},
  );

  final price = service['price'] ?? 0;

  addons.add({
    'name': serviceName,
    'type': 'custom',
    'price': price,
    'count': petIds.length,
    'total': price * petIds.length,
    'petNames': petIds.map((petId) {
  final pet = _pets.firstWhere(
    (p) => p['petId'] == petId,
    orElse: () => {},
  );

  return pet['name'] ?? petId;
}).toList(),
  });
});

return addons;
}

int _calculateAdminTotalPrice({
  required Map<String, dynamic> roomType,
  required int nights,
}) {
  final basePrice = (roomType['price'] ?? 0) as int;

  final extraPetPrice = (roomType['extraPrice'] ?? 0) as int;
  final extraPetCount =
      _selectedPetIds.length > 1 ? _selectedPetIds.length - 1 : 0;
  final extraPetTotal = extraPetPrice * extraPetCount * nights;

  final timeTotal = (_selectedTimeAddon?['total'] ?? 0) as int;

  final valueTotal = _selectedValueServices.fold<int>(
    0,
    (sum, item) => sum + ((item['total'] ?? 0) as int),
  );

  final customTotal = _selectedCustomServices.entries.fold<int>(
    0,
    (sum, entry) {
      final service = List<Map<String, dynamic>>.from(
        _addonData?['customServices'] ?? [],
      ).firstWhere(
        (item) => item['name'] == entry.key,
        orElse: () => {},
      );

      final price = (service['price'] ?? 0) as int;
      return sum + (price * entry.value.length);
    },
  );

  return (basePrice * nights) +
      extraPetTotal +
      timeTotal +
      valueTotal +
      customTotal;
}

Future<void> _submitBooking() async {
  final member = _selectedMember;
  final roomType = _selectedRoomType;

  if (member == null ||
      roomType == null ||
      _startDate == null ||
      _endDate == null) {
    return;
  }

  try {
    final nights = _endDate!.difference(_startDate!).inDays;

    await BookingService.instance.createAdminBooking(
      shopId: widget.shopId,
      userId: member['userId'] ?? '',
      customerName: member['name'] ?? '',
      customerPhone: member['phone'] ?? '',
      petIds: _selectedPetIds.toList(),

      serviceType: '住宿',

      startDate: _startDate!,
      endDate: _endDate!,
      nights: nights,

      roomId: roomType['roomTypeId'] ?? roomType['id'] ?? '',
      roomName: roomType['name'] ?? '',
      roomTypeName: roomType['name'] ?? '',

      basePrice: (roomType['price'] ?? 0) as int,
     extraPetPrice: (roomType['extraPrice'] ?? 0) as int,
extraPetCount: _selectedPetIds.length > 1
    ? _selectedPetIds.length - 1
    : 0,
extraPetTotal: ((roomType['extraPrice'] ?? 0) as int) *
    (_selectedPetIds.length > 1 ? _selectedPetIds.length - 1 : 0) *
    nights, 
      roomSubtotal: (roomType['price'] ?? 0) * nights,

      roomImages: roomType['images'] ?? [],

      totalPrice: _calculateAdminTotalPrice(
  roomType: roomType,
  nights: nights,
),

addons: _buildAdminAddons(),
note: '手動新增訂單｜$_adminOrderSource'
    '${_noteController.text.trim().isEmpty ? '' : '｜${_noteController.text.trim()}'}',
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('訂單建立成功')),
    );

    Navigator.pop(context);
  } catch (e) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('建立失敗：$e')),
    );
  }
}

Widget _confirmSection() {
  final member = _selectedMember;
  final roomType = _selectedRoomType;

  if (member == null ||
      roomType == null ||
      _startDate == null ||
      _endDate == null) {
    return const SizedBox();
  }

  final nights = _endDate!.difference(_startDate!).inDays;
  final roomName = roomType['name']?.toString() ?? '未選房型';
  final price = roomType['price'] ?? 0;
  final extraPetPrice = roomType['extraPrice'] ?? 0;
final extraPetCount = _selectedPetIds.length > 1
    ? _selectedPetIds.length - 1
    : 0;
final extraPetTotal = extraPetPrice * extraPetCount * nights;
  final valueAddonTotal = _selectedValueServices.fold<int>(
  0,
  (sum, item) => sum + ((item['total'] ?? 0) as int),
);

final timeAddonTotal =
    (_selectedTimeAddon?['total'] ?? 0) as int;

final customAddonTotal = _selectedCustomServices.entries.fold<int>(
  0,
  (sum, entry) {
    final service = List<Map<String, dynamic>>.from(
      _addonData?['customServices'] ?? [],
    ).firstWhere(
      (item) => item['name'] == entry.key,
      orElse: () => {},
    );

    final price = service['price'] ?? 0;
    return sum + ((price as int) * entry.value.length);
  },
);

final addonTotal =
    valueAddonTotal + timeAddonTotal + customAddonTotal;

final totalPrice = (price * nights) + extraPetTotal + addonTotal;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const Text(
        '第六步：確認資料',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w900,
        ),
      ),

      const SizedBox(height: 8),

      const Text(
        '確認資料無誤後，下一步會建立訂單並鎖房。',
        style: TextStyle(color: Colors.grey),
      ),

DropdownButtonFormField<String>(
  value: _adminOrderSource,
  decoration: InputDecoration(
    labelText: '下單方式',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
    ),
  ),
  items: const [
    DropdownMenuItem(value: '電話預約', child: Text('電話預約')),
    DropdownMenuItem(value: 'LINE 預約', child: Text('LINE 預約')),
    DropdownMenuItem(value: '現場預約', child: Text('現場預約')),
    DropdownMenuItem(value: '其他', child: Text('其他')),
  ],
  onChanged: (value) {
    setState(() {
      _adminOrderSource = value ?? '電話預約';
    });
  },
),

const SizedBox(height: 12),

TextField(
  controller: _noteController,
  maxLines: 3,
  decoration: InputDecoration(
    labelText: '訂單備註',
    hintText: '例如：電話預約、LINE 預約、已口頭確認、特殊照顧事項',
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
    ),
  ),
),

const SizedBox(height: 16),

      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _confirmRow('會員', member['name'] ?? '未填姓名'),
            _confirmRow('電話', member['phone'] ?? '未填電話'),
            _confirmRow('寵物數', '${_selectedPetIds.length} 隻'),
            _confirmRow(
              '日期',
              '${_formatDate(_startDate!)} ～ ${_formatDate(_endDate!)}',
            ),
            _confirmRow('晚數', '$nights 晚'),
            _confirmRow('房型', roomName),
            _confirmRow('房型單價', 'NT\$ $price'),
            if (extraPetCount > 0)
  _confirmRow(
    '寵物加價',
    'NT\$ $extraPetPrice × $extraPetCount 隻 × $nights 晚 = NT\$ $extraPetTotal',
  ),
            if (_selectedTimeAddon != null)
  _confirmRow(
    '時間加購',
    '${_selectedTimeAddon!['name']} / NT\$ $timeAddonTotal',
  ),
  if (_selectedCustomServices.isNotEmpty)
  ..._selectedCustomServices.entries.map((entry) {
    final serviceName = entry.key;
    final count = entry.value.length;

    if (count <= 0) {
      return const SizedBox();
    }

    final service = List<Map<String, dynamic>>.from(
      _addonData?['customServices'] ?? [],
    ).firstWhere(
      (item) => item['name'] == serviceName,
      orElse: () => {},
    );

    final price = service['price'] ?? 0;
    final total = price * count;

    return _confirmRow(
      '客製化服務',
      '$serviceName / $count 隻 / NT\$ $total',
    );
  }),
            if (_selectedValueServices.isNotEmpty)
  ..._selectedValueServices.map((item) {
    final name = item['name']?.toString() ?? '加值服務';
    final total = item['total'] ?? item['price'] ?? 0;

    return _confirmRow(
      '加值服務',
      '$name / NT\$ $total',
    );
  }),

if (addonTotal > 0)
  _confirmRow('加值服務小計', 'NT\$ $addonTotal'),
_confirmRow('總金額', 'NT\$ $totalPrice'),
          ],
        ),
      ),
    ],
  );
}


Widget _confirmRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    ),
  );
}
}