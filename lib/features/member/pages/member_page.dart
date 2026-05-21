// lib/features/member/pages/member_page.dart
// 👤 會員中心頁（完整版：含電話輸入）

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/services/pet_service.dart';
import 'package:petnest_saas/features/pet/pages/pet_detail_page.dart';
import 'package:petnest_saas/features/pet/pages/add_pet_page.dart';
import 'package:petnest_saas/features/booking/pages/my_bookings_page.dart';
import 'package:petnest_saas/core/constants/taiwan_city_data.dart';

class MemberPage extends StatefulWidget {
  const MemberPage({super.key});

  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();

String? _city;
String? _district;
final TextEditingController _detailAddressController = TextEditingController();
final TextEditingController _nameController = TextEditingController();


/// 🚨 緊急聯絡人
final TextEditingController _emergencyNameController = TextEditingController();
final TextEditingController _emergencyPhoneController = TextEditingController();
final TextEditingController _emergencyRelationController = TextEditingController();
final TextEditingController _emergencyAddressController = TextEditingController();


bool _sameAsOwner = false;
bool _editingProfile = false;
bool _editingAddress = false;
bool _editingEmergency = false;

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
  title: const Text('會員中心'),
),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
  key: _formKey,
  child: user == null
            ? const Center(child: Text('尚未登入'))
            : StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('user_profiles')
                    .doc(user.uid)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  }

                  final data =
                      snapshot.data!.data() as Map<String, dynamic>?;

                  final phone = data?['phone'] ?? '';
                  if (_nameController.text.isEmpty) {
  _nameController.text = data?['name'] ?? '';
}

                  final address = data?['address'] ?? '';
                  // 🔥 拆地址（會員 → UI）
if (address.isNotEmpty && _city == null) {
  final cityList = [
    '台北市','新北市','桃園市','台中市','台南市','高雄市',
    '新竹縣','苗栗縣','彰化縣','南投縣','雲林縣','嘉義縣',
    '屏東縣','宜蘭縣','花蓮縣','台東縣','澎湖縣','金門縣','連江縣'
  ];

  for (final city in cityList) {
    if (address.startsWith(city)) {
      _city = city;

      final districts = cityData[city] ?? [];

      for (final d in districts) {
        if (address.contains(d)) {
          _district = d;
          break;
        }
      }

      break;
    }
  }

  if (_detailAddressController.text.isEmpty) {
  String detail = address;

  if (_city != null && detail.startsWith(_city!)) {
    detail = detail.replaceFirst(_city!, '');
  }

  if (_district != null && detail.startsWith(_district!)) {
    detail = detail.replaceFirst(_district!, '');
  }

  _detailAddressController.text = detail;
}
} // ✅ 這個一定要有
final emergency = data?['emergencyContact'];

if (emergency != null && !_sameAsOwner) {
  if (_emergencyNameController.text.isEmpty) {
    _emergencyNameController.text = emergency['name'] ?? '';
  }
  if (_emergencyPhoneController.text.isEmpty) {
    _emergencyPhoneController.text = emergency['phone'] ?? '';
  }
  if (_emergencyRelationController.text.isEmpty) {
    _emergencyRelationController.text = emergency['relation'] ?? '';
  }
  if (_emergencyAddressController.text.isEmpty) {
    _emergencyAddressController.text = emergency['address'] ?? '';
  }
}

                  /// 🔥 讓欄位帶入初始值（避免覆蓋輸入）
                  if (_phoneController.text.isEmpty) {
  _phoneController.text = phone;
}
                  return SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [

                        if (_editingProfile ||
    _editingAddress ||
    _editingEmergency)
  Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.amber.shade50,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(
        color: Colors.amber.shade200,
      ),
    ),
    child: Row(
      children: [
        Icon(
          Icons.warning_amber_rounded,
          color: Colors.amber.shade800,
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            '你有尚未儲存的資料，記得按下方「儲存資料」',
            style: TextStyle(
              color: Colors.amber.shade900,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ),
  ),

                       _buildSectionCard(
  title: '我的資料',
  children: [
    if (!_editingProfile) ...[
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: Colors.blue.shade50,
          child: const Icon(Icons.person),
        ),
        title: Text(
          _nameController.text.isEmpty
              ? '尚未填寫姓名'
              : _nameController.text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Text(
          '${_phoneController.text}\n${user.email ?? ''}',
        ),
        isThreeLine: true,
        trailing: TextButton.icon(
          onPressed: () {
            setState(() {
              _editingProfile = true;
            });
          },
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('編輯'),
        ),
      ),
    ] else ...[
      Text(
        'Email：${user.email ?? ''}',
        style: TextStyle(
          color: Colors.grey.shade700,
        ),
      ),

      const SizedBox(height: 12),

      TextFormField(
        controller: _nameController,
        decoration: const InputDecoration(
          labelText: '飼主姓名',
          border: OutlineInputBorder(),
        ),
        validator: (v) => v!.isEmpty ? '請輸入姓名' : null,
      ),

      const SizedBox(height: 12),

      TextFormField(
        controller: _phoneController,
        decoration: const InputDecoration(
          labelText: '電話',
          border: OutlineInputBorder(),
        ),
        validator: (v) => v!.isEmpty ? '請輸入電話' : null,
      ),

      const SizedBox(height: 12),

      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () {
            setState(() {
  _editingProfile = false;
  _editingAddress = false;
  _editingEmergency = false;
});
          },
          icon: const Icon(Icons.close),
          label: const Text('取消編輯'),
        ),
      ),
    ],
  ],
),

