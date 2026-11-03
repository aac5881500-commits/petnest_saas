import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/constants/shop_modules.dart';
import 'package:petnest_saas/core/models/shop_report_models.dart';
import 'package:petnest_saas/core/services/report_range.dart';
import 'package:petnest_saas/core/services/shop_report_service.dart';

class OwnerBusinessSource {
  const OwnerBusinessSource(
    this.id,
    this.module,
    this.label, {
    this.ready = true,
  });
  final String id, module, label;
  final bool ready;
}

class OwnerReportWorkspace {
  static const catalog = [
    OwnerBusinessSource('stay', ShopModules.catHotel, '貓咪住宿'),
    OwnerBusinessSource('daycare', ShopModules.catHotel, '安親／日托'),
    OwnerBusinessSource('store', ShopModules.store, '商城商品'),
    OwnerBusinessSource(
      'dog_hotel',
      ShopModules.dogHotel,
      '狗狗住宿',
      ready: false,
    ),
    OwnerBusinessSource('grooming', ShopModules.grooming, '寵物美容', ready: false),
    OwnerBusinessSource('hospital', ShopModules.hospital, '動物醫院', ready: false),
  ];
  static List<OwnerBusinessSource> available(Set<String> modules) =>
      catalog.where((s) => modules.contains(s.module)).toList();
  static Set<String> sources(Set<String> modules, String scope) =>
      available(modules)
          .where((s) => s.ready && (scope == 'all' || s.id == scope))
          .map((s) => s.id)
          .toSet();
  static bool isComplete(Set<String> modules, String scope) =>
      scope == 'all' &&
      sources(modules, scope).isNotEmpty &&
      available(modules).every((source) => source.ready);
  static String label(String scope) => scope == 'all'
      ? '整店（已串接業務）'
      : catalog.firstWhere((s) => s.id == scope).label;
  static Map<String, ShopReportBundle> build({
    required ReportRange range,
    required Set<String> sources,
    List<Map<String, dynamic>> bookings = const [],
    List<Map<String, dynamic>> payments = const [],
    List<Map<String, dynamic>> storeOrders = const [],
  }) {
    ShopReportBundle calculate(Set<String> selected) =>
        ShopReportService.instance.buildSelectedData(
          range: range,
          sources: {...selected, 'payments'},
          bookings: bookings,
          payments: payments,
          storeOrders: storeOrders,
        );
    return {
      'all': calculate(sources),
      for (final source in sources) source: calculate({source}),
    };
  }
}

/// A private entry can come from Firestore or the in-memory demo. Demo entries have no remote reference.
class OwnerLedgerEntry {
  OwnerLedgerEntry({
    required this.id,
    required Map<String, dynamic> value,
    this.reference,
  }) : _value = Map.unmodifiable(value);
  factory OwnerLedgerEntry.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      OwnerLedgerEntry(id: doc.id, value: doc.data(), reference: doc.reference);
  final String id;
  final Map<String, dynamic> _value;
  final DocumentReference<Map<String, dynamic>>? reference;
  Map<String, dynamic> data() => _value;
}

class OwnerReportDemo {
  static const modules = {
    'cat_hotel',
    'store',
    'dog_hotel',
    'grooming',
    'hospital',
  };
  static Map<String, ShopReportBundle> reports(
    ReportRange range,
    Set<String> sources,
  ) {
    final bookings = <Map<String, dynamic>>[],
        payments = <Map<String, dynamic>>[],
        orders = <Map<String, dynamic>>[];
    // Stable per-month examples: reopening a month produces the same report.
    final variation = (range.startDate.year * 12 + range.startDate.month) % 5;
    for (var i = 0; i < 18; i++) {
      final date = Timestamp.fromDate(
        DateTime(range.startDate.year, range.startDate.month, 1 + i),
      );
      final daycare = i % 3 == 0;
      final amount = (daycare ? 900 : 3600) + variation * 100 + i * 30;
      final id = 'demo-booking-$i';
      bookings.add({
        'id': id,
        'bookingKind': daycare ? 'daycare' : 'accommodation',
        'status': i == 16 ? 'cancelled' : 'completed',
        'createdAt': date,
        'startDate': date,
        'endDate': date,
        'roomTypeName': daycare
            ? '示範安親區'
            : i % 2 == 0
            ? '示範景觀房'
            : '示範標準房',
        'totalPrice': amount,
        'nights': daycare ? 0 : 3,
        'petIds': ['demo-pet-$i'],
        'paidAmount': i == 17 ? 0 : amount,
      });
      if (i < 16) {
        payments.add({
          'id': 'demo-pay-$i',
          'bookingId': id,
          'sourceType': 'booking',
          'amount': amount,
          'status': i == 3 ? 'partially_refunded' : 'paid',
          'refundedAmount': i == 3 ? 300 : 0,
          'createdAt': date,
          'paidAt': date,
        });
      }
    }
    for (var i = 0; i < 10; i++) {
      final date = Timestamp.fromDate(
        DateTime(range.startDate.year, range.startDate.month, 2 + i * 2),
      );
      final amount = 600 + variation * 50 + i * 80;
      orders.add({
        'id': 'demo-store-$i',
        'status': 'completed',
        'createdAt': date,
        'totalAmount': amount,
        'paymentStatus': i == 9 ? 'unpaid' : 'paid',
      });
      if (i < 9) {
        payments.add({
          'id': 'demo-store-pay-$i',
          'storeOrderId': 'demo-store-$i',
          'sourceType': 'store_order',
          'status': 'paid',
          'amount': amount,
          'createdAt': date,
          'paidAt': date,
        });
      }
    }
    return OwnerReportWorkspace.build(
      range: range,
      sources: sources,
      bookings: bookings,
      payments: payments,
      storeOrders: orders,
    );
  }

  static List<OwnerLedgerEntry> ledger(DateTime month) {
    final extra = (month.month % 3) * 1000;
    final rows = <Map<String, dynamic>>[
      {
        'kind': 'salary',
        'name': '示範員工・小林',
        'amount': 32000 + extra,
        'note': '虛構：本薪＋獎金',
      },
      {'kind': 'salary', 'name': '示範員工・小陳', 'amount': 35000, 'note': '虛構：本月薪資'},
      {
        'kind': 'expense',
        'name': '房租（示範）',
        'amount': 18000,
        'note': '虛構：整店共用成本',
      },
      {
        'kind': 'expense',
        'name': '水電（示範）',
        'amount': 4200 + extra,
        'note': '虛構：整店共用成本',
      },
      {'kind': 'expense', 'name': '耗材（示範）', 'amount': 2600, 'note': '虛構資料'},
      {
        'kind': 'income',
        'name': '其他收入（示範）',
        'amount': 5000,
        'note': '虛構資料，非系統訂單',
      },
    ];
    return [
      for (var i = 0; i < rows.length; i++)
        OwnerLedgerEntry(id: 'demo-entry-$i', value: rows[i]),
    ];
  }
}
