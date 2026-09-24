// 檔案名稱：lib/features/room/pages/room_dashboard_page.dart
// 功能說明：房務管理工作台（手機清單／桌機雙欄），即時監聽與操作回饋。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/models/shop_task_item.dart';
import 'package:petnest_saas/core/navigation/admin_booking_route.dart';
import 'package:petnest_saas/core/presentation/room_status_presentation.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/services/shop_room_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/services/shop_task_center_service.dart';
import 'package:petnest_saas/core/utils/natural_sort.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/admin/widgets/admin_daily_care_report_shortcut.dart';
import 'package:petnest_saas/features/auth/pages/room_calendar_page.dart';
import 'package:petnest_saas/features/room/pages/housekeeping_setting_page.dart';
import 'package:petnest_saas/features/room/widgets/housekeeping_daily_care_pane.dart';
import 'package:petnest_saas/features/room/widgets/room_status_chip.dart';

enum _RoomQuickFilter { all, needs, checkedIn, vacant }

enum _DeskView { rooms, reports, split }

class _DashRoom {
  const _DashRoom({
    required this.room,
    required this.label,
    required this.presentation,
    this.booking,
    this.bookingId = '',
    this.care,
  });

  final Map<String, dynamic> room;
  final String label;
  final RoomStatusPresentation presentation;
  final Map<String, dynamic>? booking;
  final String bookingId;
  final ShopRoomCareProgress? care;

  String get id => (room['id'] ?? '').toString();
  String get name => (room['name'] ?? '').toString();
  String get typeName {
    final String name = (room['roomTypeName'] ?? '').toString().trim();
    return name.isEmpty ? '未分類' : name;
  }

  bool get needsAction {
    if (label == DaycareOccupancyService.cleaningLabel ||
        label == DaycareOccupancyService.maintenanceLabel ||
        label == DaycareOccupancyService.closedLabel) {
      return true;
    }
    if (label == '入住中' && care != null && !care!.isComplete) {
      return true;
    }
    return false;
  }
}

class RoomDashboardPage extends StatefulWidget {
  const RoomDashboardPage({super.key, required this.shopId});

  final String shopId;

  @override
  State<RoomDashboardPage> createState() => _RoomDashboardPageState();
}

class _RoomDashboardPageState extends State<RoomDashboardPage> {
  static const double _desktopMin = 700;
  static const double _splitMin = 1180;
  static const double _contentMax = 1520;

  DateTime selectedDate = DateTime.now();
  bool _loadingPermission = true;
  bool _hasPermission = false;
  String _selectedRoomTypeFilter = '__all__';
  _RoomQuickFilter _quickFilter = _RoomQuickFilter.all;
  final Set<String> _collapsedTypes = <String>{};
  final Set<String> _busyKeys = <String>{};
  _DeskView _deskView = _DeskView.rooms;
  double _splitRatio = 0.5;
  String _focusBookingId = '';
  int _streamRetry = 0;

