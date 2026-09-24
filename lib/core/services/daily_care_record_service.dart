// 檔案名稱：lib/core/services/daily_care_record_service.dart
// 功能說明：管理一房一天一場的每日照護紀錄
// 🐾 每日照護紀錄 Service
// 使用訂單 ID、日期與場次產生固定紀錄 ID，避免重複建立。

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/daily_care_date_helper.dart';
import '../models/daily_care_record_model.dart';
import 'daily_care_report_write_access.dart';

class DailyCareRecordService {
  DailyCareRecordService._();

  static final DailyCareRecordService instance = DailyCareRecordService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _collection {
    return _firestore.collection('daily_care_records');
  }

  /// 產生固定紀錄 ID
  ///
  /// 例如：
  /// booking123_20260808_0
  static String recordId({
    required String bookingId,
    required DateTime recordDate,
    required int sessionIndex,
  }) {
    final String dateKey = DailyCareDateHelper.recordIdDateKey(recordDate);

    return '${bookingId}_${dateKey}_$sessionIndex';
  }

  String buildRecordId({
    required String bookingId,
    required DateTime recordDate,
    required int sessionIndex,
  }) {
    return DailyCareRecordService.recordId(
      bookingId: bookingId,
      recordDate: recordDate,
      sessionIndex: sessionIndex,
    );
  }

  /// 監聽單一場次紀錄
  Stream<DailyCareRecordModel?> streamRecord({
    required String shopId,
    required String bookingId,
    required DateTime recordDate,
    required int sessionIndex,
  }) {
    final String normalizedShopId = shopId.trim();
    final String normalizedBookingId = bookingId.trim();

    if (normalizedShopId.isEmpty || normalizedBookingId.isEmpty) {
      return Stream<DailyCareRecordModel?>.value(null);
    }

    final String id = recordId(
      bookingId: normalizedBookingId,
      recordDate: recordDate,
      sessionIndex: sessionIndex,
    );

    return _collection.doc(id).snapshots().map((
      DocumentSnapshot<Map<String, dynamic>> snapshot,
    ) {
      if (!snapshot.exists) {
        return null;
      }
      final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
      if (normalizedShopId.isNotEmpty &&
          (data['shopId'] ?? '').toString() != normalizedShopId) {
        return null;
      }
      return DailyCareRecordModel.fromMap(id: snapshot.id, map: data);
    });
  }

