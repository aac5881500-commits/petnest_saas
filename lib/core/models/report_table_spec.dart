import 'package:petnest_saas/core/models/shop_report_models.dart';
import 'package:petnest_saas/core/services/shop_report_format.dart';

enum ReportTableKind { daily, revenue, room, addon, member }

class ReportField {
  const ReportField(
    this.id,
    this.label, {
    this.money = false,
    this.numeric = false,
    this.total = false,
    this.source,
    this.help = '',
  });
  final String id, label, help;
  final bool money, numeric, total;
  final String? source;
  bool get isNumeric => money || numeric;
}

class ReportTemplate {
  const ReportTemplate(
    this.id,
    this.name,
    this.description,
    this.kind,
    this.columns,
    this.sources,
  );
  final String id, name, description;
  final ReportTableKind kind;
  final List<String> columns;
  final Set<String> sources;
  static const all = <ReportTemplate>[
    ReportTemplate(
      'overview',
      '營運日報',
      '每日接單、入住退房與服務金額',
      ReportTableKind.daily,
      ['date', 'orders', 'confirmed', 'in', 'out', 'nights', 'amount', 'paid'],
      {'stay', 'daycare', 'payments'},
    ),
    ReportTemplate(
      'frontdesk',
      '接待與房務',
      '聚焦入住、退房、晚數與寵物數',
      ReportTableKind.daily,
      ['date', 'in', 'out', 'nights', 'pets'],
      {'stay', 'daycare'},
    ),
    ReportTemplate(
      'finance',
      '營收與收款',
      '服務與商城金額、實收、待收與退款',
      ReportTableKind.revenue,
      [
        'label',
        'orders',
        'service',
        'addon',
        'store',
        'amount',
        'paid',
        'unpaid',
        'refund',
      ],
      {'stay', 'daycare', 'store', 'payments'},
    ),
    ReportTemplate(
      'reconciliation',
      '收款對帳',
      '依期間核對訂單、收款及退款',
      ReportTableKind.revenue,
      ['label', 'amount', 'paid', 'unpaid', 'refund', 'discount', 'coupon'],
      {'stay', 'daycare', 'store', 'payments'},
    ),
    ReportTemplate(
      'rooms',
      '房型分析',
      '房型接單、住宿晚數、寵物與房費',
      ReportTableKind.room,
      ['name', 'orders', 'nights', 'pets', 'revenue', 'average'],
      {'stay', 'daycare'},
    ),
    ReportTemplate(
      'addons',
      '加購分析',
      '各服務購買次數、數量與金額',
      ReportTableKind.addon,
      ['name', 'type', 'orders', 'quantity', 'revenue', 'average'],
      {'stay', 'daycare'},
    ),
    ReportTemplate(
      'members',
      '會員消費',
      '本店會員在查詢期間的有效訂單與消費',
      ReportTableKind.member,
      ['name', 'orders', 'spend', 'average', 'last', 'vip'],
      {'stay', 'daycare', 'members'},
    ),
    ReportTemplate(
      'directory',
      '會員名冊',
      '聯絡資訊、VIP 與黑名單狀態',
      ReportTableKind.member,
      ['name', 'vip', 'blocked'],
      {'members'},
    ),
  ];
  static ReportTemplate byId(String id) =>
      all.firstWhere((t) => t.id == id, orElse: () => all.first);
}

