// 檔案名稱：lib/core/services/daily_care_record_service.dart
// 功能說明：管理一房一天一場的每日照護紀錄
// 🐾 每日照護紀錄 Service
// 使用訂單 ID、日期與場次產生固定紀錄 ID，避免重複建立。

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/daily_care_date_helper.dart';
import '../models/daily_care_record_model.dart';

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
  String buildRecordId({
    required String bookingId,
    required DateTime recordDate,
    required int sessionIndex,
  }) {
    final String dateKey = DailyCareDateHelper.recordIdDateKey(recordDate);

    return '${bookingId}_${dateKey}_$sessionIndex';
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

    final DateTime normalizedDate = DateTime(
      recordDate.year,
      recordDate.month,
      recordDate.day,
    );

    return _collection
        .where('shopId', isEqualTo: normalizedShopId)
        .where('bookingId', isEqualTo: normalizedBookingId)
        .where('recordDate', isEqualTo: Timestamp.fromDate(normalizedDate))
        .where('sessionIndex', isEqualTo: sessionIndex)
        .limit(1)
        .snapshots()
        .map((QuerySnapshot<Map<String, dynamic>> snapshot) {
          if (snapshot.docs.isEmpty) {
            return null;
          }

          final QueryDocumentSnapshot<Map<String, dynamic>> doc =
              snapshot.docs.first;

          return DailyCareRecordModel.fromMap(id: doc.id, map: doc.data());
        });
  }

  /// 單次取得某一場紀錄
  Future<DailyCareRecordModel?> getRecord({
    required String shopId,
    required String bookingId,
    required DateTime recordDate,
    required int sessionIndex,
  }) async {
    final String normalizedShopId = shopId.trim();
    final String normalizedBookingId = bookingId.trim();

    if (normalizedShopId.isEmpty || normalizedBookingId.isEmpty) {
      return null;
    }

    final QuerySnapshot<Map<String, dynamic>> snapshot = await _collection
        .where('shopId', isEqualTo: normalizedShopId)
        .where('bookingId', isEqualTo: normalizedBookingId)
        .where(
          'recordDate',
          isEqualTo: Timestamp.fromDate(
            DateTime(recordDate.year, recordDate.month, recordDate.day),
          ),
        )
        .where('sessionIndex', isEqualTo: sessionIndex)
        .limit(1)
        .get();

    if (snapshot.docs.isEmpty) {
      return null;
    }

    final QueryDocumentSnapshot<Map<String, dynamic>> doc = snapshot.docs.first;

    return DailyCareRecordModel.fromMap(id: doc.id, map: doc.data());
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

    if (normalizedRoomId.isEmpty) {
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

    await ref.set(<String, dynamic>{
      'shopId': normalizedShopId,
      'bookingId': normalizedBookingId,
      'roomId': normalizedRoomId,
      'roomName': normalizedRoomName,
      'recordDate': Timestamp.fromDate(
        DateTime(recordDate.year, recordDate.month, recordDate.day),
      ),
      'sessionIndex': sessionIndex,
      'sessionName': sessionName.trim(),
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
  /// Shop preview：務必帶 shopId + careDates，改讀固定 Record ID，
  /// 避免 `where bookingId` 集合查詢被 Rules 擋成 permission-denied。
  Stream<List<DailyCareRecordModel>> streamBookingRecords({
    required String bookingId,
    String? shopId,
    List<DateTime>? careDates,
    int sessionCount = 3,
  }) {
    final String normalizedBookingId = bookingId.trim();
    if (normalizedBookingId.isEmpty) {
      return Stream<List<DailyCareRecordModel>>.value(
        const <DailyCareRecordModel>[],
      );
    }

    if ((shopId ?? '').trim().isNotEmpty) {
      return _streamRecordsByDeterministicIds(
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

  Stream<List<DailyCareRecordModel>> _streamRecordsByDeterministicIds({
    required String bookingId,
    required List<DateTime> careDates,
    required int sessionCount,
  }) {
    if (careDates.isEmpty) {
      return Stream<List<DailyCareRecordModel>>.value(
        const <DailyCareRecordModel>[],
      );
    }

    final int count = sessionCount < 1
        ? 1
        : sessionCount > 3
        ? 3
        : sessionCount;
    final StreamController<List<DailyCareRecordModel>> controller =
        StreamController<List<DailyCareRecordModel>>();
    final Map<String, DailyCareRecordModel> byId =
        <String, DailyCareRecordModel>{};
    final List<StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
    subscriptions =
        <StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>[];

    void emit() {
      if (controller.isClosed) {
        return;
      }
      final List<DailyCareRecordModel> records = byId.values.toList()
        ..sort((DailyCareRecordModel a, DailyCareRecordModel b) {
          final int dateCompare = a.recordDate.compareTo(b.recordDate);
          if (dateCompare != 0) {
            return dateCompare;
          }
          return a.sessionIndex.compareTo(b.sessionIndex);
        });
      controller.add(records);
    }

    for (final DateTime date in careDates) {
      for (int index = 0; index < count; index++) {
        final String recordId = buildRecordId(
          bookingId: bookingId,
          recordDate: date,
          sessionIndex: index,
        );
        subscriptions.add(
          _collection
              .doc(recordId)
              .snapshots()
              .listen(
                (DocumentSnapshot<Map<String, dynamic>> snapshot) {
                  final Map<String, dynamic>? data = snapshot.data();
                  if (snapshot.exists && data != null) {
                    byId[recordId] = DailyCareRecordModel.fromMap(
                      id: snapshot.id,
                      map: data,
                    );
                  } else {
                    byId.remove(recordId);
                  }
                  emit();
                },
                onError: (Object error, StackTrace stackTrace) {
                  _logQueryFailure(
                    bookingId: bookingId,
                    shopId: null,
                    error: error,
                    stackTrace: stackTrace,
                    extra: 'recordId=$recordId',
                  );
                  if (!controller.isClosed) {
                    controller.addError(error, stackTrace);
                  }
                },
              ),
        );
      }
    }

    emit();
    controller.onCancel = () async {
      for (final StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>
          subscription
          in subscriptions) {
        await subscription.cancel();
      }
    };
    return controller.stream;
  }

  void _logQueryFailure({
    required String bookingId,
    required Object error,
    required StackTrace stackTrace,
    String? shopId,
    String extra = '',
  }) {
    final String code = error is FirebaseException ? error.code : '';
    final String message = error is FirebaseException
        ? (error.message ?? error.toString())
        : error.toString();
    debugPrint(
      '[DailyCarePreview] load failed\n'
      'shopId=${shopId ?? ''}\n'
      'bookingId=$bookingId\n'
      '${extra.isEmpty ? '' : '$extra\n'}'
      'errorType=${error.runtimeType}\n'
      'errorCode=$code\n'
      'message=$message\n'
      '$stackTrace',
    );
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
}