  DateTime get weekStart {
    final DateTime d = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
    );
    return d.subtract(Duration(days: d.weekday - 1));
  }

  List<DateTime> get weekDays {
    return List<DateTime>.generate(
      7,
      (int index) => weekStart.add(Duration(days: index)),
    );
  }

  String get dateStr => DateFormat('yyyy-MM-dd').format(selectedDate);

  String _actionKey(String roomId) => '$roomId|$dateStr';

  String get _deskViewLabel {
    return switch (_deskView) {
      _DeskView.rooms => '房務全頁',
      _DeskView.reports => '回報全頁',
      _DeskView.split => '分割工作台',
    };
  }

  Future<void> _checkPermission() async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _loadingPermission = false;
        _hasPermission = false;
      });
      return;
    }
    final Map<String, dynamic>? memberData = await ShopService.instance
        .getUserMemberInShop(shopId: widget.shopId, uid: user.uid);
    final bool hasPermission = ShopService.instance.hasPermission(
      memberData,
      ShopPermissionKeys.manageRoomDashboard,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _loadingPermission = false;
      _hasPermission = hasPermission;
    });
  }

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  @override
  Widget build(BuildContext context) {
    if (_loadingPermission) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_hasPermission) {
      return Scaffold(
        appBar: AppBar(title: const Text('權限限制')),
        body: const Center(child: Text('你沒有房務管理權限')),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7F9),
      appBar: AppBar(
        title: const Text('房務管理'),
        actions: <Widget>[
          if (MediaQuery.sizeOf(context).width >= _desktopMin)
            PopupMenuButton<_DeskView>(
              tooltip: '檢視模式',
              initialValue: _deskView,
              onSelected: (_DeskView value) {
                setState(() {
                  _deskView = value;
                });
              },
              itemBuilder: (BuildContext context) {
                return const <PopupMenuEntry<_DeskView>>[
                  PopupMenuItem<_DeskView>(
                    value: _DeskView.rooms,
                    child: Text('房務全頁'),
                  ),
                  PopupMenuItem<_DeskView>(
                    value: _DeskView.reports,
                    child: Text('回報全頁'),
                  ),
                  PopupMenuItem<_DeskView>(
                    value: _DeskView.split,
                    child: Text('分割工作台'),
                  ),
                ];
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: <Widget>[
                    Text(_deskViewLabel),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),
          ShopTaskCenterButton(shopId: widget.shopId),
          IconButton(
            tooltip: '房務設定',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      HousekeepingSettingPage(shopId: widget.shopId),
                ),
              );
            },
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool desktop = constraints.maxWidth >= _desktopMin;
          return StreamBuilder<List<Map<String, dynamic>>>(
            key: ValueKey<int>(_streamRetry),
            stream: ShopService.instance.streamRooms(widget.shopId),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<Map<String, dynamic>>> roomSnap,
                ) {
                  if (roomSnap.hasError) {
                    return _errorPane('房間資料讀取失敗', roomSnap.error);
                  }
                  if (!roomSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final List<Map<String, dynamic>> rooms =
                      List<Map<String, dynamic>>.from(roomSnap.data!)
                        ..sort(_compareRooms);
                  return StreamBuilder<ShopTaskCenterSnapshot>(
                    stream: ShopTaskCenterService.instance.streamSnapshot(
                      shopId: widget.shopId,
                      canViewBookings: false,
                      canFillDailyCare: true,
                      careDate: DateTime(
                        selectedDate.year,
                        selectedDate.month,
                        selectedDate.day,
                      ),
                    ),
                    builder:
                        (
                          BuildContext context,
                          AsyncSnapshot<ShopTaskCenterSnapshot> careSnap,
                        ) {
                          final Map<String, ShopRoomCareProgress> careProgress =
                              careSnap.data?.roomCareProgress ??
                              const <String, ShopRoomCareProgress>{};
                          return StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('bookings')
                                .where('shopId', isEqualTo: widget.shopId)
                                .where(
                                  'status',
                                  whereIn: <String>[
                                    'pending',
                                    'confirmed',
                                    'checked_in',
                                    'completed',
                                  ],
                                )
                                .snapshots(),
                            builder:
                                (
                                  BuildContext context,
                                  AsyncSnapshot<QuerySnapshot> bookingSnap,
                                ) {
                                  if (bookingSnap.hasError) {
                                    return _errorPane(
                                      '訂單資料讀取失敗',
                                      bookingSnap.error,
                                    );
                                  }
                                  if (!bookingSnap.hasData) {
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  }
                                  return StreamBuilder<QuerySnapshot>(
                                    stream: ShopService.instance
                                        .roomCalendarRef(widget.shopId)
                                        .snapshots(),
                                    builder:
                                        (
                                          BuildContext context,
                                          AsyncSnapshot<QuerySnapshot>
                                          calendarSnap,
                                        ) {
                                          if (calendarSnap.hasError) {
                                            return _errorPane(
                                              '房況日曆讀取失敗',
                                              calendarSnap.error,
                                            );
                                          }
                                          if (!calendarSnap.hasData) {
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          }
                                          return _workspace(
                                            desktop: desktop,
                                            width: constraints.maxWidth,
                                            rooms: rooms,
                                            bookings: bookingSnap.data!.docs,
                                            calendarDocs:
                                                calendarSnap.data!.docs,
                                            careProgress: careProgress,
                                          );
                                        },
                                  );
                                },
                          );
                        },
                  );
                },
          );
        },
      ),
    );
  }

  Widget _workspace({
    required bool desktop,
    required double width,
    required List<Map<String, dynamic>> rooms,
    required List<QueryDocumentSnapshot> bookings,
    required List<QueryDocumentSnapshot> calendarDocs,
    required Map<String, ShopRoomCareProgress> careProgress,
  }) {
    final Map<String, String> calendarStatus = <String, String>{};
    for (final QueryDocumentSnapshot doc in calendarDocs) {
      final Object? raw = doc.data();
      if (raw is! Map) {
        continue;
      }
      final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
      final String roomId = (data['roomId'] ?? '').toString();
      final String date = (data['date'] ?? '').toString();
      if (roomId.isEmpty || date.isEmpty) {
        continue;
      }
      calendarStatus['$roomId|$date'] = (data['status'] ?? '').toString();
    }
    final List<_DashRoom> allRows = rooms
        .map(
          (Map<String, dynamic> room) => _buildRow(
            room: room,
            bookings: bookings,
            calendarStatus: calendarStatus,
            careProgress: careProgress,
          ),
        )
        .toList();
    final List<String> typeNames =
        rooms
            .map((Map<String, dynamic> room) {
              final String name = (room['roomTypeName'] ?? '')
                  .toString()
                  .trim();
              return name.isEmpty ? '未分類' : name;
            })
            .toSet()
            .toList()
          ..sort(naturalCompare);
    final String typeFilter =
        _selectedRoomTypeFilter == '__all__' ||
            typeNames.contains(_selectedRoomTypeFilter)
        ? _selectedRoomTypeFilter
        : '__all__';
    final List<_DashRoom> filtered = allRows.where((_DashRoom row) {
      if (typeFilter != '__all__' && row.typeName != typeFilter) {
        return false;
      }
      switch (_quickFilter) {
        case _RoomQuickFilter.all:
          return true;
        case _RoomQuickFilter.needs:
          return row.needsAction;
        case _RoomQuickFilter.checkedIn:
          return row.label == '入住中';
        case _RoomQuickFilter.vacant:
          return row.label == DaycareOccupancyService.vacantLabel;
      }
    }).toList();
    final List<QueryDocumentSnapshot> unassigned = bookings.where((
      QueryDocumentSnapshot doc,
    ) {
      final Object? raw = doc.data();
      if (raw is! Map) {
        return false;
      }
      final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
      return data['assignStatus'] == 'unassigned' &&
          data['status'] != 'cancelled' &&
          data['status'] != 'completed';
    }).toList();
    final int emptyCount = _count(allRows, DaycareOccupancyService.vacantLabel);
    final int disabledCount = _count(
      allRows,
      DaycareOccupancyService.disabledLabel,
    );
    final int usingCount = allRows
        .where(
          (_DashRoom row) => RoomStatusPresentation.isInUseLabel(row.label),
        )
        .length;
    final int cleaningCount = _count(
      allRows,
      DaycareOccupancyService.cleaningLabel,
    );
    final int closedCount = _count(
      allRows,
      DaycareOccupancyService.closedLabel,
    );
    final int blockedCount = _count(
      allRows,
      DaycareOccupancyService.maintenanceLabel,
    );
    final List<_DashRoom> cleaningRows = allRows
        .where(
          (_DashRoom row) => row.label == DaycareOccupancyService.cleaningLabel,
        )
        .toList();
    final List<_DashRoom> careRows = allRows
        .where(
          (_DashRoom row) =>
              row.label == '入住中' && row.care != null && !row.care!.isComplete,
        )
        .toList();

    final Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _dateBar(desktop: desktop),
        _filters(rooms: rooms, typeNames: typeNames, typeFilter: typeFilter),
        _summaries(
          desktop: desktop,
          emptyCount: emptyCount,
          disabledCount: disabledCount,
          usingCount: usingCount,
          cleaningCount: cleaningCount,
          closedCount: closedCount,
          blockedCount: blockedCount,
        ),
      ],
    );

    if (!desktop) {
      return Column(
        children: <Widget>[
          header,
          Expanded(
            child: rooms.isEmpty
                ? const Center(child: Text('尚無房間'))
                : _groupedList(
                    filtered: filtered,
                    allRows: allRows,
                    bookings: bookings,
                    calendarStatus: calendarStatus,
                    dense: true,
                    splitSelect: false,
                  ),
          ),
        ],
      );
    }

    final bool splitOk = width >= _splitMin;
    final _DeskView view = _deskView == _DeskView.split && !splitOk
        ? _DeskView.rooms
        : _deskView;

    if (view == _DeskView.reports) {
      return HousekeepingDailyCarePane(
        shopId: widget.shopId,
        focusBookingId: _focusBookingId,
      );
    }

    final Widget roomsDesktop = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _contentMax),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: <Widget>[
              header,
              const SizedBox(height: 8),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Expanded(
                      flex: 7,
                      child: rooms.isEmpty
                          ? const Center(child: Text('尚無房間'))
                          : _groupedList(
                              filtered: filtered,
                              allRows: allRows,
                              bookings: bookings,
                              calendarStatus: calendarStatus,
                              dense: false,
                              splitSelect: view == _DeskView.split,
                            ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      flex: 3,
                      child: _todoPane(
                        unassigned: unassigned,
                        cleaningRows: cleaningRows,
                        careRows: careRows,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (view != _DeskView.split) {
      return roomsDesktop;
    }

    final int leftFlex = (_splitRatio * 100).round().clamp(35, 65);
    final int rightFlex = 100 - leftFlex;
    return Row(
      children: <Widget>[
        Expanded(flex: leftFlex, child: roomsDesktop),
        MouseRegion(
          cursor: SystemMouseCursors.resizeColumn,
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onHorizontalDragUpdate: (DragUpdateDetails details) {
              setState(() {
                _splitRatio = (_splitRatio + details.delta.dx / width).clamp(
                  0.35,
                  0.65,
                );
              });
            },
            child: const VerticalDivider(width: 10, thickness: 1),
          ),
        ),
        Expanded(
          flex: rightFlex,
          child: Material(
            color: const Color(0xFFF7F8FA),
            child: HousekeepingDailyCarePane(
              shopId: widget.shopId,
              focusBookingId: _focusBookingId,
            ),
          ),
        ),
      ],
    );
  }

  Widget _dateBar({required bool desktop}) {
    final bool isToday = DateUtils.isSameDay(selectedDate, DateTime.now());
    return Padding(
      padding: EdgeInsets.fromLTRB(desktop ? 0 : 8, 6, desktop ? 0 : 8, 4),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: '上一週',
            icon: const Icon(Icons.chevron_left),
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.subtract(const Duration(days: 7));
              });
            },
          ),
          Expanded(
            child: Row(
              children: List<Widget>.generate(7, (int i) {
                final DateTime day = weekDays[i];
                final bool selected = DateUtils.isSameDay(day, selectedDate);
                final bool today = DateUtils.isSameDay(day, DateTime.now());
                const List<String> weekNames = <String>[
                  '一',
                  '二',
                  '三',
                  '四',
                  '五',
                  '六',
                  '日',
                ];
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        selectedDate = day;
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      decoration: BoxDecoration(
                        color: selected
                            ? RoomStatusPresentation.checkedInColor.withValues(
                                alpha: 0.10,
                              )
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? RoomStatusPresentation.checkedInColor
                              : today
                              ? RoomStatusPresentation.checkedInColor
                                    .withValues(alpha: 0.45)
                              : Colors.transparent,
                          width: selected || today ? 1.4 : 1,
                        ),
                      ),
                      child: Column(
                        children: <Widget>[
                          Text(
                            '${day.month}/${day.day}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: selected
                                  ? RoomStatusPresentation.checkedInColor
                                  : null,
                            ),
                          ),
                          Text(
                            weekNames[i],
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: today
                                  ? RoomStatusPresentation.checkedInColor
                                  : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          IconButton(
            tooltip: '下一週',
            icon: const Icon(Icons.chevron_right),
            onPressed: () {
              setState(() {
                selectedDate = selectedDate.add(const Duration(days: 7));
              });
            },
          ),
          TextButton(
            onPressed: isToday
                ? null
                : () {
                    setState(() {
                      selectedDate = DateTime(
                        DateTime.now().year,
                        DateTime.now().month,
                        DateTime.now().day,
                      );
                    });
                  },
            child: const Text('今天'),
          ),
        ],
      ),
    );
  }

  Widget _filters({
    required List<Map<String, dynamic>> rooms,
    required List<String> typeNames,
    required String typeFilter,
  }) {
    Widget chip({
      required String label,
      required bool selected,
      required VoidCallback onTap,
    }) {
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(label),
          selected: selected,
          onSelected: (_) => onTap(),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                chip(
                  label: '全部',
                  selected: _quickFilter == _RoomQuickFilter.all,
                  onTap: () =>
                      setState(() => _quickFilter = _RoomQuickFilter.all),
                ),
                chip(
                  label: '需處理',
                  selected: _quickFilter == _RoomQuickFilter.needs,
                  onTap: () =>
                      setState(() => _quickFilter = _RoomQuickFilter.needs),
                ),
                chip(
                  label: '入住中',
                  selected: _quickFilter == _RoomQuickFilter.checkedIn,
                  onTap: () =>
                      setState(() => _quickFilter = _RoomQuickFilter.checkedIn),
                ),
                chip(
                  label: '空房',
                  selected: _quickFilter == _RoomQuickFilter.vacant,
                  onTap: () =>
                      setState(() => _quickFilter = _RoomQuickFilter.vacant),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: <Widget>[
                chip(
                  label: '全部 (${rooms.length})',
                  selected: typeFilter == '__all__',
                  onTap: () =>
                      setState(() => _selectedRoomTypeFilter = '__all__'),
                ),
                ...typeNames.map((String name) {
                  final int count = rooms.where((Map<String, dynamic> room) {
                    final String current = (room['roomTypeName'] ?? '')
                        .toString()
                        .trim();
                    return (current.isEmpty ? '未分類' : current) == name;
                  }).length;
                  return chip(
                    label: '$name ($count)',
                    selected: typeFilter == name,
                    onTap: () => setState(() => _selectedRoomTypeFilter = name),
                  );
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaries({
    required bool desktop,
    required int emptyCount,
    required int disabledCount,
    required int usingCount,
    required int cleaningCount,
    required int closedCount,
    required int blockedCount,
  }) {
    final List<Widget> cards = <Widget>[
      _summaryCard(
        title: '空房',
        count: emptyCount,
        presentation: RoomStatusPresentation.available(),
        onTap: () => setState(() => _quickFilter = _RoomQuickFilter.vacant),
      ),
      _summaryCard(
        title: '使用中',
        count: usingCount,
        presentation: RoomStatusPresentation.stayCheckedIn(),
        onTap: () => setState(() => _quickFilter = _RoomQuickFilter.checkedIn),
      ),
      _summaryCard(
        title: '清潔中',
        count: cleaningCount,
        presentation: RoomStatusPresentation.cleaning(),
        onTap: () => setState(() => _quickFilter = _RoomQuickFilter.needs),
      ),
      _summaryCard(
        title: '今日關閉',
        count: closedCount,
        presentation: RoomStatusPresentation.closed(),
        onTap: () => setState(() => _quickFilter = _RoomQuickFilter.needs),
      ),
      _summaryCard(
        title: '維修中',
        count: blockedCount,
        presentation: RoomStatusPresentation.maintenance(),
        onTap: () => setState(() => _quickFilter = _RoomQuickFilter.needs),
      ),
      if (disabledCount > 0)
        _summaryCard(
          title: '未啟用',
          count: disabledCount,
          presentation: RoomStatusPresentation.disabled(),
          onTap: () => setState(() => _quickFilter = _RoomQuickFilter.all),
        ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: desktop
          ? Wrap(spacing: 8, runSpacing: 8, children: cards)
          : SizedBox(
              height: 78,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: cards.length,
                separatorBuilder: (BuildContext context, int index) =>
                    const SizedBox(width: 8),
                itemBuilder: (_, int i) =>
                    SizedBox(width: 108, child: cards[i]),
              ),
            ),
    );
  }

  Widget _summaryCard({
    required String title,
    required int count,
    required RoomStatusPresentation presentation,
    required VoidCallback onTap,
  }) {
    return Material(
      color: presentation.background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 120,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: presentation.border),
          ),
          child: Column(
            children: <Widget>[
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: presentation.color,
                ),
              ),
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: presentation.color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _groupedList({
    required List<_DashRoom> filtered,
    required List<_DashRoom> allRows,
    required List<QueryDocumentSnapshot> bookings,
    required Map<String, String> calendarStatus,
    required bool dense,
    required bool splitSelect,
  }) {
    if (filtered.isEmpty) {
      return const Center(child: Text('沒有符合篩選的房間'));
    }
    final Map<String, List<_DashRoom>> groups = <String, List<_DashRoom>>{};
    for (final _DashRoom row in filtered) {
      groups.putIfAbsent(row.typeName, () => <_DashRoom>[]).add(row);
    }
    final List<String> keys = groups.keys.toList()..sort(naturalCompare);
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: keys.length,
      itemBuilder: (BuildContext context, int index) {
        final String type = keys[index];
        final List<_DashRoom> rows = groups[type]!;
        final int need = rows.where((_DashRoom row) => row.needsAction).length;
        final bool collapsed = _collapsedTypes.contains(type);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            InkWell(
              onTap: () {
                setState(() {
                  if (collapsed) {
                    _collapsedTypes.remove(type);
                  } else {
                    _collapsedTypes.add(type);
                  }
                });
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                child: Row(
                  children: <Widget>[
                    Icon(
                      collapsed
                          ? Icons.keyboard_arrow_right
                          : Icons.keyboard_arrow_down,
                      size: 20,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '$type　${rows.length} 間${need > 0 ? '　需處理 $need' : ''}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (!collapsed)
              ...rows.map(
                (_DashRoom row) => _roomTile(
                  row: row,
                  bookings: bookings,
                  calendarStatus: calendarStatus,
                  dense: dense,
                  splitSelect: splitSelect,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _roomTile({
    required _DashRoom row,
    required List<QueryDocumentSnapshot> bookings,
    required Map<String, String> calendarStatus,
    required bool dense,
    required bool splitSelect,
  }) {
    final bool busy = _busyKeys.contains(_actionKey(row.id));
    final bool vacant = row.label == DaycareOccupancyService.vacantLabel;
    final List<Color> dots = weekDays.map((DateTime day) {
      final Map<String, dynamic>? dayBooking = _bookingOnDate(
        bookings: bookings,
        roomId: row.id,
        day: day,
      );
      final String dayLabel = DaycareOccupancyService.housekeepingLabel(
        room: Map<String, dynamic>.from(row.room),
        calendarStatus:
            (calendarStatus['${row.id}|${DateFormat('yyyy-MM-dd').format(day)}'] ??
                    '')
                .toString(),
        stayBooking: dayBooking,
      );
      return RoomStatusPresentation.fromHousekeepingLabel(
        dayLabel,
        booking: dayBooking,
      ).color;
    }).toList();
    final Widget actions = _rowActions(row: row, busy: busy);
    final Widget body = Padding(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: vacant ? 8 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 78,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  row.typeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  row.name,
                  style: TextStyle(
                    fontSize: vacant ? 18 : 22,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (row.booking != null) ...<Widget>[
                  Text(
                    (row.booking!['customerName'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    _stayRange(row.booking!),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.blueGrey,
                    ),
                  ),
                ] else
                  Text(
                    row.presentation.label,
                    style: const TextStyle(fontSize: 13, color: Colors.grey),
                  ),
                const SizedBox(height: 6),
                RoomWeekDots(colors: dots),
                if (row.care != null && row.label == '入住中') ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    row.care!.isComplete
                        ? '照護 ${row.care!.filled}/${row.care!.total} ✓'
                        : '照護待填 ${row.care!.pending} 場',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: row.care!.isComplete
                          ? RoomStatusPresentation.availableColor
                          : RoomStatusPresentation.cleaningColor,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              RoomStatusChip(presentation: row.presentation, compact: dense),
              const SizedBox(height: 6),
              actions,
            ],
          ),
        ],
      ),
    );
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: () {
          if (splitSelect && row.label == '入住中' && row.bookingId.isNotEmpty) {
            setState(() {
              _focusBookingId = row.bookingId;
            });
            return;
          }
          _openCalendar(row.room);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: row.needsAction
                  ? row.presentation.border
                  : Colors.grey.shade200,
            ),
          ),
          child: body,
        ),
      ),
    );
  }

  Widget _rowActions({required _DashRoom row, required bool busy}) {
    Widget button({required String label, required VoidCallback? onPressed}) {
      return TextButton(
        onPressed: busy ? null : onPressed,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          padding: const EdgeInsets.symmetric(horizontal: 8),
        ),
        child: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Text(label),
      );
    }

    if (row.label == DaycareOccupancyService.cleaningLabel) {
      return button(
        label: '完成清潔',
        onPressed: () => _runRoomAction(
          roomId: row.id,
          successMessage: '${row.name} 已完成清潔，房間已恢復開放',
          action: () => ShopRoomService.instance.completeCleaning(
            shopId: widget.shopId,
            roomId: row.id,
            date: selectedDate,
          ),
        ),
      );
    }
    if (row.label == DaycareOccupancyService.disabledLabel) {
      return button(
        label: '啟用房間',
        onPressed: () => _runRoomAction(
          roomId: row.id,
          successMessage: '${row.name} 已啟用',
          action: () => ShopService.instance.updateRoomStatus(
            shopId: widget.shopId,
            roomId: row.id,
            enabled: true,
          ),
        ),
      );
    }
    if (row.label == '入住中') {
      return Wrap(
        spacing: 0,
        children: <Widget>[
          button(
            label: '查看訂單',
            onPressed: row.bookingId.isEmpty
                ? null
                : () => AdminBookingRoute.open(
                    context,
                    bookingId: row.bookingId,
                    data: row.booking,
                    canEdit: true,
                  ),
          ),
          if (row.care != null && !row.care!.isComplete)
            button(
              label: '填寫回報',
              onPressed: row.booking == null
                  ? null
                  : () {
                      if (_deskView == _DeskView.split &&
                          MediaQuery.sizeOf(context).width >= _splitMin) {
                        setState(() {
                          _focusBookingId = row.bookingId;
                        });
                        return;
                      }
                      AdminDailyCareReportShortcut.openStayEntry(
                        context: context,
                        shopId: widget.shopId,
                        bookingId: row.bookingId,
                        booking: row.booking!,
                      );
                    },
            ),
        ],
      );
    }
    return button(label: '查看房間', onPressed: () => _openCalendar(row.room));
  }

  Widget _todoPane({
    required List<QueryDocumentSnapshot> unassigned,
    required List<_DashRoom> cleaningRows,
    required List<_DashRoom> careRows,
  }) {
    final bool empty =
        unassigned.isEmpty && cleaningRows.isEmpty && careRows.isEmpty;
    return SingleChildScrollView(
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: empty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: <Widget>[
                    Icon(
                      Icons.check_circle_outline,
                      color: RoomStatusPresentation.availableColor,
                      size: 36,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      '今日房務已處理完成',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '今天要處理',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '待分房訂單（${unassigned.length}）',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  if (unassigned.isEmpty)
                    const Text('無', style: TextStyle(color: Colors.grey))
                  else
                    ...unassigned.map((QueryDocumentSnapshot doc) {
                      final Map<String, dynamic> data =
                          Map<String, dynamic>.from(doc.data() as Map);
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          (data['customerName'] ?? '').toString(),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          '${data['roomTypeName'] ?? ''}｜${_stayRange(data)}',
                        ),
                        onTap: () => AdminBookingRoute.open(
                          context,
                          bookingId: doc.id,
                          data: data,
                          canEdit: true,
                        ),
                      );
                    }),
                  const Divider(height: 24),
                  Text(
                    '清潔中（${cleaningRows.length}）',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  if (cleaningRows.isEmpty)
                    const Text('無', style: TextStyle(color: Colors.grey))
                  else
                    ...cleaningRows.map((_DashRoom row) {
                      final bool busy = _busyKeys.contains(_actionKey(row.id));
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(row.name),
                        trailing: TextButton(
                          onPressed: busy
                              ? null
                              : () => _runRoomAction(
                                  roomId: row.id,
                                  successMessage: '${row.name} 已完成清潔，房間已恢復開放',
                                  action: () =>
                                      ShopRoomService.instance.completeCleaning(
                                        shopId: widget.shopId,
                                        roomId: row.id,
                                        date: selectedDate,
                                      ),
                                ),
                          child: busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('完成清潔'),
                        ),
                      );
                    }),
                  const Divider(height: 24),
                  Text(
                    '照護待填（${careRows.length}）',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  if (careRows.isEmpty)
                    const Text('無', style: TextStyle(color: Colors.grey))
                  else
                    ...careRows.map((_DashRoom row) {
                      return ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          '${row.name}　${row.booking?['customerName'] ?? ''}',
                        ),
                        subtitle: Text('剩餘 ${row.care?.pending ?? 0} 場'),
                        onTap: row.booking == null
                            ? null
                            : () {
                                if (_deskView == _DeskView.split &&
                                    MediaQuery.sizeOf(context).width >=
                                        _splitMin) {
                                  setState(() {
                                    _focusBookingId = row.bookingId;
                                  });
                                  return;
                                }
                                AdminDailyCareReportShortcut.openStayEntry(
                                  context: context,
                                  shopId: widget.shopId,
                                  bookingId: row.bookingId,
                                  booking: row.booking!,
                                );
                              },
                      );
                    }),
                ],
              ),
      ),
    );
  }

  Widget _errorPane(String title, Object? error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(
              '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => setState(() => _streamRetry += 1),
              child: const Text('重新載入畫面'),
            ),
          ],
        ),
      ),
    );
  }

  _DashRoom _buildRow({
    required Map<String, dynamic> room,
    required List<QueryDocumentSnapshot> bookings,
    required Map<String, String> calendarStatus,
    required Map<String, ShopRoomCareProgress> careProgress,
  }) {
    final String roomId = (room['id'] ?? '').toString();
    final _BookingHit hit = _bookingHit(
      bookings: bookings,
      roomId: roomId,
      day: selectedDate,
    );
    final String label = DaycareOccupancyService.housekeepingLabel(
      room: Map<String, dynamic>.from(room),
      calendarStatus: (calendarStatus['$roomId|$dateStr'] ?? '').toString(),
      stayBooking: hit.data,
    );
    return _DashRoom(
      room: room,
      label: label,
      presentation: RoomStatusPresentation.fromHousekeepingLabel(
        label,
        booking: hit.data,
      ),
      booking: hit.data,
      bookingId: hit.id,
      care: careProgress[roomId],
    );
  }

  Future<void> _runRoomAction({
    required String roomId,
    required String successMessage,
    required Future<void> Function() action,
  }) async {
    final String key = _actionKey(roomId);
    if (_busyKeys.contains(key)) {
      return;
    }
    setState(() {
      _busyKeys.add(key);
    });
    try {
      await action();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(successMessage)));
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: Colors.red.shade700,
          content: Text('操作失敗：$error'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _busyKeys.remove(key);
        });
      }
    }
  }

  Future<void> _openCalendar(Map<String, dynamic> room) async {
    String roomTypeName = (room['roomTypeName'] ?? '未設定房型').toString();
    String roomImageUrl = '';
    final String roomTypeId = (room['roomTypeId'] ?? '').toString();
    if (roomTypeId.isNotEmpty) {
      try {
        final DocumentSnapshot<Map<String, dynamic>> roomTypeDoc =
            await FirebaseFirestore.instance
                .collection('shops')
                .doc(widget.shopId)
                .collection('room_types')
                .doc(roomTypeId)
                .get();
        final Map<String, dynamic>? roomTypeData = roomTypeDoc.data();
        if (roomTypeData != null) {
          roomTypeName = (roomTypeData['name'] ?? roomTypeName).toString();
          final Object? images = roomTypeData['images'];
          if (images is List && images.isNotEmpty) {
            final Object? firstImage = images.first;
            if (firstImage is String) {
              roomImageUrl = firstImage;
            } else if (firstImage is Map) {
              roomImageUrl = (firstImage['imageUrl'] ?? '').toString();
            }
          }
        }
      } catch (_) {}
    }
    if (!mounted) {
      return;
    }
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => RoomCalendarPage(
          shopId: widget.shopId,
          roomId: room['id'],
          roomName: room['name'] ?? '',
          roomTypeName: roomTypeName,
          roomImageUrl: roomImageUrl,
        ),
      ),
    );
  }

  int _count(List<_DashRoom> rows, String label) {
    return rows.where((_DashRoom row) => row.label == label).length;
  }

  int _compareRooms(Map<String, dynamic> a, Map<String, dynamic> b) {
    final int type = naturalCompare(
      (a['roomTypeName'] ?? a['roomTypeId'] ?? '').toString(),
      (b['roomTypeName'] ?? b['roomTypeId'] ?? '').toString(),
    );
    if (type != 0) {
      return type;
    }
    return naturalCompare(
      (a['name'] ?? '').toString(),
      (b['name'] ?? '').toString(),
    );
  }

  Map<String, dynamic>? _bookingOnDate({
    required List<QueryDocumentSnapshot> bookings,
    required String roomId,
    required DateTime day,
  }) {
    return _bookingHit(bookings: bookings, roomId: roomId, day: day).data;
  }

  _BookingHit _bookingHit({
    required List<QueryDocumentSnapshot> bookings,
    required String roomId,
    required DateTime day,
  }) {
    for (final QueryDocumentSnapshot doc in bookings) {
      final Object? raw = doc.data();
      if (raw is! Map) {
        continue;
      }
      final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
      if ((data['roomId'] ?? '').toString() != roomId) {
        continue;
      }
      if (_occupiesDate(data, day)) {
        return _BookingHit(id: doc.id, data: data);
      }
    }
    return const _BookingHit();
  }

  bool _occupiesDate(Map<String, dynamic> booking, DateTime day) {
    final DateTime? start = _asDate(booking['startDate']);
    final DateTime? end = _asDate(booking['endDate']);
    if (start == null || end == null) {
      return false;
    }
    final DateTime dayOnly = DateTime(day.year, day.month, day.day);
    final DateTime startOnly = DateTime(start.year, start.month, start.day);
    final DateTime endOnly = DateTime(end.year, end.month, end.day);
    return !dayOnly.isBefore(startOnly) && dayOnly.isBefore(endOnly);
  }

  DateTime? _asDate(Object? raw) {
    if (raw is Timestamp) {
      return raw.toDate();
    }
    if (raw is DateTime) {
      return raw;
    }
    return null;
  }

  String _stayRange(Map<String, dynamic> data) {
    final DateTime? start = _asDate(data['startDate']);
    final DateTime? end = _asDate(data['endDate']);
    if (start == null || end == null) {
      return '';
    }
    return '${DateFormat('MM/dd').format(start)} - ${DateFormat('MM/dd').format(end)}';
  }
}

class _BookingHit {
  const _BookingHit({this.id = '', this.data});

  final String id;
  final Map<String, dynamic>? data;
}