_buildSectionCard(
  title: '地址資料',
  children: [
    if (!_editingAddress) ...[
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: Colors.green.shade50,
          child: const Icon(Icons.location_on),
        ),
        title: const Text(
          '地址',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Text(
          '${_city ?? ''}${_district ?? ''}${_detailAddressController.text}',
        ),
        trailing: TextButton.icon(
          onPressed: () {
            setState(() {
              _editingAddress = true;
            });
          },
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('編輯'),
        ),
      ),
    ] else ...[
      DropdownButtonFormField<String>(
        value: _city,
        decoration: const InputDecoration(
          labelText: '縣市',
          border: UnderlineInputBorder(),
        ),
        items: cityData.keys.map((city) {
          return DropdownMenuItem(
            value: city,
            child: Text(city),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _city = value;
            _district = null;
          });
        },
      ),

      const SizedBox(height: 16),

      DropdownButtonFormField<String>(
        value: _district,
        decoration: const InputDecoration(
          labelText: '區域',
          border: UnderlineInputBorder(),
        ),
        items: (_city == null ? <String>[] : cityData[_city]!)
            .map<DropdownMenuItem<String>>((d) {
          return DropdownMenuItem<String>(
            value: d,
            child: Text(d),
          );
        }).toList(),
        onChanged: (value) {
          setState(() {
            _district = value;
          });
        },
      ),

      const SizedBox(height: 16),

      TextFormField(
        controller: _detailAddressController,
        decoration: const InputDecoration(
          labelText: '詳細地址',
          border: OutlineInputBorder(),
        ),
        validator: (v) => v!.isEmpty ? '請輸入地址' : null,
      ),

      const SizedBox(height: 12),

      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () {
            setState(() {
  _editingProfile = false;
  _editingAddress = false;
  _editingEmergency = false;
});
          },
          icon: const Icon(Icons.close),
          label: const Text('取消編輯'),
        ),
      ),
    ],
  ],
),

