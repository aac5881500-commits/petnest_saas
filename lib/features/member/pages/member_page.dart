// lib/features/member/pages/member_page.dart
// 👤 會員中心頁（完整版：含電話輸入）

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/services/pet_service.dart';
import 'package:petnest_saas/features/pet/pages/pet_detail_page.dart';
import 'package:petnest_saas/features/pet/pages/add_pet_page.dart';
import 'package:petnest_saas/features/booking/pages/booking_detail_page_backup.dart';
import 'package:petnest_saas/features/member/pages/member_booking_page.dart';
import 'package:petnest_saas/features/booking/pages/my_bookings_page.dart';

class MemberPage extends StatefulWidget {
  const MemberPage({super.key});

  @override
  State<MemberPage> createState() => _MemberPageState();
}

class _MemberPageState extends State<MemberPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _phoneController = TextEditingController();
final TextEditingController _addressController = TextEditingController();
String? _city;
String? _district;
final TextEditingController _detailAddressController = TextEditingController();
final TextEditingController _nameController = TextEditingController();


/// 🚨 緊急聯絡人
final TextEditingController _emergencyNameController = TextEditingController();
final TextEditingController _emergencyPhoneController = TextEditingController();
final TextEditingController _emergencyRelationController = TextEditingController();
final TextEditingController _emergencyAddressController = TextEditingController();
final TextEditingController _phone2Controller = TextEditingController();
bool _sameAsOwner = false;
final Map<String, List<String>> cityData = {
  '台北市': ['中正區','大同區','中山區','松山區','大安區','萬華區','信義區','士林區','北投區','內湖區','南港區','文山區'],
  '新北市': ['板橋區','新莊區','中和區','永和區','土城區','樹林區','三重區','蘆洲區','新店區','汐止區','淡水區','三峽區','鶯歌區','五股區','泰山區','林口區','深坑區','石碇區','坪林區','三芝區','石門區','八里區','平溪區','雙溪區','貢寮區','金山區','萬里區','烏來區'],
  '桃園市': ['桃園區','中壢區','平鎮區','八德區','龜山區','蘆竹區','大溪區','楊梅區','大園區','觀音區','新屋區','龍潭區','復興區'],
  '台中市': ['中區','東區','南區','西區','北區','北屯區','西屯區','南屯區','太平區','大里區','霧峰區','烏日區','豐原區','后里區','石岡區','東勢區','新社區','潭子區','大雅區','神岡區','大肚區','沙鹿區','龍井區','梧棲區','清水區','大甲區','外埔區','大安區','和平區'],
  '台南市': ['中西區','東區','南區','北區','安平區','安南區','永康區','歸仁區','新化區','左鎮區','玉井區','楠西區','南化區','仁德區','關廟區','龍崎區','官田區','麻豆區','佳里區','西港區','七股區','將軍區','學甲區','北門區','新營區','後壁區','白河區','東山區','六甲區','下營區','柳營區','鹽水區','善化區','大內區','山上區','新市區','安定區'],
  '高雄市': ['新興區','前金區','苓雅區','鹽埕區','鼓山區','旗津區','前鎮區','三民區','楠梓區','小港區','左營區','仁武區','大社區','岡山區','路竹區','阿蓮區','田寮區','燕巢區','橋頭區','梓官區','彌陀區','永安區','湖內區','鳳山區','大寮區','林園區','鳥松區','大樹區','旗山區','美濃區','六龜區','內門區','杉林區','甲仙區','桃源區','那瑪夏區','茂林區','茄萣區'],
  '新竹縣': ['竹北市','竹東鎮','新埔鎮','關西鎮','湖口鄉','新豐鄉','芎林鄉','橫山鄉','北埔鄉','寶山鄉','峨眉鄉','尖石鄉','五峰鄉'],
  '苗栗縣': ['苗栗市','苑裡鎮','通霄鎮','竹南鎮','頭份市','後龍鎮','卓蘭鎮','大湖鄉','公館鄉','銅鑼鄉','南庄鄉','頭屋鄉','三義鄉','西湖鄉','造橋鄉','三灣鄉','獅潭鄉','泰安鄉'],
  '彰化縣': ['彰化市','鹿港鎮','和美鎮','線西鄉','伸港鄉','福興鄉','秀水鄉','花壇鄉','芬園鄉','員林市','溪湖鎮','田中鎮','大村鄉','埔鹽鄉','埔心鄉','永靖鄉','社頭鄉','二水鄉','北斗鎮','二林鎮','田尾鄉','埤頭鄉','芳苑鄉','大城鄉','竹塘鄉','溪州鄉'],
  '南投縣': ['南投市','埔里鎮','草屯鎮','竹山鎮','集集鎮','名間鄉','鹿谷鄉','中寮鄉','魚池鄉','國姓鄉','水里鄉','信義鄉','仁愛鄉'],
  '雲林縣': ['斗六市','斗南鎮','虎尾鎮','西螺鎮','土庫鎮','北港鎮','古坑鄉','大埤鄉','莿桐鄉','林內鄉','二崙鄉','崙背鄉','麥寮鄉','東勢鄉','褒忠鄉','台西鄉','元長鄉','四湖鄉','口湖鄉','水林鄉'],
  '嘉義縣': ['太保市','朴子市','布袋鎮','大林鎮','民雄鄉','溪口鄉','新港鄉','六腳鄉','東石鄉','義竹鄉','鹿草鄉','水上鄉','中埔鄉','竹崎鄉','梅山鄉','番路鄉','大埔鄉','阿里山鄉'],
  '嘉義市': ['東區','西區'],
  '屏東縣': ['屏東市','潮州鎮','東港鎮','恆春鎮','萬丹鄉','長治鄉','麟洛鄉','九如鄉','里港鄉','鹽埔鄉','高樹鄉','萬巒鄉','內埔鄉','竹田鄉','新埤鄉','枋寮鄉','新園鄉','崁頂鄉','林邊鄉','南州鄉','佳冬鄉','琉球鄉','車城鄉','滿州鄉','枋山鄉','三地門鄉','霧台鄉','瑪家鄉','泰武鄉','來義鄉','春日鄉','獅子鄉','牡丹鄉'],
  '宜蘭縣': ['宜蘭市','羅東鎮','蘇澳鎮','頭城鎮','礁溪鄉','壯圍鄉','員山鄉','冬山鄉','五結鄉','三星鄉','大同鄉','南澳鄉'],
  '花蓮縣': ['花蓮市','鳳林鎮','玉里鎮','新城鄉','吉安鄉','壽豐鄉','光復鄉','豐濱鄉','瑞穗鄉','富里鄉','秀林鄉','萬榮鄉','卓溪鄉'],
  '台東縣': ['台東市','成功鎮','關山鎮','卑南鄉','鹿野鄉','池上鄉','東河鄉','長濱鄉','太麻里鄉','大武鄉','綠島鄉','海端鄉','延平鄉','金峰鄉','達仁鄉','蘭嶼鄉'],
  '澎湖縣': ['馬公市','湖西鄉','白沙鄉','西嶼鄉','望安鄉','七美鄉'],
  '金門縣': ['金城鎮','金湖鎮','金沙鎮','金寧鄉','烈嶼鄉','烏坵鄉'],
  '連江縣': ['南竿鄉','北竿鄉','莒光鄉','東引鄉'],
};

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

                        /// Email
                        Text('Email：${user.email ?? ''}'),
                        const SizedBox(height: 12),

