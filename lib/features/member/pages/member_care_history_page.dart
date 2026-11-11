import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/models/booking_kind.dart';
import '../../../core/models/daily_care_entitlement.dart';
import '../../../core/models/daily_care_record_model.dart';
import '../../../core/models/daily_care_stay_info.dart';
import '../../../core/models/home_theme_model.dart';
import '../../../core/services/daily_care_record_service.dart';
import '../../../core/models/daily_care_photo_model.dart';
import '../../../core/models/daily_care_date_helper.dart';
import '../../booking/pages/customer_daily_care_page.dart';

typedef _Booking = QueryDocumentSnapshot<Map<String, dynamic>>;
typedef _HistoryEntry = ({_Booking booking, DailyCareRecordModel latest});
typedef _History = ({List<_HistoryEntry> entries, bool hasError});

class MemberCareHistoryEntry extends StatefulWidget {
  const MemberCareHistoryEntry({
    super.key,
    required this.userId,
    required this.theme,
  });

  final String userId;
  final HomeThemeModel theme;

  @override
  State<MemberCareHistoryEntry> createState() => _MemberCareHistoryEntryState();
}

class _MemberCareHistoryEntryState extends State<MemberCareHistoryEntry> {
  final _history = ValueNotifier<_History>((entries: [], hasError: false));
  final _records = <String, StreamSubscription<List<DailyCareRecordModel>>>{};
  final _latest = <String, DailyCareRecordModel>{};
  final _recordErrors = <String>{};
  Map<String, _Booking> _bookings = {};
  bool _bookingError = false;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _orders;

