// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_member_snapshot.dart
// 功能說明：聊天視窗內單筆會員摘要，只讀目前對話的會員文件。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/features/admin/pages/admin_member_detail_page.dart';

class ShopChatMemberSnapshot {
  const ShopChatMemberSnapshot({
    required this.name,
    required this.phone,
    required this.email,
    required this.vip,
    required this.regular,
    required this.blacklisted,
    required this.petNames,
    required this.recentOrderLabel,
  });

  final String name;
  final String phone;
  final String email;
  final bool vip;
  final bool regular;
  final bool blacklisted;
  final List<String> petNames;
  final String recentOrderLabel;
}

class ShopChatMemberSnapshotLoader {
  ShopChatMemberSnapshotLoader._();

  static Future<ShopChatMemberSnapshot> load({
    required String shopId,
    required String userId,
    String fallbackName = '',
    String fallbackPhone = '',
  }) async {
    Map<String, dynamic> data = const <String, dynamic>{};
    try {
      final DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
          .instance
          .collection('shops')
          .doc(shopId)
          .collection('members')
          .doc(userId)
          .get();
      data = doc.data() ?? const <String, dynamic>{};
    } catch (_) {}

    final List<String> tags = _stringList(data['tags']);
    final bool vip = data['isVip'] == true || tags.contains('vip');
    final bool regular =
        data['isRegular'] == true ||
        tags.contains('regular') ||
        tags.contains('常客');
    final bool blacklisted =
        data['blacklisted'] == true ||
        data['isBlacklisted'] == true ||
        data['blocked'] == true;

    final List<String> pets = <String>[];
    try {
      final QuerySnapshot<Map<String, dynamic>> petSnap =
          await FirebaseFirestore.instance
              .collection('shops')
              .doc(shopId)
              .collection('members')
              .doc(userId)
              .collection('pets')
              .limit(8)
              .get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> pet
          in petSnap.docs) {
        final String name = (pet.data()['name'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          pets.add(name);
        }
      }
    } catch (_) {}

    String orderLabel = '';
    try {
      final Map<String, dynamic>? booking = await ShopChatService.instance
          .findActiveBooking(shopId: shopId, customerUid: userId);
      if (booking != null) {
        final String room = (booking['roomName'] ?? '').toString().trim();
        final String status = (booking['status'] ?? '').toString();
        orderLabel = <String>[
          if (room.isNotEmpty) room,
          if (status.isNotEmpty) status,
          _stay(booking),
        ].where((String item) => item.isNotEmpty).join(' · ');
      }
    } catch (_) {}

    return ShopChatMemberSnapshot(
      name: _firstNonEmpty(<String>[
        (data['name'] ?? '').toString(),
        (data['displayName'] ?? '').toString(),
        fallbackName,
      ], '會員'),
      phone: _firstNonEmpty(<String>[
        (data['phone'] ?? '').toString(),
        (data['mobile'] ?? '').toString(),
        fallbackPhone,
      ], ''),
      email: (data['email'] ?? '').toString().trim(),
      vip: vip,
      regular: regular,
      blacklisted: blacklisted,
      petNames: pets,
      recentOrderLabel: orderLabel,
    );
  }

  static List<String> _stringList(dynamic raw) {
    if (raw is Iterable) {
      return raw.map((dynamic item) => item.toString()).toList();
    }
    return const <String>[];
  }

  static String _firstNonEmpty(List<String> values, String fallback) {
    for (final String value in values) {
      final String trimmed = value.trim();
      if (trimmed.isNotEmpty) {
        return trimmed;
      }
    }
    return fallback;
  }

  static String _stay(Map<String, dynamic> data) {
    final DateTime? start = _dateOf(data['startDate']);
    final DateTime? end = _dateOf(data['endDate']);
    if (start == null || end == null) {
      return '';
    }
    return '${DateFormat('M/d').format(start)}～${DateFormat('M/d').format(end)}';
  }

  static DateTime? _dateOf(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    return null;
  }
}

Future<void> showShopChatMemberSnapshot({
  required BuildContext context,
  required String shopId,
  required String userId,
  String fallbackName = '',
  String fallbackPhone = '',
  bool asBottomSheet = false,
}) async {
  final Widget body = FutureBuilder<ShopChatMemberSnapshot>(
    future: ShopChatMemberSnapshotLoader.load(
      shopId: shopId,
      userId: userId,
      fallbackName: fallbackName,
      fallbackPhone: fallbackPhone,
    ),
    builder:
        (BuildContext context, AsyncSnapshot<ShopChatMemberSnapshot> snapshot) {
          if (!snapshot.hasData) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          final ShopChatMemberSnapshot data = snapshot.data!;
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  data.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                if (data.phone.isNotEmpty) Text('電話：${data.phone}'),
                if (data.email.isNotEmpty) Text('Email：${data.email}'),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    if (data.vip) _chip('VIP', Colors.amber),
                    if (data.regular) _chip('常客', Colors.blue),
                    if (data.blacklisted) _chip('黑名單', Colors.red),
                    if (!data.vip && !data.regular && !data.blacklisted)
                      _chip('一般會員', Colors.grey),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  data.petNames.isEmpty
                      ? '寵物：尚未建檔'
                      : '寵物：${data.petNames.join('、')}',
                ),
                Text(
                  data.recentOrderLabel.isEmpty
                      ? '最近訂單：無進行中訂單'
                      : '最近訂單：${data.recentOrderLabel}',
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => AdminMemberDetailPage(
                            userId: userId,
                            shopId: shopId,
                          ),
                        ),
                      );
                    },
                    child: const Text('查看完整會員資料'),
                  ),
                ),
              ],
            ),
          );
        },
  );

  if (asBottomSheet) {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return SafeArea(child: body);
      },
    );
    return;
  }

  await showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: body,
        ),
      );
    },
  );
}

Widget _chip(String label, MaterialColor color) {
  return Chip(
    label: Text(label),
    visualDensity: VisualDensity.compact,
    backgroundColor: color.shade50,
    side: BorderSide(color: color.shade200),
  );
}
