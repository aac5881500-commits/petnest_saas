import 'package:flutter_test/flutter_test.dart';
import 'package:excel/excel.dart';
import 'package:petnest_saas/core/models/report_table_spec.dart';
import 'package:petnest_saas/core/services/report_range.dart';
import 'package:petnest_saas/core/services/report_workbench_export.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';
import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';

ReportRange testRange() => ReportRange.custom(
  startDate: DateTime(2026, 10, 10),
  endDate: DateTime(2026, 10, 16),
);
Map<String, dynamic> booking(
  String id,
  int amount, {
  String kind = 'stay',
  DateTime? created,
  String user = 'u1',
}) => {
  'id': id,
  'userId': user,
  'createdAt': created ?? DateTime(2026, 10, 12),
  'startDate': DateTime(2026, 10, 13),
  'endDate': DateTime(2026, 10, 15),
  'status': 'confirmed',
  'bookingKind': kind,
  'nights': kind == 'daycare' ? 0 : 2,
  'totalPrice': amount,
  'roomTypeName': '獨立房',
};
void main() {
  test(
    'all presets have real fields, unique ids and a shared table family',
    () {
      expect(ReportTemplate.all.length, 8);
      expect(ReportTemplate.all.map((t) => t.id).toSet().length, 8);
      for (final t in ReportTemplate.all) {
        final spec = ReportTableSpec.preset(t);
        expect(spec.visibleFields.length, spec.columns.length);
        expect(spec.columns.toSet().length, spec.columns.length);
      }
    },
  );
  test('saved views normalize unknown fields and retain identity', () {
    final spec = ReportTableSpec.fromMap({
      'templateId': 'bad',
      'columns': ['paid', 'bad', 'paid'],
      'sources': ['stay', 'payments', 'unknown'],
    });
    expect(spec.columns, ['date', 'paid']);
    expect(spec.sources, {'stay', 'payments'});
    expect(ReportTableSpec.fromMap(spec.toMap()).toMap(), spec.toMap());
  });
  test(
    'unselected payments and member order sources hide dependent fields',
    () {
      var spec = ReportTableSpec.preset(
        ReportTemplate.byId('finance'),
      ).copyWith(sources: {'stay'});
      expect(
        spec.visibleFields.any(
          (f) => ['paid', 'unpaid', 'refund', 'store'].contains(f.id),
        ),
        isFalse,
      );
      spec = ReportTableSpec.preset(
        ReportTemplate.byId('members'),
      ).copyWith(sources: {'members'});
      expect(spec.visibleFields.map((f) => f.id), ['name', 'vip']);
    },
  );
  test('source selection excludes money and members from other sources', () {
    final bundle = ShopReportService.instance.buildSelectedData(
      range: testRange(),
      sources: {'stay', 'payments'},
      bookings: [
        booking('s', 1000),
        booking('d', 600, kind: 'daycare'),
      ],
      payments: [
        {
          'id': 'p',
          'bookingId': 's',
          'sourceType': PaymentSourceType.booking,
          'status': 'paid',
          'amount': 1000,
          'createdAt': DateTime(2026, 10, 12),
          'paidAt': DateTime(2026, 10, 12),
        },
        {
          'id': 'q',
          'bookingId': 'd',
          'sourceType': PaymentSourceType.booking,
          'status': 'paid',
          'amount': 600,
          'createdAt': DateTime(2026, 10, 12),
          'paidAt': DateTime(2026, 10, 12),
        },
      ],
      storeOrders: [
        {
          'id': 'store',
          'status': StoreConstants.statusPaid,
          'paymentStatus': StoreConstants.paymentPaid,
          'totalAmount': 500,
          'createdAt': DateTime(2026, 10, 12),
        },
      ],
      members: [
        {'id': 'u1', 'name': 'Ada', 'phone': '00123'},
      ],
    );
    expect(bundle.revenueKpi.orderAmount, 1000);
    expect(bundle.revenueKpi.paidAmount, 1000);
    expect(bundle.revenueKpi.storeRevenue, 0);
    expect(bundle.members, isEmpty);
  });
  test('daycare base charges are present without inventing stay nights', () {
    final b = ShopReportService.instance.buildSelectedData(
      range: testRange(),
      sources: {'daycare'},
      bookings: [booking('d', 600, kind: 'daycare')],
    );
    expect(b.revenueKpi.stayRevenue, 600);
    expect(b.dailySummary.nights, 0);
    expect(b.revenueKpi.orderAmount, 600);
  });
  test('member period spend is separated from lookback activity', () {
    final b = ShopReportService.instance.buildSelectedData(
      range: testRange(),
      sources: {'stay', 'members'},
      bookings: [
        booking('old', 400, created: DateTime(2026, 10, 1)),
        booking('new', 1000),
      ],
      members: [
        {
          'id': 'u1',
          'userId': 'u1',
          'name': 'Ada',
          'phone': '00123',
          'tags': ['vip'],
        },
      ],
    );
    expect(b.members.single.spend, 1000);
    expect(b.members.single.completedOrders, 1);
    expect(b.members.single.firstOrderAt, DateTime(2026, 10, 12));
    expect(b.members.single.spentLast30, isTrue);
    final oldOnly = ShopReportService.instance.buildSelectedData(
      range: testRange(),
      sources: {'stay', 'members'},
      bookings: [booking('old', 400, created: DateTime(2026, 10, 1))],
      members: [
        {'id': 'u1', 'name': 'Ada'},
      ],
    );
    expect(oldOnly.members.single.spend, 0);
    expect(oldOnly.members.single.spentLast30, isTrue);
    expect(oldOnly.members.single.firstOrderAt, isNull);
  });
  test(
    'one dataset applies numeric sort and search only to visible fields',
    () {
      final spec = ReportTableSpec.preset(
        ReportTemplate.byId('rooms'),
      ).copyWith(columns: ['name', 'revenue']);
      const dataset = ReportDataset(ReportTableKind.room, [
        {'name': 'A', 'revenue': 20, 'phone': 'secret'},
        {'name': 'B', 'revenue': 3},
      ]);
      expect(
        dataset.filtered(spec, '', 'revenue', true).map((r) => r['revenue']),
        [3, 20],
      );
      expect(dataset.filtered(spec, 'secret', 'name', true), isEmpty);
      expect(dataset.filtered(spec, 'a', 'name', true).length, 1);
    },
  );
  test(
    'Excel uses chosen columns and full filtered rows, numeric money and text phones',
    () {
      final spec = ReportTableSpec.preset(
        ReportTemplate.byId('members'),
      ).copyWith(columns: ['name', 'phone', 'spend']);
      final rows = List<Map<String, Object?>>.generate(
        31,
        (i) => {
          'name': i == 0 ? '=SUM(A1:A2)' : 'Member $i',
          'phone': '0012345',
          'spend': i + 100,
        },
      );
      final bytes = ReportWorkbenchExport.build(
        shopName: '測試店',
        range: testRange(),
        tables: [ReportExportTable(name: '會員/測試', spec: spec, rows: rows)],
        query: '',
      );
      final x = Excel.decodeBytes(bytes);
      expect(x.sheets.keys, contains('報表說明'));
      final sheet = x.sheets['會員測試']!;
      expect(sheet.maxRows, 33);
      expect(sheet.maxColumns, 3);
      expect(sheet.rows[1][0]!.value, isA<TextCellValue>());
      expect(sheet.rows[1][1]!.value.toString(), '0012345');
      expect(sheet.rows[1][2]!.value, isA<IntCellValue>());
      expect(sheet.rows[0].map((c) => c!.value.toString()), [
        '會員姓名',
        '電話',
        '期間消費金額',
      ]);
      expect(sheet.rows.last[2]!.value.toString(), '3565');
    },
  );
  test('report pack has separate tabs and never reinserts hidden fields', () {
    final daily = ReportTableSpec.preset(
      ReportTemplate.byId('overview'),
    ).copyWith(columns: ['date', 'orders']);
    final room = ReportTableSpec.preset(
      ReportTemplate.byId('rooms'),
    ).copyWith(columns: ['name', 'orders']);
    final bytes = ReportWorkbenchExport.build(
      shopName: '店',
      range: testRange(),
      query: 'Ada',
      tables: [
        ReportExportTable(
          name: '日報',
          spec: daily,
          rows: [
            {'date': DateTime(2026, 10, 12), 'orders': 2, 'paid': 999},
          ],
        ),
        ReportExportTable(
          name: '房型',
          spec: room,
          rows: [
            {'name': 'A', 'orders': 2, 'revenue': 999},
          ],
        ),
      ],
    );
    final x = Excel.decodeBytes(bytes);
    expect(x.sheets.length, 3);
    expect(x['日報'].maxColumns, 2);
    expect(x['房型'].maxColumns, 2);
  });
}
