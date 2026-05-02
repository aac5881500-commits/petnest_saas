// lib/features/booking/pages/booking_detail_page.dart
// 📄 訂單詳細頁（客戶端）
//
// 功能：
// - 顯示完整訂單資訊（卡片式 UI）
// - 顧客 / 寵物 / 訂金 / 備註
// - 上傳轉帳截圖
// - 填寫轉帳後五碼
//
// 特點：
// - UI 已升級（區塊卡片）
// - 訂金區強化（橘色提示）
// - 不顯示員工備註（安全）

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';

class BookingDetailPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final String docId;

  const BookingDetailPage({
    super.key,
    required this.data,
    required this.docId,
  });

  @override
  State<BookingDetailPage> createState() => _BookingDetailPageState();
}

class _BookingDetailPageState extends State<BookingDetailPage> {
  final TextEditingController _last5Controller = TextEditingController();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final data = widget.data;

    final start = (data['startDate'] as Timestamp).toDate();
    final end = (data['endDate'] as Timestamp).toDate();

    return Scaffold(
      appBar: AppBar(title: const Text('訂單詳細')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [

            /// 🧾 訂單總覽
            _sectionCard(
              title: '訂單總覽',
              children: [
                _item('房型', data['roomName'] ?? ''),
                _item('日期',
                    '${start.toString().substring(0, 10)} → ${end.toString().substring(0, 10)}'),
                _item('寵物數量', '${(data['petIds'] ?? []).length}'),
                Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    const Text(
      '總金額',
      style: TextStyle(fontWeight: FontWeight.bold),
    ),
    const SizedBox(height: 4),
    Text(
      'NT\$ ${data['totalPrice'] ?? 0}',
      style: const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.bold,
        color: Colors.blue,
      ),
    ),
  ],
),
                Row(
  children: [
    const SizedBox(
      width: 90,
      child: Text('狀態', style: TextStyle(fontWeight: FontWeight.bold)),
    ),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: data['status'] == 'confirmed'
            ? Colors.green.shade100
            : Colors.orange.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        data['status'] == 'confirmed' ? '已確認' : '待確認',
        style: TextStyle(
          color: data['status'] == 'confirmed'
              ? Colors.green
              : Colors.orange,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
  ],
),
              ],
            ),

            /// 👤 顧客資訊
            _sectionCard(
              title: '顧客資訊',
              children: [
                _item('姓名', data['customerName'] ?? ''),
                _item('電話', data['customerPhone'] ?? ''),
                _item('地址', data['customerAddress'] ?? ''),
              ],
            ),

            /// 🐾 寵物資訊
            _sectionCard(
              title: '寵物資訊',
              children: [
                ...((data['pets'] ?? []) as List).map((pet) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          pet['name'] ?? '',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text('品種：${pet['breed'] ?? ''}'),
                      ],
                    ),
                  );
                }).toList(),
              ],
            ),

/// 🔥 加值服務
if ((data['addons'] ?? []).isNotEmpty)
  _sectionCard(
    title: '加值服務',
    children: [
      ...List.generate(
        (data['addons'] as List).length,
        (index) {
          final item = data['addons'][index];

          return Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(item['name'] ?? ''),
                Text(
                  '+ ${item['price']} 元',
                  style: const TextStyle(
                    color: Colors.blue,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ],
  ),

            /// 💰 訂金資訊
            /// 
            /// 
            Container(
  padding: const EdgeInsets.all(10),
  margin: const EdgeInsets.only(bottom: 10),
  decoration: BoxDecoration(
    color: Colors.red.shade50,
    borderRadius: BorderRadius.circular(10),
  ),
  child: const Text(
    '⚠️ 尚未完成訂金，訂單不會成立',
    style: TextStyle(
      color: Colors.red,
      fontWeight: FontWeight.bold,
    ),
  ),
),
            _sectionCard(
              title: '訂金資訊',
              children: [

                _item('訂金金額', '${data['depositAmount'] ?? 0} 元'),

                const SizedBox(height: 10),

                /// 🔥 強化後五碼輸入
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.orange),
                    borderRadius: BorderRadius.circular(10),
                    color: Colors.orange.shade50,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '⚠️ 請輸入轉帳後五碼',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _last5Controller,
                        decoration: const InputDecoration(
                          hintText: '例如：12345',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                /// 上傳圖片
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _uploadImage,
                    child: const Text('上傳轉帳截圖'),
                  ),
                ),

                const SizedBox(height: 12),

                /// 顯示圖片
                if (data['transferImageUrl'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      data['transferImageUrl'],
                      height: 180,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),

                const SizedBox(height: 12),

                /// 送出訂金
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _submitDeposit,
                    child: Text(_loading ? '送出中...' : '送出訂金'),
                  ),
                ),
              ],
            ),

            /// 📝 備註
            _sectionCard(
              title: '備註',
              children: [
                Text(data['note'] ?? '無'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 🔥 寫入訂金
  Future<void> _submitDeposit() async {
    final last5 = _last5Controller.text.trim();

    if (last5.length != 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('請輸入正確的後五碼')),
      );
      return;
    }

    try {
      setState(() {
        _loading = true;
      });

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.docId)
          .update({
        'transferLast5': last5,
        'depositStatus': 'pending',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('訂金已送出')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('錯誤：$e')),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  /// 📦 區塊卡片
  Widget _sectionCard({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(16),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withOpacity(0.06),
      blurRadius: 12,
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
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          ...children,
        ],
      ),
    );
  }

  /// 🔹 欄位
  Widget _item(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  /// 📸 上傳圖片
  Future<void> _uploadImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked == null) return;

    setState(() {
      _loading = true;
    });

    try {
      final file = File(picked.path);

      final ref = FirebaseStorage.instance
          .ref()
          .child('booking_images')
          .child(widget.docId)
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');

      await ref.putFile(file);

      final url = await ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(widget.docId)
          .update({
        'transferImageUrl': url,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('圖片上傳成功')),
      );

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('上傳失敗：$e')),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }
}