class ReportTableSpec {
  const ReportTableSpec({
    required this.templateId,
    required this.columns,
    required this.sources,
    this.monthly = false,
    this.hideEmpty = false,
    this.memberFilter = 'all',
    this.compact = false,
  });
  final String templateId, memberFilter;
  final List<String> columns;
  final Set<String> sources;
  final bool monthly, hideEmpty, compact;
  ReportTableKind get kind => ReportTemplate.byId(templateId).kind;
  factory ReportTableSpec.preset(ReportTemplate template) => ReportTableSpec(
    templateId: template.id,
    columns: template.columns,
    sources: template.sources,
  );
  ReportTableSpec copyWith({
    String? templateId,
    List<String>? columns,
    Set<String>? sources,
    bool? monthly,
    bool? hideEmpty,
    String? memberFilter,
    bool? compact,
  }) => ReportTableSpec(
    templateId: templateId ?? this.templateId,
    columns: columns ?? this.columns,
    sources: sources ?? this.sources,
    monthly: monthly ?? this.monthly,
    hideEmpty: hideEmpty ?? this.hideEmpty,
    memberFilter: memberFilter ?? this.memberFilter,
    compact: compact ?? this.compact,
  );
  Map<String, dynamic> toMap() => {
    'templateId': templateId,
    'columns': columns,
    'sources': sources.toList(),
    'monthly': monthly,
    'hideEmpty': hideEmpty,
    'memberFilter': memberFilter,
    'compact': compact,
  };
  factory ReportTableSpec.fromMap(Map raw) {
    final template = ReportTemplate.byId('${raw['templateId'] ?? ''}');
    final allowed = ReportDataset.fields(
      template.kind,
    ).map((f) => f.id).toSet();
    final columns =
        (raw['columns'] is List
                ? (raw['columns'] as List).whereType<String>()
                : template.columns)
            .where(allowed.contains)
            .toSet()
            .toList();
    final sources =
        (raw['sources'] is List
                ? (raw['sources'] as List).whereType<String>()
                : template.sources)
            .where(sourceNames.containsKey)
            .toSet();
    return ReportTableSpec(
      templateId: template.id,
      columns: {
        ReportDataset.fields(template.kind).first.id,
        ...columns,
      }.toList(),
      sources: sources,
      monthly: raw['monthly'] == true,
      hideEmpty: raw['hideEmpty'] == true,
      memberFilter:
          [
            'all',
            'vip',
            'blocked',
            'active30',
            'inactive30',
          ].contains(raw['memberFilter'])
          ? '${raw['memberFilter']}'
          : 'all',
      compact: raw['compact'] == true,
    );
  }
  Set<String> get allowedSources => switch (kind) {
    ReportTableKind.daily => {'stay', 'daycare', 'payments'},
    ReportTableKind.revenue => {'stay', 'daycare', 'store', 'payments'},
    ReportTableKind.member => {'stay', 'daycare', 'members'},
    _ => {'stay', 'daycare'},
  };
  static const sourceNames = {
    'stay': '住宿訂單',
    'daycare': '安親訂單',
    'store': '商城訂單',
    'payments': '實收與退款',
    'members': '本店會員名單',
  };
  List<ReportField> get visibleFields => columns
      .map(
        (id) => ReportDataset.fields(kind).where((f) => f.id == id).firstOrNull,
      )
      .whereType<ReportField>()
      .where((f) => available(f))
      .toList();
  bool available(ReportField field) {
    if (field.source != null && !sources.contains(field.source)) return false;
    if (kind == ReportTableKind.member &&
        field.id != 'name' &&
        field.id != 'phone' &&
        field.id != 'vip' &&
        field.id != 'blocked' &&
        !sources.contains('stay') &&
        !sources.contains('daycare')) {
      return false;
    }
    return true;
  }
}

