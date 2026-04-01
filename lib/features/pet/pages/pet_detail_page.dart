// lib/features/pet/pages/pet_detail_page.dart
// 🐾 寵物詳細頁
//
// 功能：
// - 顯示寵物資料
// - 顯示照片
// - 點擊照片可上傳（覆蓋舊圖）
// - 上傳後自動刷新

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/pet_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';


class PetDetailPage extends StatefulWidget {
  const PetDetailPage({
    super.key,
    required this.pet,
  });

  final Map<String, dynamic> pet;

  @override
  State<PetDetailPage> createState() => _PetDetailPageState();
}

class _PetDetailPageState extends State<PetDetailPage> {
  Map<String, dynamic> get pet => widget.pet;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(pet['name'] ?? '寵物'),
      ),
      body: StreamBuilder<DocumentSnapshot>(
  stream: FirebaseFirestore.instance
      .collection('user_profiles')
      .doc(FirebaseAuth.instance.currentUser!.uid)
      .collection('pets')
      .doc(pet['petId'])
      .snapshots(),
  builder: (context, snapshot) {
    if (!snapshot.hasData) {
      return const Center(child: CircularProgressIndicator());
    }

    final data = snapshot.data!.data() as Map<String, dynamic>?;

    if (data == null) {
      return const Center(child: Text('找不到寵物資料'));
    }

    final photoUrl = data['photoUrl'];

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          /// 🔥 照片（即時更新）
          Center(
            child: GestureDetector(
              onTap: () async {
                await PetService.instance.uploadPetPhoto(
                  petId: pet['petId'],
                );
              },
              child: CircleAvatar(
                radius: 50,
                backgroundImage: photoUrl != null &&
                        photoUrl.toString().isNotEmpty
                    ? NetworkImage(photoUrl)
                    : null,
                child: (photoUrl == null ||
                        photoUrl.toString().isEmpty)
                    ? const Icon(Icons.camera_alt, size: 30)
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 20),

          /// 名稱
          Text(
            '名稱：${data['name'] ?? ''}',
            style: const TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 12),

          /// 類型
          Text('類型：${data['type'] ?? ''}'),
          const SizedBox(height: 12),

          /// 品種
          Text('品種：${data['breed'] ?? ''}'),
          const SizedBox(height: 12),

          /// 性別
          Text('性別：${data['gender'] ?? ''}'),
          const SizedBox(height: 12),

          /// 備註
          Text('備註：${data['note'] ?? ''}'),

        ],
      ),
    );
  },
),
    );
  }
}