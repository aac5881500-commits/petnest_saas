// 檔案名稱：lib/core/services/booking_entry_card_service.dart
// 功能說明：預約入口卡片照片：住宿 / 臨托分別上傳、預覽、更換與刪除

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/services/inventory_image_service.dart';

class BookingEntryCardKind {
  BookingEntryCardKind._();

  static const String accommodation = 'accommodation';
  static const String daycare = 'daycare';
}

class BookingEntryCardService {
  BookingEntryCardService._();

  static final BookingEntryCardService instance = BookingEntryCardService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static const String _urlFieldAccommodation =
      'bookingEntryAccommodationImageUrl';
  static const String _pathFieldAccommodation =
      'bookingEntryAccommodationImagePath';
  static const String _urlFieldDaycare = 'bookingEntryDaycareImageUrl';
  static const String _pathFieldDaycare = 'bookingEntryDaycareImagePath';

  DocumentReference<Map<String, dynamic>> _shopRef(String shopId) {
    return _firestore.collection('shops').doc(shopId);
  }

  String urlField(String kind) {
    return kind == BookingEntryCardKind.daycare
        ? _urlFieldDaycare
        : _urlFieldAccommodation;
  }

  String pathField(String kind) {
    return kind == BookingEntryCardKind.daycare
        ? _pathFieldDaycare
        : _pathFieldAccommodation;
  }

  Future<XFile?> pickImage() {
    return InventoryImageService.instance.pickAndValidateImage();
  }

  Future<void> upload({
    required String shopId,
    required String kind,
    required XFile image,
  }) async {
    final String normalizedShopId = shopId.trim();
    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家編號');
    }

    final DocumentReference<Map<String, dynamic>> shopRef = _shopRef(
      normalizedShopId,
    );
    final DocumentSnapshot<Map<String, dynamic>> snap = await shopRef.get();
    final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
    final String oldPath = (data[pathField(kind)] ?? '').toString().trim();
    final String oldUrl = (data[urlField(kind)] ?? '').toString().trim();

    final InventoryImageUploadResult result = await InventoryImageService
        .instance
        .uploadImage(
          shopId: normalizedShopId,
          itemId: kind,
          image: image,
          folder: 'booking_entry',
          imageType: 'booking_entry_$kind',
          idMetadataKey: 'bookingEntryKind',
        );

    await shopRef.set(<String, dynamic>{
      urlField(kind): result.imageUrl,
      pathField(kind): result.imageStoragePath,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (oldPath.isNotEmpty &&
        oldPath != result.imageStoragePath &&
        oldPath.startsWith('shops/$normalizedShopId/')) {
      await InventoryImageService.instance.tryDeleteImage(
        imageStoragePath: oldPath,
      );
    } else if (oldUrl.isNotEmpty && oldUrl != result.imageUrl) {
      await InventoryImageService.instance.tryDeleteImage(imageUrl: oldUrl);
    }
  }

  Future<void> remove({required String shopId, required String kind}) async {
    final String normalizedShopId = shopId.trim();
    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家編號');
    }
    final DocumentReference<Map<String, dynamic>> shopRef = _shopRef(
      normalizedShopId,
    );
    final DocumentSnapshot<Map<String, dynamic>> snap = await shopRef.get();
    final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
    final String oldPath = (data[pathField(kind)] ?? '').toString().trim();
    final String oldUrl = (data[urlField(kind)] ?? '').toString().trim();

    await shopRef.set(<String, dynamic>{
      urlField(kind): FieldValue.delete(),
      pathField(kind): FieldValue.delete(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (oldPath.isNotEmpty && oldPath.startsWith('shops/$normalizedShopId/')) {
      await InventoryImageService.instance.tryDeleteImage(
        imageStoragePath: oldPath,
      );
    } else if (oldUrl.isNotEmpty) {
      await InventoryImageService.instance.tryDeleteImage(imageUrl: oldUrl);
    }
  }
}