class ReportDataset {
  const ReportDataset(this.kind, this.rows);
  final ReportTableKind kind;
  final List<Map<String, Object?>> rows;
  static List<ReportField> fields(ReportTableKind kind) => switch (kind) {
    ReportTableKind.daily => const [
      ReportField('date', '日期'),
      ReportField('orders', '新增訂單', numeric: true, total: true),
      ReportField('confirmed', '有效訂單', numeric: true, total: true),
      ReportField('cancelled', '取消訂單', numeric: true, total: true),
      ReportField('in', '入住數', numeric: true, total: true),
      ReportField('out', '退房完成數', numeric: true, total: true),
      ReportField('nights', '住宿晚數', numeric: true, total: true),
      ReportField('pets', '寵物數', numeric: true, total: true),
      ReportField('amount', '訂單金額', money: true, total: true),
      ReportField('paid', '期間實收', money: true, total: true, source: 'payments'),
      ReportField('average', '平均客單', money: true),
      ReportField('cancelRate', '取消率'),
    ],
    ReportTableKind.revenue => const [
      ReportField('label', '期間'),
      ReportField('orders', '有效訂單', numeric: true, total: true),
      ReportField('service', '住宿／安親房費', money: true, total: true),
      ReportField('addon', '加購金額', money: true, total: true),
      ReportField('store', '商城金額', money: true, total: true, source: 'store'),
      ReportField('amount', '訂單金額', money: true, total: true),
      ReportField('paid', '期間實收', money: true, total: true, source: 'payments'),
      ReportField(
        'unpaid',
        '待收款估計',
        money: true,
        total: true,
        source: 'payments',
      ),
      ReportField('refund', '退款', money: true, total: true, source: 'payments'),
      ReportField('discount', '訂單折扣', money: true, total: true),
      ReportField('coupon', '優惠券折抵', money: true, total: true),
      ReportField('surcharge', '特殊日期加價', money: true, total: true),
    ],
    ReportTableKind.room => const [
      ReportField('name', '房型'),
      ReportField('orders', '有效訂單', numeric: true, total: true),
      ReportField('nights', '住宿晚數', numeric: true, total: true),
      ReportField('pets', '寵物數', numeric: true, total: true),
      ReportField('revenue', '房費及特殊加價', money: true, total: true),
      ReportField('average', '平均每筆房費', money: true),
    ],
    ReportTableKind.addon => const [
      ReportField('name', '加購服務'),
      ReportField('type', '類型'),
      ReportField('orders', '購買次數', numeric: true, total: true),
      ReportField('quantity', '數量', numeric: true, total: true),
      ReportField('revenue', '加購金額', money: true, total: true),
      ReportField('average', '平均單價', money: true),
    ],
    ReportTableKind.member => const [
      ReportField('name', '會員姓名'),
      ReportField('phone', '電話', source: 'members'),
      ReportField('orders', '期間有效訂單', numeric: true, total: true),
      ReportField('spend', '期間消費金額', money: true, total: true),
      ReportField('average', '期間平均客單', money: true),
      ReportField('first', '期間首次訂單日'),
      ReportField('last', '期間最近訂單日'),
      ReportField('vip', '常客 VIP'),
      ReportField('blocked', '黑名單'),
      ReportField('d30', '近 30 天消費'),
      ReportField('d90', '近 90 天消費'),
    ],
  };
  factory ReportDataset.fromBundle(
    ShopReportBundle bundle,
    ReportTableSpec spec,
  ) {
    final rows = <Map<String, Object?>>[];
    switch (spec.kind) {
      case ReportTableKind.daily:
        for (final r in bundle.daily) {
          if (spec.hideEmpty && !r.hasActivity) continue;
          rows.add({
            'date': r.date,
            'orders': r.newOrders,
            'confirmed': r.confirmedOrders,
            'cancelled': r.cancelledOrders,
            'in': r.checkIns,
            'out': r.checkOuts,
            'nights': r.nights,
            'pets': r.pets,
            'amount': r.orderAmount,
            'paid': r.paidAmount,
            'average': r.averageOrderAmount,
            'cancelRate': ShopReportFormat.percent(r.cancelRate),
          });
        }
      case ReportTableKind.revenue:
        for (final r
            in spec.monthly ? bundle.revenueByMonth : bundle.revenueByDay) {
          if (spec.hideEmpty && !r.hasActivity) continue;
          rows.add({
            'label': r.label,
            'orders': r.orderCount,
            'service': r.stayRevenue,
            'addon': r.addonRevenue,
            'store': r.storeRevenue,
            'amount': r.orderAmount,
            'paid': r.paidAmount,
            'unpaid': r.unpaidAmount,
            'refund': r.refundAmount,
            'discount': r.discountAmount,
            'coupon': r.couponAmount,
            'surcharge': r.surchargeAmount,
          });
        }
      case ReportTableKind.room:
        for (final r in bundle.roomTypes) {
          rows.add({
            'name': r.roomTypeName,
            'orders': r.orderCount,
            'nights': r.nights,
            'pets': r.pets,
            'revenue': r.revenue,
            'average': r.averageOrderRevenue,
          });
        }
      case ReportTableKind.addon:
        for (final r in bundle.addons) {
          rows.add({
            'name': r.name,
            'type': r.typeLabel,
            'orders': r.purchaseCount,
            'quantity': r.quantity,
            'revenue': r.revenue,
            'average': r.averagePrice,
          });
        }
      case ReportTableKind.member:
        for (final r in bundle.members) {
          if (spec.memberFilter == 'vip' && !r.isVip ||
              spec.memberFilter == 'blocked' && !r.isBlacklisted ||
              spec.memberFilter == 'active30' &&
                  (spec.sources.contains('stay') ||
                      spec.sources.contains('daycare')) &&
                  !r.spentLast30 ||
              spec.memberFilter == 'inactive30' &&
                  (spec.sources.contains('stay') ||
                      spec.sources.contains('daycare')) &&
                  r.spentLast30) {
            continue;
          }
          rows.add({
            'name': r.name,
            'phone': r.phone,
            'orders': r.completedOrders,
            'spend': r.spend,
            'average': r.averageSpend,
            'first': r.firstOrderAt,
            'last': r.lastOrderAt,
            'vip': r.isVip,
            'blocked': r.isBlacklisted,
            'd30': r.spentLast30,
            'd90': r.spentLast90,
          });
        }
    }
    return ReportDataset(spec.kind, rows);
  }
  static String display(Object? value, ReportField field) {
    if (value == null || value == '') return '—';
    if (value is DateTime) return ShopReportFormat.date.format(value);
    if (value is bool) return value ? '是' : '否';
    if (value is num) {
      return field.money
          ? ShopReportFormat.money(value.toInt())
          : ShopReportFormat.number(value.toInt());
    }
    return '$value';
  }

  List<Map<String, Object?>> filtered(
    ReportTableSpec spec,
    String query,
    String sortId,
    bool ascending,
  ) {
    final fields = spec.visibleFields;
    final tokens = query
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty);
    final result = rows.where((row) {
      final text = fields
          .map((f) => display(row[f.id], f))
          .join(' ')
          .toLowerCase();
      return tokens.every(text.contains);
    }).toList();
    result.sort((a, b) {
      final av = a[sortId], bv = b[sortId];
      final int compared;
      if (av == null || bv == null) {
        compared = av == bv
            ? 0
            : av == null
            ? 1
            : -1;
      } else if (av is num && bv is num) {
        compared = av.compareTo(bv);
      } else if (av is DateTime && bv is DateTime) {
        compared = av.compareTo(bv);
      } else {
        compared = '$av'.compareTo('$bv');
      }
      return ascending ? compared : -compared;
    });
    return result;
  }
}
