// 檔案名稱：test/daily_care_photo_expiry_test.dart
// 功能說明：照片保存期限顯示、分享圖小字、摘要統計圖門檻與產圖資料仍可用。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/daily_care_entitlement.dart';
import 'package:petnest_saas/core/models/daily_care_photo_model.dart';
import 'package:petnest_saas/core/models/daily_care_record_model.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_item.dart';
import 'package:petnest_saas/core/models/daily_care_report_data.dart';
import 'package:petnest_saas/core/models/daily_care_setting_model.dart';
import 'package:petnest_saas/core/models/daily_care_stay_info.dart';
import 'package:petnest_saas/core/services/daily_care_report_export_service.dart';
import 'package:petnest_saas/core/widgets/daily_care_summary_report_view.dart';
import 'package:petnest_saas/features/shop/widgets/daily_care_report_center_board.dart';

void main() {
  final DateTime day = DateTime(2026, 9, 21);

  DailyCarePhotoModel photo({DateTime? expiresAt}) {
    return DailyCarePhotoModel(
      id: 'p1',
      shopId: 's1',
      bookingId: 'stay-1',
      roomId: 'r-1',
      roomName: 'A1',
      recordDate: day,
      sessionIndex: 0,
      sessionName: '上午場',
      previewUrl: 'https://img.example/1.jpg',
      previewStoragePath: 'path',
      createdAt: day,
      expiresAt: expiresAt,
    );
  }

  DailyCareReportCenterItem item({bool locked = false, DateTime? checkOut}) {
    return DailyCareReportCenterItem(
      id: 'stay-1_0',
      shopId: 's1',
      bookingId: 'stay-1',
      sessionIndex: 0,
      sessionName: '上午場',
      recordDate: day,
      entitlement: const DailyCareEntitlement(enabled: true, finalReports: 1),
      reportsLocked: locked,
      canOperate: !locked,
      checkInDate: DateTime(2026, 9, 20),
      checkOutDate: checkOut ?? DateTime(2026, 9, 22),
    );
  }

  test('DailyCarePhotoModel 讀得到 expiresAt，缺欄位時為 null', () {
    final DailyCarePhotoModel withExpiry = DailyCarePhotoModel.fromMap(
      id: 'p1',
      map: <String, dynamic>{
        'shopId': 's1',
        'bookingId': 'stay-1',
        'roomId': 'r-1',
        'roomName': 'A1',
        'recordDate': Timestamp.fromDate(day),
        'sessionIndex': 0,
        'sessionName': '上午場',
        'previewUrl': 'https://img.example/1.jpg',
        'previewStoragePath': 'path',
        'createdAt': Timestamp.fromDate(day),
        'expiresAt': Timestamp.fromDate(DateTime(2026, 9, 23, 8, 30)),
      },
    );
    expect(withExpiry.expiresAt, DateTime(2026, 9, 23, 8, 30));
    expect(withExpiry.hasExpired(now: DateTime(2026, 9, 22)), isFalse);
    expect(withExpiry.hasExpired(now: DateTime(2026, 9, 24)), isTrue);
    expect(withExpiry.expiringSoon(now: DateTime(2026, 9, 23, 2)), isTrue);

    final DailyCarePhotoModel legacy = DailyCarePhotoModel.fromMap(
      id: 'p2',
      map: <String, dynamic>{
        'shopId': 's1',
        'bookingId': 'stay-1',
        'recordDate': Timestamp.fromDate(day),
        'previewUrl': 'https://img.example/2.jpg',
        'previewStoragePath': 'path2',
        'createdAt': Timestamp.fromDate(day),
      },
    );
    expect(legacy.expiresAt, isNull);
    expect(legacy.hasExpired(now: DateTime(2026, 9, 24)), isFalse);
    expect(legacy.expiringSoon(now: DateTime(2026, 9, 24)), isFalse);
  });

  test('照片保存期限三種提示文案', () {
    // 一律用 UTC 基準，避免測試機時區影響。
    final DateTime now = DateTime.utc(2026, 9, 21, 2);

    final DailyCarePhotoNotice running = buildPhotoNotice(
      item: item(),
      photos: <DailyCarePhotoModel>[photo()],
      now: now,
    );
    expect(running.text, '照片將於服務結束後保留 24 小時，期限前請下載保存。');
    expect(running.warn, isFalse);

    final DailyCarePhotoNotice withDeadline = buildPhotoNotice(
      item: item(),
      photos: <DailyCarePhotoModel>[
        photo(expiresAt: DateTime.utc(2026, 9, 21, 20)),
      ],
      now: now,
    );
    expect(withDeadline.text.contains('照片保存至 2026/09/22 04:00（台灣時間）'), isTrue);
    expect(withDeadline.text.contains('到期後將由系統排程永久清除照片檔案，且無法復原。'), isTrue);
    expect(withDeadline.warn, isTrue);

    final DailyCarePhotoNotice far = buildPhotoNotice(
      item: item(),
      photos: <DailyCarePhotoModel>[
        photo(expiresAt: DateTime.utc(2026, 9, 30, 12)),
      ],
      now: now,
    );
    expect(far.warn, isFalse);

    final DailyCarePhotoNotice expired = buildPhotoNotice(
      item: item(locked: true),
      photos: const <DailyCarePhotoModel>[],
      now: now,
    );
    expect(expired.text, '照護照片保存期限已結束（文字照護紀錄仍會保留）。');
    expect(expired.text.contains('紀錄'), isTrue);
  });

  test('分享圖小字只在接近期限時出現', () {
    final DateTime now = DateTime.utc(2026, 9, 21, 2);
    expect(buildPhotoExpiryFootnote(expiresAt: null, now: now), '');
    expect(
      buildPhotoExpiryFootnote(expiresAt: DateTime.utc(2026, 9, 30), now: now),
      '',
    );
    expect(
      buildPhotoExpiryFootnote(expiresAt: DateTime.utc(2026, 9, 20), now: now),
      '',
    );
    expect(
      buildPhotoExpiryFootnote(
        expiresAt: DateTime.utc(2026, 9, 21, 20),
        now: now,
      ),
      '照護照片保存至 2026/09/22 04:00，請於期限前保存',
    );
  });

  test('工作清單只在接近期限時提示即將清除', () {
    final DateTime now = DateTime(2026, 9, 22, 10);
    final DailyCareReportCenterItem withPhoto = DailyCareReportCenterItem(
      id: 'stay-1_0',
      shopId: 's1',
      bookingId: 'stay-1',
      sessionIndex: 0,
      sessionName: '上午場',
      recordDate: day,
      entitlement: const DailyCareEntitlement(enabled: true, finalReports: 1),
      checkOutDate: DateTime(2026, 9, 22),
      photoCount: 2,
    );
    expect(withPhoto.photoRetentionDeadline, DateTime(2026, 9, 23));
    expect(withPhoto.photoExpiringSoon(now: now), isTrue);
    expect(withPhoto.photoExpiringSoon(now: DateTime(2026, 9, 21)), isFalse);
    expect(
      withPhoto.copyWith(photoCount: 0).photoExpiringSoon(now: now),
      isFalse,
    );
  });

  group('摘要統計圖門檻', () {
    DailyCareReportData data({required bool fullStay, required int completed}) {
      return DailyCareReportData(
        shopName: 'PetNest',
        shopLogoUrl: '',
        brandColor: const Color(0xFF6D4C41),
        title: '住宿照護報告',
        headerDateText: '2026/09/21',
        roomName: 'A1',
        roomTypeName: '豪華套房',
        petNames: '小米',
        checkInText: '2026/09/20',
        checkOutText: '2026/09/22',
        nightsText: '2 晚',
        bookingCode: 'PN1001',
        days: const <DailyCareReportDay>[],
        generatedAtText: '2026/09/22 10:00',
        isFullStay: fullStay,
        kind: DailyCareReportExportKind.summary,
        stats: DailyCareReportStats(
          stayNights: 2,
          expectedSessions: 4,
          completedSessions: completed,
        ),
      );
    }

    test('單場或資料不足不出統計圖', () {
      expect(
        DailyCareSummaryReportView.ratioChartsEligible(
          data(fullStay: false, completed: 1),
        ),
        isFalse,
      );
      expect(
        DailyCareSummaryReportView.ratioFields(
          data(fullStay: true, completed: 4),
        ),
        isEmpty,
      );
    });

    test('整次住宿或兩場以上完整紀錄才出統計圖', () {
      expect(
        DailyCareSummaryReportView.ratioChartsEligible(
          data(fullStay: true, completed: 1),
        ),
        isTrue,
      );
      expect(
        DailyCareSummaryReportView.ratioChartsEligible(
          data(fullStay: false, completed: 2),
        ),
        isTrue,
      );
    });

    testWidgets('資料不足時顯示資料不足，尚無統計圖', (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(720, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: SingleChildScrollView(
            child: DailyCareSummaryReportView(
              data: data(fullStay: false, completed: 1),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('資料不足，尚無統計圖'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });

  test('店家端產圖仍沿用既有 buildReport，不需要顧客登入', () {
    final DailyCareReportExportService export =
        DailyCareReportExportService.instance;
    final Map<String, dynamic> booking = <String, dynamic>{
      'bookingId': 'stay-1',
      'bookingCode': 'PN1001',
      'roomName': 'A1',
      'roomTypeName': '豪華套房',
      'customerName': '手動建立會員',
      'pets': <Map<String, dynamic>>[
        <String, dynamic>{'petId': 'p1', 'name': '小米'},
      ],
      'startDate': Timestamp.fromDate(DateTime(2026, 9, 20)),
      'endDate': Timestamp.fromDate(DateTime(2026, 9, 22)),
    };
    final DailyCareStayInfo stay = DailyCareStayInfo.fromBookingMap(booking);
    final DailyCareRecordModel record = DailyCareRecordModel(
      id: 'stay-1_20260921_0',
      shopId: 's1',
      bookingId: 'stay-1',
      roomId: 'r-1',
      roomName: 'A1',
      recordDate: day,
      sessionIndex: 0,
      sessionName: '上午場',
      values: const <String, dynamic>{
        'temperature': 26,
        'humidity': 55,
        'water': '一般',
        'generalNote': '今天活動力很好',
      },
      petNotes: const <String, String>{},
      photoCount: 1,
      createdAt: day,
      updatedAt: day,
    );

    final DailyCareReportData full = export.buildReport(
      booking: booking,
      shop: <String, dynamic>{'name': 'PetNest 測試店'},
      stay: stay,
      setting: const DailyCareSettingModel(enabled: true, sessionCount: 1),
      records: <DailyCareRecordModel>[record],
    );
    expect(full.shopName, 'PetNest 測試店');
    expect(full.days, isNotEmpty);
    expect(full.kind, DailyCareReportExportKind.fullStay);
    expect(export.fileName(data: full).endsWith('.png'), isTrue);

    final DailyCareReportData summary = export.buildReport(
      booking: booking,
      shop: <String, dynamic>{'name': 'PetNest 測試店'},
      stay: stay,
      setting: const DailyCareSettingModel(enabled: true, sessionCount: 1),
      records: <DailyCareRecordModel>[record],
      kind: DailyCareReportExportKind.summary,
    );
    expect(summary.stats, isNotNull);
    expect(summary.stats!.completedSessions, 1);
    expect(
      export.recordCareDates(
        stay: stay,
        records: <DailyCareRecordModel>[record],
      ),
      isNotEmpty,
    );
  });
}