_buildSectionCard(
  title: '緊急聯絡人',
  children: [
    if (!_editingEmergency) ...[
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 26,
          backgroundColor: Colors.red.shade50,
          child: const Icon(Icons.emergency),
        ),
        title: Text(
          _emergencyNameController.text.isEmpty
              ? '尚未填寫緊急聯絡人'
              : _emergencyNameController.text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        subtitle: Text(
          '${_emergencyRelationController.text}\n${_emergencyPhoneController.text}',
        ),
        isThreeLine: true,
        trailing: TextButton.icon(
          onPressed: () {
            setState(() {
              _editingEmergency = true;
            });
          },
          icon: const Icon(Icons.edit, size: 18),
          label: const Text('編輯'),
        ),
      ),
    ] else ...[
      TextField(
        controller: _emergencyNameController,
        decoration: const InputDecoration(
          labelText: '姓名',
          border: OutlineInputBorder(),
        ),
      ),

      const SizedBox(height: 16),

      TextField(
        controller: _emergencyPhoneController,
        decoration: const InputDecoration(
          labelText: '電話',
          border: OutlineInputBorder(),
        ),
      ),

      const SizedBox(height: 16),

      TextField(
        controller: _emergencyRelationController,
        decoration: const InputDecoration(
          labelText: '關係',
          border: OutlineInputBorder(),
        ),
      ),

      const SizedBox(height: 16),

      Row(
        children: [
          Checkbox(
            value: _sameAsOwner,
            onChanged: (value) {
              setState(() {
                _sameAsOwner = value ?? false;

                if (_sameAsOwner) {
                  String detail =
                      _detailAddressController.text.trim();

                  if (_city != null &&
                      detail.startsWith(_city!)) {
                    detail = detail.replaceFirst(_city!, '');
                  }

                  if (_district != null &&
                      detail.startsWith(_district!)) {
                    detail = detail.replaceFirst(_district!, '');
                  }

                  final fullAddress =
                      '${_city ?? ''}${_district ?? ''}$detail';

                  _emergencyAddressController.text =
                      fullAddress;
                } else {
                  _emergencyAddressController.text = '';
                }
              });
            },
          ),
          const Text('地址與飼主相同'),
        ],
      ),

      const SizedBox(height: 8),

      TextField(
        controller: _emergencyAddressController,
        decoration: const InputDecoration(
          labelText: '地址',
          border: OutlineInputBorder(),
        ),
      ),

      const SizedBox(height: 12),

      Align(
        alignment: Alignment.centerRight,
        child: TextButton.icon(
          onPressed: () {
            setState(() {
              _editingEmergency = false;
            });
          },
          icon: const Icon(Icons.close),
          label: const Text('取消編輯'),
        ),
      ),
    ],
  ],
),
                        SizedBox(
  width: double.infinity,
  child: ElevatedButton(
    onPressed: () async {

  /// 🔥 這行一定要加（觸發紅字）
  if (!_formKey.currentState!.validate()) {
    return;
  }

  /// （你原本的必填判斷可以刪掉或留著都可以）

  /// ✅ 必填鎖（全部欄位）
  if (_nameController.text.trim().isEmpty ||
      _phoneController.text.trim().isEmpty ||
      _city == null ||
      _district == null ||
      _detailAddressController.text.trim().isEmpty ||
      _emergencyNameController.text.trim().isEmpty ||
      _emergencyPhoneController.text.trim().isEmpty ||
      _emergencyRelationController.text.trim().isEmpty ||
      _emergencyAddressController.text.trim().isEmpty) {

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('請填寫所有必填欄位')),
    );
    return;
  }
      final fullAddress =
          '${_city ?? ''}${_district ?? ''}${_detailAddressController.text}';

      await FirebaseFirestore.instance
          .collection('user_profiles')
          .doc(user.uid)
          .set({
        'name': _nameController.text.trim(),   
        'phone': _phoneController.text.trim(),
        'address': fullAddress,

        /// 🚨 緊急聯絡人
        'emergencyContact': {
          'name': _emergencyNameController.text.trim(),
          'phone': _emergencyPhoneController.text.trim(),
          'relation': _emergencyRelationController.text.trim(),
          'address': _emergencyAddressController.text.trim(),
        },

        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (context.mounted) {

  setState(() {
    _editingProfile = false;
  });

  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(content: Text('已儲存')),
  );
}
    },
    child: const Text('儲存資料'),
  ),
),

                        const SizedBox(height: 20),

                        _buildSectionCard(
  title: '我的寵物',
  children: [

    Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Text(
      '管理你的寵物資料',
      style: TextStyle(
        color: Colors.grey.shade600,
        fontWeight: FontWeight.w600,
      ),
    ),
    FilledButton.tonalIcon(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => const AddPetPage(),
          ),
        );
      },
      icon: const Icon(Icons.add),
      label: const Text('新增'),
    ),
  ],
),

const SizedBox(height: 12),

    StreamBuilder<List<Map<String, dynamic>>>(
      stream: PetService.instance.streamMyPets(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const CircularProgressIndicator();
        }

        final pets = snapshot.data!;

        if (pets.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Text('尚未新增寵物'),
            ),
          );
        }

        return Column(
          children: pets.map((pet) {
            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.all(12),

                leading: CircleAvatar(
                  radius: 28,
                  backgroundImage:
                      pet['photoUrl'] != null &&
                              pet['photoUrl']
                                  .toString()
                                  .isNotEmpty
                          ? NetworkImage(
                              pet['photoUrl'],
                            )
                          : null,
                  child: (pet['photoUrl'] == null ||
                          pet['photoUrl']
                              .toString()
                              .isEmpty)
                      ? const Icon(Icons.pets)
                      : null,
                ),

                title: Text(
                  pet['name'] ?? '未命名',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                subtitle: Text(
                  pet['type'] ?? '',
                ),

                trailing: const Icon(
                  Icons.chevron_right,
                ),

                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) =>
                          PetDetailPage(pet: pet),
                    ),
                  );
                },
              ),
            );
          }).toList(),
        );
      },
    ),
  ],
),

                        const SizedBox(height: 24),


_buildSectionCard(
  title: '訂單中心',
  children: [
    ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: Colors.blue.shade50,
        child: const Icon(Icons.receipt_long),
      ),
      title: const Text(
        '我的訂單',
        style: TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: const Text('查看所有預約紀錄與付款狀態'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
  builder: (_) => const MyBookingsPage(),
),
        );
      },
    ),
  ],
),
                      ],
                    ),
                  );
                },
              ),
      ),
      ),
    );
  }

Widget _buildSectionCard({
  required String title,
  required List<Widget> children,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}
}