  /// 單次取得某一場紀錄。直接讀固定 document id，不走集合 where 查詢。
  Future<DailyCareRecordModel?> getRecord({
    required String bookingId,
    required String shopId,
    required DateTime recordDate,
    required int sessionIndex,
  }) async {
    final String normalizedBookingId = bookingId.trim();
    final String normalizedShopId = shopId.trim();
    if (normalizedBookingId.isEmpty || normalizedShopId.isEmpty) {
      return null;
    }
    final String id = buildRecordId(
      bookingId: normalizedBookingId,
      recordDate: recordDate,
      sessionIndex: sessionIndex,
    );
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await _collection
          .doc(id)
          .get();
      if (!snapshot.exists) {
        return null;
      }
      final Map<String, dynamic> data = snapshot.data() ?? <String, dynamic>{};
      if ((data['shopId'] ?? '').toString() != normalizedShopId) {
        return null;
      }
      return DailyCareRecordModel.fromMap(id: snapshot.id, map: data);
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        return null;
      }
      rethrow;
    }
  }

  /// 儲存或更新某一場照護紀錄
  ///
  /// 紀錄 ID 已固定為：
  /// bookingId + 日期 + sessionIndex
  ///
  /// 因此不需要先讀取文件，也不需要 Transaction，
  /// 同一場次重複儲存時只會更新同一份文件。
  Future<void> saveRecord({
    required String shopId,
    required String bookingId,
    required String roomId,
    required String roomName,
    required DateTime recordDate,
    required int sessionIndex,
    required String sessionName,
    required Map<String, dynamic> values,
    required Map<String, String> petNotes,
    required String? operatorUid,
    required String? operatorName,
    String serviceType = DailyCareServiceTypes.accommodation,
    List<String> petIds = const <String>[],
  }) async {
    final String normalizedShopId = shopId.trim();

    final String normalizedBookingId = bookingId.trim();

    final String normalizedRoomId = roomId.trim();

    final String normalizedRoomName = roomName.trim();

    if (normalizedShopId.isEmpty) {
      throw ArgumentError('缺少店家 ID');
    }

    if (normalizedBookingId.isEmpty) {
      throw ArgumentError('缺少訂單 ID');
    }

    await _assertBookingWritable(normalizedBookingId);

    final String normalizedServiceType = DailyCareServiceTypes.parse(
      serviceType,
    );
    final bool isDaycare =
        normalizedServiceType == DailyCareServiceTypes.daycare;

    if (normalizedRoomId.isEmpty && !isDaycare) {
      throw ArgumentError('缺少房間 ID');
    }

    final String recordId = buildRecordId(
      bookingId: normalizedBookingId,
      recordDate: recordDate,
      sessionIndex: sessionIndex,
    );

    final DocumentReference<Map<String, dynamic>> ref = _collection.doc(
      recordId,
    );

    final DateTime taipei = DailyCareDateHelper.calendarDateInTaipei(
      recordDate,
    );
    final DateTime day = DateTime(taipei.year, taipei.month, taipei.day);
    final String serviceDate = DailyCareDateHelper.dateKey(
      day,
    ).replaceAll('/', '-');

    await ref.set(<String, dynamic>{
      'shopId': normalizedShopId,
      'bookingId': normalizedBookingId,
      'roomId': normalizedRoomId,
      'roomName': normalizedRoomName,
      'recordDate': Timestamp.fromDate(day),
      'sessionIndex': sessionIndex,
      'recordIndex': sessionIndex,
      'sessionName': sessionName.trim(),
      'serviceType': normalizedServiceType,
      'serviceDate': serviceDate,
      'petIds': petIds
          .map((String id) => id.trim())
          .where((String id) => id.isNotEmpty)
          .toList(),
      'values': values,

      // 個別寵物概況目前停用，
      // 先保留資料欄位以相容既有 Model。
      'petNotes': petNotes,

      // 目前保存最後一次操作人資訊。
      // 之後若要嚴格區分 createdBy / updatedBy，
      // 再另外擴充欄位。
      'createdByUid': operatorUid?.trim(),
      'createdByName': operatorName?.trim(),

      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// 取得某次住宿全部照護紀錄
  ///
  /// Customer：只帶 bookingId，走既有 ownership query。
  /// Shop：帶 shopId 時用 shopId + bookingId 集合查詢，再過濾預期
  /// deterministic ID。未建立的文件不會出現在 query 結果中，這是待填
  /// 的正常狀態，不可對不存在的 document 做 get/snapshots。
  Stream<List<DailyCareRecordModel>> streamBookingRecords({
    required String bookingId,
    String? shopId,
    List<DateTime>? careDates,
    int sessionCount = 3,
  }) {
    final String normalizedBookingId = bookingId.trim();
    final String normalizedShopId = (shopId ?? '').trim();

    if (normalizedBookingId.isEmpty) {
      return Stream<List<DailyCareRecordModel>>.value(
        const <DailyCareRecordModel>[],
      );
    }

    if (normalizedShopId.isNotEmpty) {
      return _streamRecordsByBookingQuery(
        shopId: normalizedShopId,
        bookingId: normalizedBookingId,
        careDates: careDates ?? const <DateTime>[],
        sessionCount: sessionCount,
      );
    }

    return _collection
        .where('bookingId', isEqualTo: normalizedBookingId)
        .snapshots()
        .map(_mapRecordQuery);
  }

  List<DailyCareRecordModel> _mapRecordQuery(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final List<DailyCareRecordModel> records = snapshot.docs.map((
      QueryDocumentSnapshot<Map<String, dynamic>> doc,
    ) {
      return DailyCareRecordModel.fromMap(id: doc.id, map: doc.data());
    }).toList();

    records.sort((DailyCareRecordModel a, DailyCareRecordModel b) {
      final int dateCompare = a.recordDate.compareTo(b.recordDate);
      if (dateCompare != 0) {
        return dateCompare;
      }
      return a.sessionIndex.compareTo(b.sessionIndex);
    });

    return records;
  }

  Stream<List<DailyCareRecordModel>> _streamRecordsByBookingQuery({
    required String shopId,
    required String bookingId,
    List<DateTime> careDates = const <DateTime>[],
    int sessionCount = 3,
  }) {
    assert(sessionCount >= 0);
    return _collection
        .where('shopId', isEqualTo: shopId)
        .where('bookingId', isEqualTo: bookingId)
        .snapshots()
        .map(_mapRecordQuery);
  }

  static Set<String> matchKeys({
    required String bookingId,
    required DateTime recordDate,
    required int sessionIndex,
    String recordId = '',
  }) {
    final String id = recordId.trim();
    final String built = DailyCareRecordService.recordId(
      bookingId: bookingId,
      recordDate: recordDate,
      sessionIndex: sessionIndex,
    );
    return <String>{
      if (id.isNotEmpty) id,
      built,
      '${bookingId.trim()}#${DailyCareDateHelper.dateKey(recordDate)}#$sessionIndex',
      '${bookingId.trim()}#${DailyCareDateHelper.recordIdDateKey(recordDate)}#$sessionIndex',
    };
  }

  /// 首頁用：只讀固定 Record ID，不掃整間店紀錄。
  Stream<Set<int>> streamFilledSessionIndexes({
    required String bookingId,
    required DateTime recordDate,
    required int sessionCount,
  }) {
    final String normalizedBookingId = bookingId.trim();
    final int count = sessionCount < 1
        ? 1
        : sessionCount > 3
        ? 3
        : sessionCount;

    if (normalizedBookingId.isEmpty) {
      return Stream<Set<int>>.value(const <int>{});
    }

    final StreamController<Set<int>> controller = StreamController<Set<int>>();
    final Set<int> filled = <int>{};
    final List<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
    subscriptions =
        <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>[];

    void emit() {
      if (!controller.isClosed) {
        controller.add(Set<int>.from(filled));
      }
    }

    for (int index = 0; index < count; index++) {
      final String recordId = buildRecordId(
        bookingId: normalizedBookingId,
        recordDate: recordDate,
        sessionIndex: index,
      );
      subscriptions.add(
        _collection.doc(recordId).snapshots().listen((
          DocumentSnapshot<Map<String, dynamic>> snapshot,
        ) {
          if (snapshot.exists) {
            filled.add(index);
          } else {
            filled.remove(index);
          }
          emit();
        }),
      );
    }

    controller.onCancel = () async {
      for (final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
          subscription
          in subscriptions) {
        await subscription.cancel();
      }
    };

    return controller.stream;
  }

  Future<void> _assertBookingWritable(String bookingId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot = await _firestore
        .collection('bookings')
        .doc(bookingId)
        .get();
    final Map<String, dynamic>? data = snapshot.data();
    if (!DailyCareReportWriteAccess.canWrite(data)) {
      throw StateError(DailyCareReportWriteAccess.lockedMessage);
    }
  }
}