TextFormField(
  controller: _nameController,
  decoration: const InputDecoration(
    labelText: '飼主姓名',
    border: OutlineInputBorder(),
  ),
  validator: (v) => v!.isEmpty ? '請輸入姓名' : null,
),


                        /// 🔥 電話輸入
                        TextFormField(
  controller: _phoneController,
  decoration: const InputDecoration(
    labelText: '電話',
    border: OutlineInputBorder(),
  ),
  validator: (v) => v!.isEmpty ? '請輸入電話' : null,
),

const Text('地址', style: TextStyle(fontWeight: FontWeight.bold)),
const SizedBox(height: 8),

DropdownButtonFormField<String>(
  value: _city,
  hint: const Text('選擇縣市'),
  items: [
    '台北市','新北市','桃園市','台中市','台南市','高雄市',
    '新竹縣','苗栗縣','彰化縣','南投縣','雲林縣','嘉義縣',
    '屏東縣','宜蘭縣','花蓮縣','台東縣'
  ].map((city) {
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

const SizedBox(height: 8),

DropdownButtonFormField<String>(
  value: _district,
  hint: const Text('選擇區域'),
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

const SizedBox(height: 8),

TextFormField(
  controller: _detailAddressController,
  decoration: const InputDecoration(
    labelText: '詳細地址',
    border: OutlineInputBorder(),
  ),
  validator: (v) => v!.isEmpty ? '請輸入地址' : null,
),

const SizedBox(height: 24),

const Text(
  '緊急聯絡人',
  style: TextStyle(fontWeight: FontWeight.bold),
),

const SizedBox(height: 8),

TextField(
  controller: _emergencyNameController,
  decoration: const InputDecoration(labelText: '姓名'),
),

const SizedBox(height: 16),

TextField(
  controller: _emergencyPhoneController,
  decoration: const InputDecoration(labelText: '電話'),
),

const SizedBox(height: 16),

TextField(
  controller: _emergencyRelationController,
  decoration: const InputDecoration(labelText: '關係'),
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
        String detail = _detailAddressController.text.trim();

/// 🔥 防止使用者貼完整地址
if (_city != null && detail.startsWith(_city!)) {
  detail = detail.replaceFirst(_city!, '');
}

if (_district != null && detail.startsWith(_district!)) {
  detail = detail.replaceFirst(_district!, '');
}

final fullAddress =
    '${_city ?? ''}${_district ?? ''}$detail';
        _emergencyAddressController.text = fullAddress;
      } else {
        /// 🔥 取消勾選 → 強制清空
        _emergencyAddressController.text = '';
      }
    });
  },
),
    const Text('地址與飼主相同'),
  ],
),

