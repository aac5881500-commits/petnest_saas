// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_member_snapshot.dart
// 功能說明：聊天視窗內單筆會員摘要，只讀會員文件與一筆進行中訂單，不另查寵物 collection。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/models/booking_kind.dart';
import 'package:petnest_saas/core/services/daycare_status_labels.dart';
import 'package:petnest_saas/core/services/shop_chat_service.dart';
import 'package:petnest_saas/features/admin/pages/admin_member_detail_page.dart';

class ShopChatMemberSnapshot {
  const ShopChatMemberSnapshot({
    required this.name,
    required this.phone,
    required this.email,
    required this.photoUrl,
    required this.vip,
    required this.regular,
    required this.blacklisted,
    required this.emergencyName,
    required this.emergencyPhone,
    required this.petNames,
    required this.currentServiceLabel,
  });

  final String name;
  final String phone;
  final String email;
  final String photoUrl;
  final bool vip;
  final bool regular;
  final bool blacklisted;
  final String emergencyName;
  final String emergencyPhone;
  final List<String> petNames;
  final String currentServiceLabel;

  String get memberTag {
    if (blacklisted) {
      return '黑名單';
    }
    if (vip) {
      return 'VIP';
    }
    return '一般會員';
  }

  String get petSummary {
    if (petNames.isEmpty) {
      return '';
    }
    if (petNames.length <= 3) {
      return '${petNames.length} 隻・${petNames.join('、')}';
    }
    return '${petNames.length} 隻・${petNames.take(3).join('、')} ＋${petNames.length - 3} 隻';
  }

  static List<String> petNamesFromMember(Map<String, dynamic> data) {
    final List<String> names = <String>[];
    void add(String value) {
      final String trimmed = value.trim();
      if (trimmed.isNotEmpty && !names.contains(trimmed)) {
        names.add(trimmed);
      }
    }

    final Object? petNames = data['petNames'];
    if (petNames is Iterable) {
      for (final Object? item in petNames) {
        add(item.toString());
      }
    }
    for (final String key in <String>[
      'pets',
      'petNameSnapshots',
      'petSummaries',
    ]) {
      final Object? raw = data[key];
      if (raw is! Iterable) {
        continue;
      }
      for (final Object? item in raw) {
        if (item is Map) {
          add((item['name'] ?? item['petName'] ?? '').toString());
        } else {
          add(item.toString());
        }
      }
    }
    add((data['petName'] ?? '').toString());
    return names;
  }
}

class ShopChatMemberSnapshotLoader {
  ShopChatMemberSnapshotLoader._();

  static Future<ShopChatMemberSnapshot> load({
    required String shopId,
    required String userId,
    String fallbackName = '',
    String fallbackPhone = '',
    String fallbackPhoto = '',
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

    final Map<String, dynamic> emergency = data['emergencyContact'] is Map
        ? Map<String, dynamic>.from(data['emergencyContact'] as Map)
        : const <String, dynamic>{};

    String serviceLabel = '目前沒有服務中的訂單';
    try {
      final Map<String, dynamic>? booking = await ShopChatService.instance
          .findActiveBooking(shopId: shopId, customerUid: userId);
      if (booking != null) {
        serviceLabel = _serviceLine(booking);
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
      photoUrl: _firstNonEmpty(<String>[
        (data['avatarUrl'] ?? '').toString(),
        (data['photoUrl'] ?? '').toString(),
        fallbackPhoto,
      ], ''),
      vip: vip,
      regular: regular,
      blacklisted: blacklisted,
      emergencyName: (emergency['name'] ?? '').toString().trim(),
      emergencyPhone: (emergency['phone'] ?? '').toString().trim(),
      petNames: ShopChatMemberSnapshot.petNamesFromMember(data),
      currentServiceLabel: serviceLabel,
    );
  }

  static String _serviceLine(Map<String, dynamic> booking) {
    final bool daycare = BookingKind.isDaycare(booking);
    final String status = daycare
        ? DaycareStatusLabels.primary(booking)
        : _stayStatus(booking);
    if (daycare) {
      final DateTime? start =
          _dateOf(booking['actualStartAt']) ??
          _dateOf(booking['scheduledStartAt']);
      final DateTime? end =
          _dateOf(booking['actualEndAt']) ?? _dateOf(booking['scheduledEndAt']);
      final String time = start != null && end != null
          ? '${DateFormat('HH:mm').format(start)}～${DateFormat('HH:mm').format(end)}'
          : '';
      return <String>['安親', if (time.isNotEmpty) time, status].join('・');
    }
    final String room = (booking['roomName'] ?? '').toString().trim();
    final String stay = _stay(booking);
    return <String>[
      if (room.isNotEmpty) room,
      if (stay.isNotEmpty) stay,
      status,
    ].join('・');
  }

  static String _stayStatus(Map<String, dynamic> data) {
    switch ((data['status'] ?? '').toString()) {
      case 'checked_in':
        return '入住中';
      case 'confirmed':
        return '已確認';
      case 'pending':
      case 'unpaid':
        return '待確認';
      default:
        return (data['status'] ?? '').toString();
    }
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
  String fallbackPhoto = '',
  bool asBottomSheet = false,
}) async {
  final Widget body = FutureBuilder<ShopChatMemberSnapshot>(
    future: ShopChatMemberSnapshotLoader.load(
      shopId: shopId,
      userId: userId,
      fallbackName: fallbackName,
      fallbackPhone: fallbackPhone,
      fallbackPhoto: fallbackPhoto,
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
                Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 22,
                      backgroundImage: data.photoUrl.isNotEmpty
                          ? NetworkImage(data.photoUrl)
                          : null,
                      child: data.photoUrl.isEmpty
                          ? Text(data.name.characters.first)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        data.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: <Widget>[
                    _chip(
                      data.memberTag,
                      data.blacklisted ? Colors.red : Colors.blueGrey,
                    ),
                    if (data.regular && !data.blacklisted)
                      _chip('常客', Colors.blue),
                  ],
                ),
                if (data.phone.isNotEmpty)
                  _copyRow(context, label: '電話', value: data.phone),
                if (data.email.isNotEmpty)
                  _copyRow(context, label: 'Email', value: data.email),
                if (data.emergencyName.isNotEmpty ||
                    data.emergencyPhone.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      '緊急聯絡人：${<String>[if (data.emergencyName.isNotEmpty) data.emergencyName, if (data.emergencyPhone.isNotEmpty) data.emergencyPhone].join(' ')}',
                    ),
                  ),
                if (data.petSummary.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 8),
                  Text('寵物：${data.petSummary}'),
                ],
                const SizedBox(height: 8),
                Text(
                  data.currentServiceLabel == '目前沒有服務中的訂單'
                      ? data.currentServiceLabel
                      : '目前服務中：${data.currentServiceLabel}',
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

Widget _copyRow(
  BuildContext context, {
  required String label,
  required String value,
}) {
  return Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: <Widget>[
        Expanded(child: Text('$label：$value')),
        IconButton(
          tooltip: '複製$label',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: value));
            if (context.mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('已複製$label')));
            }
          },
          icon: const Icon(Icons.copy, size: 18),
        ),
      ],
    ),
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
