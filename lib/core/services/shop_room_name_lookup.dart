// 檔案名稱：lib/core/services/shop_room_name_lookup.dart
// 功能說明：以 shops/{shopId}/rooms/{roomId} 查房號名稱；畫面不露出 document id

import 'package:cloud_firestore/cloud_firestore.dart';

class ShopRoomNameLookup {
  ShopRoomNameLookup._();

  static const String missingLabel = '原房間資料已不存在';

  static bool looksLikeDocumentId(String value) {
    final String trimmed = value.trim();
    if (trimmed.length < 18) {
      return false;
    }
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(trimmed)) {
      return false;
    }
    return RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(trimmed);
  }

  static String? idIfLookupNeeded(dynamic name, dynamic id) {
    final String nameText = (name ?? '').toString().trim();
    final String idText = (id ?? '').toString().trim();
    if (nameText.isNotEmpty && !looksLikeDocumentId(nameText)) {
      return null;
    }
    if (looksLikeDocumentId(nameText)) {
      return nameText;
    }
    if (idText.isNotEmpty) {
      return idText;
    }
    return null;
  }

  static Future<Map<String, String>> resolve({
    required String shopId,
    required Iterable<String> roomIds,
    FirebaseFirestore? firestore,
  }) async {
    if (shopId.trim().isEmpty) {
      return <String, String>{};
    }
    final Set<String> ids = roomIds
        .map((String id) => id.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();
    if (ids.isEmpty) {
      return <String, String>{};
    }
    final FirebaseFirestore db = firestore ?? FirebaseFirestore.instance;
    final Map<String, String> out = <String, String>{};
    await Future.wait(
      ids.map((String id) async {
        try {
          final DocumentSnapshot<Map<String, dynamic>> snap = await db
              .collection('shops')
              .doc(shopId)
              .collection('rooms')
              .doc(id)
              .get();
          if (!snap.exists) {
            out[id] = '';
            return;
          }
          final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
          final String name = (data['name'] ?? data['number'] ?? data['roomName'] ?? '')
              .toString()
              .trim();
          out[id] = name;
        } catch (_) {
          out[id] = '';
        }
      }),
    );
    return out;
  }
}