TextField(
  controller: _emergencyAddressController,
  decoration: const InputDecoration(labelText: '地址'),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('已儲存')),
        );
      }
    },
    child: const Text('儲存資料'),
  ),
),

                        const SizedBox(height: 20),

                        /// 🔥 寵物標題 + 新增
                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              '寵物',
                              style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold),
                            ),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        const AddPetPage(),
                                  ),
                                );
                              },
                              child: const Text('新增'),
                            ),
                          ],
                        ),

                        const SizedBox(height: 8),

                        /// 🔥 寵物列表
                        StreamBuilder<
                            List<Map<String, dynamic>>>(
                          stream:
                              PetService.instance.streamMyPets(),
                          builder: (context, snapshot) {
                            if (!snapshot.hasData) {
                              return const CircularProgressIndicator();
                            }

                            final pets = snapshot.data!;

                            if (pets.isEmpty) {
                              return const Text('尚未新增寵物');
                            }

                            return Column(
                              children: pets.map((pet) {
                                return Card(
                                  child: ListTile(
                                    leading: CircleAvatar(
                                      radius: 24,
                                      backgroundImage:
                                          pet['photoUrl'] != null &&
                                                  pet['photoUrl']
                                                      .toString()
                                                      .isNotEmpty
                                              ? NetworkImage(
                                                  pet['photoUrl'])
                                              : null,
                                      child: (pet['photoUrl'] ==
                                                  null ||
                                              pet['photoUrl']
                                                  .toString()
                                                  .isEmpty)
                                          ? const Icon(Icons.pets)
                                          : null,
                                    ),
                                    title: Text(
                                        pet['name'] ?? '未命名'),
                                    subtitle: Text(
                                        pet['type'] ?? ''),
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              PetDetailPage(
                                                  pet: pet),
                                        ),
                                      );
                                    },
                                  ),
                                );
                              }).toList(),
                            );
                          },
                        ),

                        const SizedBox(height: 24),


ListTile(
  leading: const Icon(Icons.receipt_long),
  title: const Text('我的訂單'),
  subtitle: const Text('查看所有預約紀錄'),
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
                  );
                },
              ),
      ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}