// lib/core/services/store_settings_service.dart
// 🛒 賣場設定

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';

class StoreSettingsService {
  StoreSettingsService._();

  static final StoreSettingsService instance = StoreSettingsService._();

  DocumentReference<Map<String, dynamic>> settingsRef(String shopId) {
    return FirebaseFirestore.instance
        .collection('shops')
        .doc(shopId.trim())
        .collection(StoreConstants.settingsCollection)
        .doc(StoreConstants.settingsDocId);
  }

  Stream<Map<String, dynamic>> streamSettings(String shopId) {
    return settingsRef(shopId).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      return snapshot.data() ?? <String, dynamic>{};
    });
  }

  Future<void> saveSettings({
    required String shopId,
    required String pickupNote,
    required bool storefrontEnabled,
  }) async {
    await settingsRef(shopId).set(<String, dynamic>{
      'shopId': shopId.trim(),
      'pickupNote': pickupNote.trim(),
      'storefrontEnabled': storefrontEnabled,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
