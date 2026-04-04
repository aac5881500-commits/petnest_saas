// lib/features/pet/pages/pet_detail_page.dart
// 🐱 寵物資料詳細編輯卡（完整版🔥修好所有問題）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';

class PetDetailPage extends StatelessWidget {
  const PetDetailPage({
    super.key,
    required this.pet,
    this.isAdminView = false,
  });

  final Map<String, dynamic> pet;
  final bool isAdminView;

  @override
  Widget build(BuildContext context) {
    final photoUrl = pet['photoUrl']?.toString() ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(
          pet['name'] ?? '寵物資料',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
  if (isAdminView)
    IconButton(
      icon: const Icon(Icons.edit),
      onPressed: () => _showEditDialog(context),
    )
  else ...[
    IconButton(
      icon: const Icon(Icons.edit),
      onPressed: () => _showEditDialog(context),
    ),
    IconButton(
      icon: const Icon(Icons.delete, color: Colors.red),
      onPressed: () => _deletePet(context),
    ),
  ],
],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            /// 🖼️ 圖片
            GestureDetector(
              onTap: photoUrl.isNotEmpty
                  ? () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              _FullImagePage(imageUrl: photoUrl),
                        ),
                      );
                    }
                  : null,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey.shade300, width: 2),
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 10,
                      color: Colors.black.withOpacity(0.1),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: photoUrl.isNotEmpty
                      ? Image.network(
                          photoUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                          errorBuilder: (_, __, ___) {
                            return const Icon(Icons.pets, size: 60);
                          },
                        )
                      : const Icon(Icons.pets, size: 60),
                ),
              ),
            ),

            const SizedBox(height: 24),

            _buildCard([
              const Text(
                '基本資料',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              _item('名稱', pet['name']),
              _item('品種', pet['breed']),
              _item('性別', pet['gender']),
              _item('年齡', pet['age']),
            ]),

            const SizedBox(height: 16),

            _buildCard([
              const Text('健康資訊',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              _item('結紮狀況',
                  pet['isNeutered'] == true ? '已結紮' : '未結紮'),
                  const SizedBox(height: 6),
const Text(
  '※ 未結紮公貓可能會有噴尿情況，將會額外收費（詳見入住須知）',
  style: TextStyle(
    color: Colors.red,
    fontSize: 16,
  ),
),
              _item('醫療狀況', pet['vaccine']),
              _item('貓砂種類', pet['litterType']),
            ]),

            const SizedBox(height: 16),

            _buildCard([
              const Text('其他備註',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text(pet['note'] ?? '無'),
            ]),
            if (isAdminView) ...[
  const SizedBox(height: 16),

  _buildCard([
    const Text(
      '🔒 員工備註（內部）',
      style: TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: Colors.red,
      ),
    ),
    const SizedBox(height: 8),
    Text(pet['adminNote'] ?? '無'),
  ]),
],
          ],
        ),
      ),
    );
  }

  Widget _buildCard(List<Widget> children) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            blurRadius: 12,
            color: Colors.black.withOpacity(0.08),
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _item(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label：',
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(
            child: Text(
              value?.toString().isNotEmpty == true
                  ? value.toString()
                  : '未填寫',
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  /// ✏️ 編輯（完整版🔥含換照片）
  Future<void> _showEditDialog(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final name = TextEditingController(text: pet['name'] ?? '');
    final breed = TextEditingController(text: pet['breed'] ?? '');
    final note = TextEditingController(text: pet['note'] ?? '');
    final adminNote = TextEditingController(
  text: pet['adminNote'] ?? '',
);

    String? gender = pet['gender'];
    String? age = pet['age'];
    String? medical = pet['vaccine'];
    String? litterType = pet['litterType'];

    Uint8List? newImage;

    await showDialog(
      context: context,
      builder: (_) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('編輯寵物'),
              content: SingleChildScrollView(
                child: Column(
                  children: [

                    

                    /// 🔥 圖片選擇
                    GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked =
                            await picker.pickImage(source: ImageSource.gallery);
                        if (picked != null) {
                          final bytes = await picked.readAsBytes();
                          setState(() => newImage = bytes);
                        }
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.grey[200],
                        ),
                        child: ClipOval(
                          child: newImage != null
                              ? Image.memory(newImage!, fit: BoxFit.cover)
                              : (pet['photoUrl'] != null &&
                                      pet['photoUrl'] != '')
                                  ? Image.network(pet['photoUrl'],
                                      fit: BoxFit.cover)
                                  : const Icon(Icons.camera_alt),
                        ),
                      ),
                    ),

                    TextField(
  controller: name,
  enabled: !isAdminView,

                      decoration: const InputDecoration(labelText: '名稱'),
                    ),

if (isAdminView) ...[
  const SizedBox(height: 12),
  TextField(
    controller: adminNote,
    decoration: const InputDecoration(
      labelText: '員工備註（只有後台看得到）',
    ),
  ),
],

                    DropdownButtonFormField(
                      value: ['公貓', '母貓'].contains(gender) ? gender : null,
                      items: ['公貓', '母貓']
                          .map((e) =>
                              DropdownMenuItem(value: e, child: Text(e)))
                          .toList(),
                      onChanged: isAdminView
    ? null
    : (v) => setState(() => gender = v as String?),
                    ),

                    DropdownButtonFormField(
                      value: ['6~12個月', '1~10歲'].contains(age) ? age : null,
                      items: const [
                        DropdownMenuItem(value: '6~12個月', child: Text('6~12個月')),
                        DropdownMenuItem(value: '1~10歲', child: Text('1~10歲')),
                      ],
                      onChanged: isAdminView
    ? null
    : (v) => setState(() => age = v as String?),
                    ),

                    DropdownButtonFormField(
  value: ['無', '慢性腎臟病', '糖尿病'].contains(medical)
      ? medical
      : null,
                      items: const [
                        DropdownMenuItem(value: '無', child: Text('無')),
                        DropdownMenuItem(value: '慢性腎臟病', child: Text('慢性腎臟病')),
                        DropdownMenuItem(value: '糖尿病', child: Text('糖尿病')), 
                      ],
                      onChanged: isAdminView
    ? null
    : (v) => setState(() => medical = v as String?),
                    ),

                    DropdownButtonFormField(
                      value: ['豆腐砂', '礦砂'].contains(litterType)
    ? litterType
    : null,
                      items: const [
                        DropdownMenuItem(value: '豆腐砂', child: Text('豆腐砂')),
                        DropdownMenuItem(value: '礦砂', child: Text('礦砂')),
                      ],
                      onChanged: isAdminView
    ? null
    : (v) => setState(() => litterType = v as String?),
                    ),

                    TextField(
  controller: note,
  enabled: !isAdminView,
  decoration: const InputDecoration(labelText: '備註'),
),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                TextButton(
                  onPressed: () async {

                    /// 🔥 刪舊圖
                    if (newImage != null &&
                        pet['photoUrl'] != null &&
                        pet['photoUrl'] != '') {
                      try {
                        await FirebaseStorage.instance
                            .refFromURL(pet['photoUrl'])
                            .delete();
                      } catch (e) {}
                    }

                    /// 🔥 更新資料
                    await FirebaseFirestore.instance
                        .collection('user_profiles')
                        .doc(uid)
                        .collection('pets')
                        .doc(pet['petId'])
                        .update({
                      'name': name.text,
                      'age': age,
                      'gender': gender,
                      'breed': breed.text,
                      'vaccine': medical,
                      'litterType': litterType,
                      'note': note.text,
                      'adminNote': adminNote.text,
                    });

                    /// 🔥 上傳新圖
                    if (newImage != null) {
                      final ref = FirebaseStorage.instance
                          .ref()
                          .child('pets')
                          .child(uid)
                          .child('${pet['petId']}.jpg');

                      await ref.putData(newImage!);
                      final url = await ref.getDownloadURL();

                      await FirebaseFirestore.instance
                          .collection('user_profiles')
                          .doc(uid)
                          .collection('pets')
                          .doc(pet['petId'])
                          .update({'photoUrl': url});
                    }

                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  child: const Text('儲存'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deletePet(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    /// 🔥 刪圖片
    if (pet['photoUrl'] != null && pet['photoUrl'] != '') {
      try {
        await FirebaseStorage.instance
            .refFromURL(pet['photoUrl'])
            .delete();
      } catch (e) {}
    }

    await FirebaseFirestore.instance
        .collection('user_profiles')
        .doc(uid)
        .collection('pets')
        .doc(pet['petId'])
        .delete();

    if (context.mounted) Navigator.pop(context);
  }
}

class _FullImagePage extends StatelessWidget {
  final String imageUrl;

  const _FullImagePage({required this.imageUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Center(
          child: InteractiveViewer(
            child: Image.network(imageUrl),
          ),
        ),
      ),
    );
  }
}