// lib/core/services/shop_report_service.dart
// 📊 營運報表：唯讀統計。金額公式集中在此，各頁面不要各算一套。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/core/models/shop_report_models.dart';
import 'package:petnest_saas/core/services/report_range.dart';

class ShopReportService {
  ShopReportService._();

  static final ShopReportService instance = ShopReportService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const Set<String> _bookingRevenueStatuses = <String>{
    'confirmed',
    'checked_in',
    'completed',
  };

  static const Set<String> _storeRevenueStatuses = <String>{
    StoreConstants.statusPaid,
    StoreConstants.statusPreparing,
    StoreConstants.statusReadyForPickup,
    StoreConstants.statusCompleted,
  };

  Future<ShopReportBundle> load({
    required String shopId,
    required ReportRange range,
    bool includeMembers = false,
    bool includeTrend = false,
  }) async {
    final String id = shopId.trim();
    final DateTime start = range.startDate;
    final DateTime end = range.endDate;
    final DateTime trendStart = DateTime(end.year, end.month - 5, 1);
    final DateTime bookingQueryStart =
        includeTrend && trendStart.isBefore(start) ? trendStart : start;

    final List<QuerySnapshot<Map<String, dynamic>>> snaps =
        await Future.wait(<Future<QuerySnapshot<Map<String, dynamic>>>>[
          _bookingsCreated(id, bookingQueryStart, end),
          _bookingsByStartDate(
            id,
            start.subtract(const Duration(days: 120)),
            end,
          ),
          _payments(id, start.subtract(const Duration(days: 90)), end),
          _storeOrders(id, bookingQueryStart, end),
        ]);

    final Map<String, Map<String, dynamic>> bookings =
        <String, Map<String, dynamic>>{};
    _mergeDocs(bookings, snaps[0]);
    _mergeDocs(bookings, snaps[1]);

    final List<Map<String, dynamic>> payments = snaps[2].docs
        .map(_docMap)
        .toList();
    final List<Map<String, dynamic>> storeOrders = snaps[3].docs
        .map(_docMap)
        .toList();
    List<Map<String, dynamic>> members = const <Map<String, dynamic>>[];
    if (includeMembers) {
      members = (await _members(id)).docs.map(_docMap).toList();
    }

    List<Map<String, dynamic>> lifetimeBookings = bookings.values.toList();
    if (includeMembers) {
      final QuerySnapshot<Map<String, dynamic>> all = await _db
          .collection('bookings')
          .where('shopId', isEqualTo: id)
          .get();
      lifetimeBookings = all.docs.map(_docMap).toList();
    }

    return _build(
      range: range,
      bookings: bookings.values.toList(),
      lifetimeBookings: lifetimeBookings,
      payments: payments,
      storeOrders: storeOrders,
      members: members,
      includeTrend: includeTrend,
      trendStart: trendStart,
    );
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _bookingsCreated(
    String shopId,
    DateTime start,
    DateTime end,
  ) {
    return _db
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: true)
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _bookingsByStartDate(
    String shopId,
    DateTime start,
    DateTime end,
  ) {
    return _db
        .collection('bookings')
        .where('shopId', isEqualTo: shopId)
        .where('startDate', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startDate', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('startDate')
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _payments(
    String shopId,
    DateTime start,
    DateTime end,
  ) {
    return _db
        .collection('payments')
        .where('shopId', isEqualTo: shopId)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: true)
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _storeOrders(
    String shopId,
    DateTime start,
    DateTime end,
  ) {
    return _db
        .collection('shops')
        .doc(shopId)
        .collection(StoreConstants.ordersCollection)
        .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('createdAt', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('createdAt', descending: true)
        .get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> _members(String shopId) {
    return _db.collection('shops').doc(shopId).collection('members').get();
  }

  ShopReportBundle _build({
    required ReportRange range,
    required List<Map<String, dynamic>> bookings,
    required List<Map<String, dynamic>> lifetimeBookings,
    required List<Map<String, dynamic>> payments,
    required List<Map<String, dynamic>> storeOrders,
    required List<Map<String, dynamic>> members,
    required bool includeTrend,
    required DateTime trendStart,
  }) {
    final DateTime start = range.startDate;
    final DateTime end = range.endDate;
    final Map<String, _DayAcc> days = <String, _DayAcc>{};
    for (
      DateTime d = DateTime(start.year, start.month, start.day);
      !d.isAfter(end);
      d = d.add(const Duration(days: 1))
    ) {
      days[_dateKey(d)] = _DayAcc(d);
    }

    final Map<String, int> paidByBooking = <String, int>{};
    final Map<String, int> paidByStore = <String, int>{};
    final Map<String, _RevAcc> monthRev = <String, _RevAcc>{};
    int paidStay = 0;
    int paidStore = 0;
    int refundTotal = 0;

    for (final Map<String, dynamic> pay in payments) {
      final String status = _str(pay['status']);
      final int amount = _int(pay['amount']);
      final DateTime when =
          _dateOf(pay['paidAt']) ?? _dateOf(pay['createdAt']) ?? start;
      final bool inRange = _inRange(when, start, end);
      final String source = PaymentSourceType.resolve(
        pay['sourceType'],
        bookingId: _str(pay['bookingId']),
      );
      int recognizedPaid = 0;
      int recognizedRefund = 0;
      if (PaymentTransactionStatus.isPaid(status)) {
        recognizedPaid = amount;
      } else if (status == PaymentTransactionStatus.partiallyRefunded) {
        final int refund = _int(pay['refundedAmount']);
        recognizedRefund = refund > 0 ? refund : 0;
        recognizedPaid = (amount - recognizedRefund).clamp(0, amount);
      } else if (status == PaymentTransactionStatus.refunded) {
        final int refund = _int(pay['refundedAmount']);
        recognizedRefund = refund > 0 ? refund : amount;
      }
      if (recognizedPaid > 0 && inRange) {
        if (source == PaymentSourceType.storeOrder) {
          paidStore += recognizedPaid;
          final String oid = _str(pay['storeOrderId']);
          if (oid.isNotEmpty) {
            paidByStore[oid] = (paidByStore[oid] ?? 0) + recognizedPaid;
          }
          days[_dateKey(when)]?.paidStore += recognizedPaid;
        } else {
          paidStay += recognizedPaid;
          final String bid = _str(pay['bookingId']);
          if (bid.isNotEmpty) {
            paidByBooking[bid] = (paidByBooking[bid] ?? 0) + recognizedPaid;
          }
          days[_dateKey(when)]?.paidStay += recognizedPaid;
        }
      }
      if (recognizedRefund > 0 && inRange) {
        refundTotal += recognizedRefund;
        days[_dateKey(when)]?.refundAmount += recognizedRefund;
        monthRev.putIfAbsent(_monthKey(when), _RevAcc.new).refund +=
            recognizedRefund;
      }
    }

    int stayOrderAmount = 0;
    int stayRoom = 0;
    int stayAddon = 0;
    int stayDiscount = 0;
    int stayCoupon = 0;
    int staySurcharge = 0;
    int stayUnpaid = 0;
    int stayNights = 0;
    int stayPets = 0;
    int newOrders = 0;
    int confirmedOrders = 0;
    int cancelledOrders = 0;

    final Map<String, _RoomAcc> rooms = <String, _RoomAcc>{};
    final Map<String, _AddonAcc> addonMap = <String, _AddonAcc>{};

    for (final Map<String, dynamic> booking in bookings) {
      final DateTime? created = _dateOf(booking['createdAt']);
      if (created == null) {
        continue;
      }
      final bool createdInRange = _inRange(created, start, end);
      final String status = _str(booking['status']);
      final bool revenue = _bookingRevenueStatuses.contains(status);
      final _Money money = _bookingMoney(booking);
      final int nights = _int(booking['nights']);
      final int pets = _petCount(booking);
      final String dayKey = _dateKey(created);
      final _DayAcc? day = days[dayKey];
      final DateTime? checkInAt =
          _dateOf(booking['checkInAt']) ?? _dateOf(booking['startDate']);
      final DateTime? checkOutAt =
          _dateOf(booking['checkOutAt']) ?? _dateOf(booking['endDate']);

      if (createdInRange) {
        newOrders++;
        day?.newOrders++;
        if (status == 'cancelled') {
          cancelledOrders++;
          day?.cancelledOrders++;
        } else if (revenue) {
          confirmedOrders++;
          day?.confirmedOrders++;
          day?.nights += nights;
          day?.pets += pets;
          day?.stayOrderAmount += money.orderAmount;
          day?.stayRevenue += money.room;
          day?.addonRevenue += money.addon;
          day?.discountAmount += money.discount;
          day?.couponAmount += money.coupon;
          day?.surchargeAmount += money.surcharge;
          stayOrderAmount += money.orderAmount;
          stayRoom += money.room;
          stayAddon += money.addon;
          stayDiscount += money.discount;
          stayCoupon += money.coupon;
          staySurcharge += money.surcharge;
          stayNights += nights;
          stayPets += pets;
          final String bid = _str(booking['id']);
          final int paid = paidByBooking[bid] ?? _int(booking['paidAmount']);
          final int unpaid = (money.orderAmount - paid).clamp(
            0,
            money.orderAmount,
          );
          stayUnpaid += unpaid;
          day?.stayUnpaid += unpaid;
          final String roomName = _roomTypeName(booking);
          final _RoomAcc roomAcc = rooms.putIfAbsent(
            roomName,
            () => _RoomAcc(roomName),
          );
          roomAcc.orders++;
          roomAcc.nights += nights;
          roomAcc.pets += pets;
          roomAcc.revenue += money.room + money.surcharge;
          _collectAddons(addonMap, booking);
          final String monthKey = _monthKey(created);
          final _RevAcc month = monthRev.putIfAbsent(monthKey, _RevAcc.new);
          month.orders++;
          month.stay += money.room;
          month.addon += money.addon;
          month.discount += money.discount;
          month.coupon += money.coupon;
          month.surcharge += money.surcharge;
          month.orderAmount += money.orderAmount;
          month.unpaid += unpaid;
        }
      }

      if (checkInAt != null &&
          _inRange(checkInAt, start, end) &&
          (status == 'checked_in' || status == 'completed')) {
        days[_dateKey(checkInAt)]?.checkIns++;
      }
      if (checkOutAt != null &&
          _inRange(checkOutAt, start, end) &&
          status == 'completed') {
        days[_dateKey(checkOutAt)]?.checkOuts++;
      }
    }

    int storeRevenue = 0;
    int storeUnpaid = 0;
    int storeOrdersCount = 0;
    for (final Map<String, dynamic> order in storeOrders) {
      final DateTime? created = _dateOf(order['createdAt']);
      if (created == null || !_inRange(created, start, end)) {
        continue;
      }
      final String status = _str(order['status']);
      if (!_storeRevenueStatuses.contains(status)) {
        continue;
      }
      storeOrdersCount++;
      final int amount = _int(order['totalAmount']);
      storeRevenue += amount;
      final String oid = _str(order['id']);
      final int paid =
          paidByStore[oid] ??
          (_str(order['paymentStatus']) == StoreConstants.paymentPaid
              ? amount
              : 0);
      final int unpaid = (amount - paid).clamp(0, amount);
      storeUnpaid += unpaid;
      final _DayAcc? day = days[_dateKey(created)];
      day?.storeOrders++;
      day?.storeRevenue += amount;
      day?.storeUnpaid += unpaid;
      final String monthKey = _monthKey(created);
      final _RevAcc month = monthRev.putIfAbsent(monthKey, _RevAcc.new);
      month.orders++;
      month.store += amount;
      month.orderAmount += amount;
      month.unpaid += unpaid;
    }

    for (final Map<String, dynamic> pay in payments) {
      final String status = _str(pay['status']);
      final int amount = _int(pay['amount']);
      int recognizedPaid = 0;
      if (PaymentTransactionStatus.isPaid(status)) {
        recognizedPaid = amount;
      } else if (status == PaymentTransactionStatus.partiallyRefunded) {
        final int refund = _int(pay['refundedAmount']);
        recognizedPaid = (amount - (refund > 0 ? refund : 0)).clamp(0, amount);
      }
      if (recognizedPaid <= 0) {
        continue;
      }
      final DateTime when =
          _dateOf(pay['paidAt']) ?? _dateOf(pay['createdAt']) ?? start;
      if (!_inRange(when, start, end)) {
        continue;
      }
      monthRev.putIfAbsent(_monthKey(when), _RevAcc.new).paid += recognizedPaid;
    }

    final List<DailyOpsRow> daily =
        days.values.map((_DayAcc d) {
            return DailyOpsRow(
              date: d.date,
              newOrders: d.newOrders,
              confirmedOrders: d.confirmedOrders,
              cancelledOrders: d.cancelledOrders,
              checkIns: d.checkIns,
              checkOuts: d.checkOuts,
              nights: d.nights,
              pets: d.pets,
              orderAmount: d.stayOrderAmount,
              paidAmount: d.paidStay,
            );
          }).toList()
          ..sort((DailyOpsRow a, DailyOpsRow b) => b.date.compareTo(a.date));

    final int avg = confirmedOrders <= 0
        ? 0
        : (stayOrderAmount / confirmedOrders).round();
    final double cancelRate = newOrders <= 0 ? 0 : cancelledOrders / newOrders;
    final int combinedOrders = confirmedOrders + storeOrdersCount;
    final int combinedAmount = stayOrderAmount + storeRevenue;
    final int combinedAvg = combinedOrders <= 0
        ? 0
        : (combinedAmount / combinedOrders).round();

    final DailyOpsSummary dailySummary = DailyOpsSummary(
      orders: newOrders,
      nights: stayNights,
      orderAmount: stayOrderAmount,
      paidAmount: paidStay,
      averageOrderAmount: avg,
      cancelRate: cancelRate,
    );

    final List<RevenuePeriodRow> revenueDays =
        days.values.map((_DayAcc d) {
          return RevenuePeriodRow(
            label: _dateKey(d.date).replaceAll('-', '/'),
            orderCount: d.confirmedOrders + d.storeOrders,
            stayRevenue: d.stayRevenue,
            addonRevenue: d.addonRevenue,
            storeRevenue: d.storeRevenue,
            discountAmount: d.discountAmount,
            couponAmount: d.couponAmount,
            surchargeAmount: d.surchargeAmount,
            orderAmount: d.stayOrderAmount + d.storeRevenue,
            paidAmount: d.paidStay + d.paidStore,
            unpaidAmount: d.stayUnpaid + d.storeUnpaid,
            refundAmount: d.refundAmount,
          );
        }).toList()..sort(
          (RevenuePeriodRow a, RevenuePeriodRow b) =>
              b.label.compareTo(a.label),
        );

    final List<RevenuePeriodRow> revenueMonths =
        monthRev.entries.map((MapEntry<String, _RevAcc> e) {
          final _RevAcc m = e.value;
          return RevenuePeriodRow(
            label: e.key,
            orderCount: m.orders,
            stayRevenue: m.stay,
            addonRevenue: m.addon,
            storeRevenue: m.store,
            discountAmount: m.discount,
            couponAmount: m.coupon,
            surchargeAmount: m.surcharge,
            orderAmount: m.orderAmount,
            paidAmount: m.paid,
            unpaidAmount: m.unpaid,
            refundAmount: m.refund,
          );
        }).toList()..sort(
          (RevenuePeriodRow a, RevenuePeriodRow b) =>
              b.label.compareTo(a.label),
        );

    final RevenueKpi kpi = RevenueKpi(
      orderAmount: stayOrderAmount + storeRevenue,
      stayRevenue: stayRoom,
      addonRevenue: stayAddon,
      storeRevenue: storeRevenue,
      paidAmount: paidStay + paidStore,
      unpaidAmount: stayUnpaid + storeUnpaid,
      refundAmount: refundTotal,
      discountAmount: stayDiscount,
      couponAmount: stayCoupon,
      surchargeAmount: staySurcharge,
      stayOrderCount: confirmedOrders,
      storeOrderCount: storeOrdersCount,
    );

    final List<RoomTypeRow> roomRows =
        rooms.values.map((_RoomAcc r) {
          return RoomTypeRow(
            roomTypeName: r.name,
            orderCount: r.orders,
            nights: r.nights,
            pets: r.pets,
            revenue: r.revenue,
          );
        }).toList()..sort(
          (RoomTypeRow a, RoomTypeRow b) => b.revenue.compareTo(a.revenue),
        );

    final List<AddonRow> addonRows =
        addonMap.values.map((_AddonAcc a) {
            return AddonRow(
              name: a.name,
              type: a.type,
              typeLabel: addonTypeLabel(a.type),
              purchaseCount: a.purchases,
              quantity: a.qty,
              revenue: a.revenue,
            );
          }).toList()
          ..sort((AddonRow a, AddonRow b) => b.revenue.compareTo(a.revenue));

    final MemberBundle memberBundle = _membersFrom(
      members: members,
      bookings: lifetimeBookings,
      rangeStart: start,
      rangeEnd: end,
    );

    final OverviewKpi overview = OverviewKpi(
      orders: newOrders,
      orderAmount: combinedAmount,
      paidAmount: paidStay + paidStore,
      nights: stayNights,
      pets: stayPets,
      averageOrderAmount: combinedAvg,
      cancelRate: cancelRate,
      newMembers: memberBundle.kpi.newInRange,
    );

    final List<MonthTrendRow> trend = <MonthTrendRow>[];
    if (includeTrend) {
      for (int i = 5; i >= 0; i--) {
        final DateTime m = DateTime(end.year, end.month - i, 1);
        final String key = _monthKey(m);
        final _RevAcc acc = monthRev[key] ?? _RevAcc();
        trend.add(
          MonthTrendRow(
            month: key,
            orderCount: acc.orders,
            revenue: acc.stay + acc.addon + acc.store,
          ),
        );
      }
    }

    return ShopReportBundle(
      range: range,
      daily: daily,
      dailySummary: dailySummary,
      revenueByDay: revenueDays,
      revenueByMonth: revenueMonths,
      revenueKpi: kpi,
      roomTypes: roomRows,
      addons: addonRows,
      members: memberBundle.rows,
      memberKpi: memberBundle.kpi,
      overview: overview,
      topRooms: roomRows
          .take(5)
          .map(
            (RoomTypeRow r) => NamedMoneyRow(
              name: r.roomTypeName,
              count: r.orderCount,
              revenue: r.revenue,
            ),
          )
          .toList(),
      topAddons: addonRows
          .take(5)
          .map(
            (AddonRow a) => NamedMoneyRow(
              name: a.name,
              count: a.purchaseCount,
              revenue: a.revenue,
            ),
          )
          .toList(),
      monthTrend: trend,
    );
  }

  MemberBundle _membersFrom({
    required List<Map<String, dynamic>> members,
    required List<Map<String, dynamic>> bookings,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final Map<String, _MemAcc> acc = <String, _MemAcc>{};
    for (final Map<String, dynamic> m in members) {
      if (_str(m['status']) == 'archived') {
        continue;
      }
      final String uid = _str(m['userId']).isNotEmpty
          ? _str(m['userId'])
          : _str(m['id']);
      if (uid.isEmpty) {
        continue;
      }
      acc[uid] = _MemAcc(
        userId: uid,
        name: _str(m['name']).isEmpty ? '未填姓名' : _str(m['name']),
        phone: _str(m['phone']),
        createdAt: _dateOf(m['createdAt']),
        isVip: (m['tags'] is List) && (m['tags'] as List).contains('vip'),
        isBlacklisted:
            m['blacklisted'] == true ||
            m['isBlocked'] == true ||
            ((m['tags'] is List) && (m['tags'] as List).contains('blacklist')),
      );
    }

    final DateTime now = DateTime.now();
    final DateTime d30 = now.subtract(const Duration(days: 30));
    final DateTime d90 = now.subtract(const Duration(days: 90));

    for (final Map<String, dynamic> booking in bookings) {
      final String uid = _str(booking['userId']);
      if (uid.isEmpty || !acc.containsKey(uid)) {
        continue;
      }
      final _MemAcc row = acc[uid]!;
      final DateTime? created = _dateOf(booking['createdAt']);
      if (created != null) {
        row.firstOrderAt = row.firstOrderAt == null
            ? created
            : (created.isBefore(row.firstOrderAt!)
                  ? created
                  : row.firstOrderAt);
        row.lastOrderAt = row.lastOrderAt == null
            ? created
            : (created.isAfter(row.lastOrderAt!) ? created : row.lastOrderAt);
      }
      final String status = _str(booking['status']);
      if (_bookingRevenueStatuses.contains(status)) {
        row.completed++;
        final int amount = _bookingMoney(booking).orderAmount;
        row.spend += amount;
        if (created != null && !created.isBefore(d30)) {
          row.spentLast30 = true;
        }
        if (created != null && !created.isBefore(d90)) {
          row.spentLast90 = true;
        }
        if (created != null && _inRange(created, rangeStart, rangeEnd)) {
          row.periodOrders++;
        }
      }
    }

    int newInRange = 0;
    int spending = 0;
    int returning = 0;
    int vip = 0;
    int blacklisted = 0;
    final List<MemberRow> rows = acc.values.map((_MemAcc m) {
      if (m.createdAt != null && _inRange(m.createdAt!, rangeStart, rangeEnd)) {
        newInRange++;
      }
      if (m.periodOrders > 0) {
        spending++;
      }
      final bool createdBefore =
          m.createdAt == null || m.createdAt!.isBefore(rangeStart);
      if (createdBefore && m.periodOrders > 0) {
        returning++;
      } else if (!createdBefore && m.periodOrders >= 2) {
        returning++;
      }
      if (m.isVip) {
        vip++;
      }
      if (m.isBlacklisted) {
        blacklisted++;
      }
      return MemberRow(
        userId: m.userId,
        name: m.name,
        phone: m.phone,
        firstOrderAt: m.firstOrderAt,
        lastOrderAt: m.lastOrderAt,
        completedOrders: m.completed,
        spend: m.spend,
        spentLast30: m.spentLast30,
        spentLast90: m.spentLast90,
        isVip: m.isVip,
        isBlacklisted: m.isBlacklisted,
      );
    }).toList()..sort((MemberRow a, MemberRow b) => b.spend.compareTo(a.spend));

    return MemberBundle(
      rows: rows,
      kpi: MemberKpi(
        total: rows.length,
        newInRange: newInRange,
        spending: spending,
        returning: returning,
        vip: vip,
        blacklisted: blacklisted,
      ),
    );
  }

  static String addonTypeLabel(String type) {
    switch (type) {
      case 'time':
        return '時間加購';
      case 'value':
        return '加值服務';
      case 'custom':
        return '客製服務';
      case 'daily_timed':
        return '每日分時段服務';
      default:
        return '其他';
    }
  }

  static bool isBookingRevenueStatus(String status) {
    return _bookingRevenueStatuses.contains(status);
  }

  static bool isStoreRevenueStatus(String status) {
    return _storeRevenueStatuses.contains(status);
  }

  static BookingMoneyBreakdown bookingMoneyForTest(Map<String, dynamic> data) {
    final _Money m = _bookingMoney(data);
    return BookingMoneyBreakdown(
      orderAmount: m.orderAmount,
      room: m.room,
      addon: m.addon,
      discount: m.discount,
      coupon: m.coupon,
      surcharge: m.surcharge,
    );
  }

  static String roomTypeNameForTest(Map<String, dynamic> data) {
    return _roomTypeName(data);
  }

  static _Money _bookingMoney(Map<String, dynamic> data) {
    final int addon = _addonTotal(data);
    final int surcharge = _int(data['specialDateSurchargeAmount']);
    final int discount = _int(data['discountAmount']);
    final int coupon = _int(data['couponDiscountAmount']);
    final int extra = _int(data['extraFee']);
    final int order =
        _int(data['finalAmount'] ?? data['totalPrice'] ?? data['totalAmount']) +
        (data['finalAmount'] == null ? extra : 0);
    int room = _int(data['roomSubtotal'] ?? data['basePrice']);
    if (room <= 0) {
      room = (order - addon - extra - surcharge + discount + coupon).clamp(
        0,
        order,
      );
    }
    return _Money(
      orderAmount: order < 0 ? 0 : order,
      room: room,
      addon: addon,
      discount: discount,
      coupon: coupon,
      surcharge: surcharge,
    );
  }

  static int _addonTotal(Map<String, dynamic> data) {
    final Object? addons = data['addons'];
    if (addons is! List) {
      return _int(data['addonTotal'] ?? data['addonsTotal']);
    }
    int total = 0;
    for (final Object? raw in addons) {
      if (raw is! Map) {
        continue;
      }
      total += _int(raw['total'] ?? raw['price']);
    }
    return total;
  }

  static void _collectAddons(
    Map<String, _AddonAcc> map,
    Map<String, dynamic> booking,
  ) {
    final Object? addons = booking['addons'];
    if (addons is! List) {
      return;
    }
    for (final Object? raw in addons) {
      if (raw is! Map) {
        continue;
      }
      final String name = (raw['name'] ?? '未命名加購').toString();
      final String type = (raw['type'] ?? 'other').toString();
      final int qty = _int(raw['count'] ?? 1).clamp(1, 999999);
      final int revenue = _int(raw['total'] ?? raw['price']);
      final String key = '$type|$name';
      final _AddonAcc acc = map.putIfAbsent(
        key,
        () => _AddonAcc(name: name, type: type),
      );
      acc.purchases++;
      acc.qty += qty;
      acc.revenue += revenue;
    }
  }

  static String _roomTypeName(Map<String, dynamic> data) {
    final String name = _str(
      data['roomTypeName'] ?? data['selectedRoomTypeName'] ?? data['roomType'],
    );
    return name.isEmpty ? '未指定房型' : name;
  }

  static int _petCount(Map<String, dynamic> data) {
    final Object? ids = data['petIds'];
    if (ids is List && ids.isNotEmpty) {
      return ids.length;
    }
    final Object? pets = data['pets'];
    if (pets is List && pets.isNotEmpty) {
      return pets.length;
    }
    return 1 + _int(data['extraPetCount']);
  }

  static void _mergeDocs(
    Map<String, Map<String, dynamic>> into,
    QuerySnapshot<Map<String, dynamic>> snap,
  ) {
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in snap.docs) {
      into[doc.id] = _docMap(doc);
    }
  }

  static Map<String, dynamic> _docMap(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return <String, dynamic>{'id': doc.id, ...doc.data()};
  }

  static bool _inRange(DateTime value, DateTime start, DateTime end) {
    return !value.isBefore(start) && !value.isAfter(end);
  }

  static DateTime? _dateOf(dynamic raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    return null;
  }

  static String _dateKey(DateTime d) {
    final String m = d.month.toString().padLeft(2, '0');
    final String day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  static String _monthKey(DateTime d) {
    return '${d.year}/${d.month.toString().padLeft(2, '0')}';
  }

  static String _str(dynamic raw) => (raw ?? '').toString().trim();

  static int _int(dynamic raw) {
    if (raw is int) {
      return raw;
    }
    if (raw is num) {
      return raw.round();
    }
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }
}

class _Money {
  const _Money({
    required this.orderAmount,
    required this.room,
    required this.addon,
    required this.discount,
    required this.coupon,
    required this.surcharge,
  });

  final int orderAmount;
  final int room;
  final int addon;
  final int discount;
  final int coupon;
  final int surcharge;
}

class _DayAcc {
  _DayAcc(this.date);

  final DateTime date;
  int newOrders = 0;
  int confirmedOrders = 0;
  int cancelledOrders = 0;
  int checkIns = 0;
  int checkOuts = 0;
  int nights = 0;
  int pets = 0;
  int stayOrderAmount = 0;
  int stayRevenue = 0;
  int addonRevenue = 0;
  int storeRevenue = 0;
  int storeOrders = 0;
  int discountAmount = 0;
  int couponAmount = 0;
  int surchargeAmount = 0;
  int paidStay = 0;
  int paidStore = 0;
  int stayUnpaid = 0;
  int storeUnpaid = 0;
  int refundAmount = 0;
}

class _RoomAcc {
  _RoomAcc(this.name);

  final String name;
  int orders = 0;
  int nights = 0;
  int pets = 0;
  int revenue = 0;
}

class _AddonAcc {
  _AddonAcc({required this.name, required this.type});

  final String name;
  final String type;
  int purchases = 0;
  int qty = 0;
  int revenue = 0;
}

class _RevAcc {
  int orders = 0;
  int stay = 0;
  int addon = 0;
  int store = 0;
  int discount = 0;
  int coupon = 0;
  int surcharge = 0;
  int orderAmount = 0;
  int paid = 0;
  int unpaid = 0;
  int refund = 0;
}

class _MemAcc {
  _MemAcc({
    required this.userId,
    required this.name,
    required this.phone,
    this.createdAt,
    this.isVip = false,
    this.isBlacklisted = false,
  });

  final String userId;
  String name;
  String phone;
  DateTime? createdAt;
  DateTime? firstOrderAt;
  DateTime? lastOrderAt;
  int completed = 0;
  int spend = 0;
  int periodOrders = 0;
  bool spentLast30 = false;
  bool spentLast90 = false;
  bool isVip;
  bool isBlacklisted;
}

class MemberBundle {
  const MemberBundle({required this.rows, required this.kpi});

  final List<MemberRow> rows;
  final MemberKpi kpi;
}