  @override
  void initState() {
    super.initState();
    _orders = FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: widget.userId)
        .snapshots()
        .listen(
          _updateBookings,
          onError: (Object _) {
            _bookingError = true;
            _publish();
          },
        );
  }

  void _updateBookings(QuerySnapshot<Map<String, dynamic>> snapshot) {
    _bookingError = false;
    _bookings = {
      for (final doc in snapshot.docs)
        if (_eligible(doc.data())) doc.id: doc,
    };
    for (final id in _records.keys.toList()) {
      if (!_bookings.containsKey(id)) {
        unawaited(_records.remove(id)?.cancel());
        _latest.remove(id);
        _recordErrors.remove(id);
      }
    }
    for (final id in _bookings.keys) {
      _records.putIfAbsent(
        id,
        () => DailyCareRecordService.instance
            .streamBookingRecords(bookingId: id)
            .listen(
              (records) {
                _recordErrors.remove(id);
                // The existing service sorts by service date and session index.
                final completed = records.where(
                  (record) => record.countsAsCompleted,
                );
                if (completed.isEmpty) {
                  _latest.remove(id);
                } else {
                  _latest[id] = completed.last;
                }
                _publish();
              },
              onError: (Object _) {
                _recordErrors.add(id);
                _latest.remove(id);
                _publish();
              },
            ),
      );
    }
    _publish();
  }

  bool _eligible(Map<String, dynamic> data) {
    return const {
          'checked_in',
          'checked_out',
          'completed',
        }.contains(data['status']) &&
        (data['shopId'] ?? '').toString().trim().isNotEmpty &&
        !DailyCareEntitlement.explicitlyNoReports(data);
  }

  void _publish() {
    if (!mounted) return;
    final entries = <_HistoryEntry>[
      for (final entry in _latest.entries)
        if (_bookings[entry.key] case final booking?)
          (booking: booking, latest: entry.value),
    ]..sort((a, b) => b.latest.recordDate.compareTo(a.latest.recordDate));
    _history.value = (
      entries: entries,
      hasError: _bookingError || _recordErrors.isNotEmpty,
    );
  }

  @override
  void dispose() {
    unawaited(_orders?.cancel());
    for (final sub in _records.values) {
      unawaited(sub.cancel());
    }
    _history.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return ValueListenableBuilder<_History>(
      valueListenable: _history,
      builder: (context, history, _) {
        if (history.entries.isEmpty) return const SizedBox.shrink();
        return Card(
          color: theme.cardColor,
          margin: const EdgeInsets.only(top: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: theme.primaryColor.withValues(alpha: .35)),
          ),
          child: ListTile(
            leading: Icon(Icons.assignment_outlined, color: theme.primaryColor),
            title: Text(
              '我的照護回報',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: theme.textColor,
              ),
            ),
            subtitle: Text(
              '查看各店家的照護紀錄',
              style: TextStyle(color: theme.textColor),
            ),
            trailing: Icon(Icons.chevron_right, color: theme.primaryColor),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => _HistoryPage(
                  history: _history,
                  userId: widget.userId,
                  theme: theme,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _HistoryPage extends StatefulWidget {
  const _HistoryPage({
    required this.history,
    required this.userId,
    required this.theme,
  });

  final ValueNotifier<_History> history;
  final String userId;
  final HomeThemeModel theme;

  @override
  State<_HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<_HistoryPage> {
  late final _auth = FirebaseAuth.instance.authStateChanges();
  String? _shop;

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    return Scaffold(
      backgroundColor: theme.backgroundColor,
      appBar: AppBar(
        title: const Text('我的照護回報'),
        backgroundColor: theme.backgroundColor,
        foregroundColor: theme.textColor,
      ),
      body: StreamBuilder<User?>(
        stream: _auth,
        builder: (context, auth) {
          if (auth.data?.uid != widget.userId) return const SizedBox.shrink();
          return ValueListenableBuilder<_History>(
            valueListenable: widget.history,
            builder: (context, history, _) {
              final shops = <String, List<_HistoryEntry>>{};
              for (final entry in history.entries) {
                final id = (entry.booking.data()['shopId'] as Object)
                    .toString()
                    .trim();
                shops.putIfAbsent(id, () => []).add(entry);
              }
              final selected = shops.containsKey(_shop) ? _shop : null;
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (history.hasError)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 12),
                      child: Text('部分照護紀錄暫時無法讀取'),
                    ),
                  if (shops.isEmpty && !history.hasError)
                    const Text('目前沒有可查看的照護回報'),
                  if (shops.isNotEmpty)
                    DropdownButton<String>(
                      isExpanded: true,
                      value: selected ?? '',
                      onChanged: (value) => setState(() => _shop = value),
                      items: [
                        const DropdownMenuItem(value: '', child: Text('全部店家')),
                        for (final shop in shops.entries)
                          DropdownMenuItem(
                            value: shop.key,
                            child: Text(
                              _shopName(
                                shop.key,
                                shop.value.first.booking.data(),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  for (final shop in shops.entries)
                    if (selected == null || selected == shop.key) ...[
                      Padding(
                        padding: const EdgeInsets.only(top: 16, bottom: 6),
                        child: Text(
                          _shopName(shop.key, shop.value.first.booking.data()),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: theme.textColor,
                          ),
                        ),
                      ),
                      for (final entry in shop.value)
                        _bookingTile(entry, shop.key),
                    ],
                ],
              );
            },
          );
        },
      ),
    );
  }

  String _shopName(String shopId, Map<String, dynamic> booking) {
    final name = (booking['shopName'] ?? '').toString().trim();
    return name.isEmpty ? '店家 $shopId' : name;
  }

  Widget _bookingTile(_HistoryEntry entry, String shopId) {
    final data = entry.booking.data();
    final stay = DailyCareStayInfo.fromBookingMap(data);
    final daycare = BookingKind.isDaycare(data);
    final active = data['status'] == 'checked_in';
    final status = daycare
        ? (active ? '安親中' : '安親已結束')
        : (active ? '入住中' : '已退房');
    final theme = widget.theme;
    return Card(
      color: theme.cardColor,
      child: ListTile(
        leading: Icon(Icons.pets_outlined, color: theme.primaryColor),
        title: Text(
          stay.petNamesText,
          style: TextStyle(color: theme.textColor),
        ),
        subtitle: Text(
          [
            status,
            if (stay.stayDateText.isNotEmpty) stay.stayDateText,
          ].join(' · '),
        ),
        trailing: Text('查看回報 ›', style: TextStyle(color: theme.primaryColor)),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CustomerDailyCarePage(
              shopId: shopId,
              bookingId: entry.booking.id,
              roomName: stay.roomName,
              initialDate: DailyCareDateHelper.parseDateKey(
                DailyCarePhotoMatch.canonicalDateKey(entry.latest.recordDate),
              ),
              initialSessionIndex: entry.latest.sessionIndex,
              journalTitle: daycare ? '本次安親回報' : '每日照護紀錄',
            ),
          ),
        ),
      ),
    );
  }
}
