// 檔案名稱：lib/features/room/pages/room_dashboard_page.dart
// 功能說明：營運工作台主頁，整合房務管理與每日回報三種檢視。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_item.dart';
import 'package:petnest_saas/core/models/daily_care_report_center_snapshot.dart';
import 'package:petnest_saas/core/navigation/admin_booking_route.dart';
import 'package:petnest_saas/core/presentation/room_day_status.dart';
import 'package:petnest_saas/core/presentation/room_status_presentation.dart';
import 'package:petnest_saas/core/services/daily_care_report_center_service.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/services/shop_room_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/utils/natural_sort.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/auth/pages/room_calendar_page.dart';
import 'package:petnest_saas/features/room/pages/housekeeping_setting_page.dart';
import 'package:petnest_saas/features/room/widgets/room_status_chip.dart';
import 'package:petnest_saas/features/shop/pages/daily_care_report_center_page.dart';

enum _RoomQuickFilter { all, needs, checkedIn, vacant }

enum _DeskView { rooms, reports, split }

class _DashRoom {
  const _DashRoom({
    required this.room,
    required this.label,
    required this.presentation,
    this.booking,
    this.bookingId = '',
    this.pendingSessions = 0,
  });

  final Map<String, dynamic> room;
  final String label;
  final RoomStatusPresentation presentation;
  final Map<String, dynamic>? booking;
  final String bookingId;
  final int pendingSessions;

  String get id => (room['id'] ?? '').toString();
  String get name => (room['name'] ?? '').toString();
  String get typeName {
    final String name = (room['roomTypeName'] ?? '').toString().trim();
    return name.isEmpty ? '未分類' : name;
  }

  bool get needsHousekeeping {
    return label == DaycareOccupancyService.cleaningLabel ||
        label == DaycareOccupancyService.maintenanceLabel ||
        label == DaycareOccupancyService.closedLabel;
  }

  bool needsAction({required bool reportsOn}) {
    if (needsHousekeeping) {
      return true;
    }
    if (reportsOn && label == '入住中' && pendingSessions > 0) {
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
  static const double _splitMin = 1100;
  static const Color _accent = Color(0xFF1565C0);

  DateTime selectedDate = DateTime.now();
  bool _loadingPermission = true;
  bool _hasPermission = false;
  String _selectedRoomTypeFilter = '__all__';
  _RoomQuickFilter _quickFilter = _RoomQuickFilter.all;
  final Set<String> _collapsedTypes = <String>{};
  final Set<String> _busyKeys = <String>{};
  _DeskView _deskView = _DeskView.rooms;
  String _focusBookingId = '';
  String _selectedRoomId = '';
  int _streamRetry = 0;
  DailyCareReportCenterSnapshot? _lastReport;

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

  bool get _reportsOn => _lastReport?.settingEnabled == true;

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
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final bool desktop = width >= _desktopMin;
        final bool splitOk = width >= _splitMin;
        if (!splitOk && _deskView == _DeskView.split) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _deskView == _DeskView.split) {
              setState(() {
                _deskView = _DeskView.rooms;
              });
            }
          });
        }
        return StreamBuilder<DailyCareReportCenterSnapshot>(
          stream: DailyCareReportCenterService.instance.streamToday(
            shopId: widget.shopId,
            canOperate: true,
          ),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<DailyCareReportCenterSnapshot> reportSnap,
              ) {
                if (reportSnap.hasData &&
                    reportSnap.data != null &&
                    !reportSnap.data!.hasError) {
                  _lastReport = reportSnap.data;
                }
                return Scaffold(
                  backgroundColor: const Color(0xFFF6F7F9),
                  appBar: AppBar(
                    titleSpacing: 0,
                    title: _appTitle(),
                    actions: <Widget>[
                      if (_reportsOn) _viewSwitcher(splitOk: splitOk),
                      ShopTaskCenterButton(shopId: widget.shopId),
                      IconButton(
                        tooltip: '房務設定',
                        icon: const Icon(Icons.settings_outlined),
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => HousekeepingSettingPage(
                                shopId: widget.shopId,
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  body: StreamBuilder<List<Map<String, dynamic>>>(
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
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          final List<Map<String, dynamic>> rooms =
                              List<Map<String, dynamic>>.from(roomSnap.data!)
                                ..sort(_compareRooms);
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
                                            width: width,
                                            rooms: rooms,
                                            bookings: bookingSnap.data!.docs,
                                            calendarDocs:
                                                calendarSnap.data!.docs,
                                            report: _lastReport,
                                          );
                                        },
                                  );
                                },
                          );
                        },
                  ),
                );
              },
        );
      },
    );
  }

  Widget _appTitle() {
    if (!_reportsOn) {
      return const Text('房務管理');
    }
    final bool reportsView = _deskView == _DeskView.reports;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(reportsView ? '每日回報' : '營運工作台'),
        if (!reportsView)
          const Text(
            '今日房務與照護回報一覽',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.black54,
            ),
          ),
      ],
    );
  }

  Widget _viewSwitcher({required bool splitOk}) {
    final List<ButtonSegment<_DeskView>> segments = <ButtonSegment<_DeskView>>[
      const ButtonSegment<_DeskView>(
        value: _DeskView.rooms,
        label: Text('房務總覽'),
      ),
      const ButtonSegment<_DeskView>(
        value: _DeskView.reports,
        label: Text('每日回報'),
      ),
      if (splitOk)
        const ButtonSegment<_DeskView>(
          value: _DeskView.split,
          label: Text('分割工作台'),
        ),
    ];
    final _DeskView selected = _deskView == _DeskView.split && !splitOk
        ? _DeskView.rooms
        : _deskView;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: SegmentedButton<_DeskView>(
          showSelectedIcon: false,
          style: const ButtonStyle(
            visualDensity: VisualDensity.compact,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          segments: segments,
          selected: <_DeskView>{selected},
          onSelectionChanged: (Set<_DeskView> value) {
            setState(() {
              _deskView = value.first;
            });
          },
        ),
      ),
    );
  }

  Widget _workspace({
    required bool desktop,
    required double width,
    required List<Map<String, dynamic>> rooms,
    required List<QueryDocumentSnapshot> bookings,
    required List<QueryDocumentSnapshot> calendarDocs,
    required DailyCareReportCenterSnapshot? report,
  }) {
    final bool reportsOn = report?.settingEnabled == true;
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
            report: report,
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
          return row.needsAction(reportsOn: reportsOn);
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
    final int pendingHousekeeping =
        unassigned.length + cleaningCount + closedCount + blockedCount;
    final int pendingReports = reportsOn ? (report?.pendingCount ?? 0) : 0;
    final List<_DashRoom> cleaningRows = allRows
        .where(
          (_DashRoom row) => row.label == DaycareOccupancyService.cleaningLabel,
        )
        .toList();
    final List<_DashRoom> careRows = allRows
        .where(
          (_DashRoom row) =>
              reportsOn && row.label == '入住中' && row.pendingSessions > 0,
        )
        .toList();

    if (!reportsOn) {
      return _roomsOverview(
        desktop: desktop,
        rooms: rooms,
        filtered: filtered,
        allRows: allRows,
        bookings: bookings,
        calendarStatus: calendarStatus,
        typeNames: typeNames,
        typeFilter: typeFilter,
        unassigned: unassigned,
        cleaningRows: cleaningRows,
        careRows: const <_DashRoom>[],
        emptyCount: emptyCount,
        disabledCount: disabledCount,
        usingCount: usingCount,
        cleaningCount: cleaningCount,
        closedCount: closedCount,
        blockedCount: blockedCount,
        reportsOn: false,
        splitSelect: false,
      );
    }

    final bool splitOk = width >= _splitMin;
    final _DeskView view = _deskView == _DeskView.split && !splitOk
        ? _DeskView.rooms
        : _deskView;

    final Widget stats = _opsStats(
      desktop: desktop,
      usingCount: usingCount,
      cleaningCount: cleaningCount,
      pendingHousekeeping: pendingHousekeeping,
      pendingReports: pendingReports,
    );

    if (view == _DeskView.reports) {
      return Column(
        children: <Widget>[
          stats,
          Expanded(
            child: DailyCareReportCenterPage(
              shopId: widget.shopId,
              canOperate: true,
              embedded: true,
            ),
          ),
        ],
      );
    }

    if (view == _DeskView.split) {
      return Column(
        children: <Widget>[
          stats,
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  Expanded(
                    flex: 38,
                    child: _quickRoomPane(
                      allRows: allRows,
                      usingCount: usingCount,
                      pendingHousekeeping: pendingHousekeeping,
                      bookings: bookings,
                      calendarStatus: calendarStatus,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8),
                    child: VerticalDivider(width: 1, thickness: 1),
                  ),
                  Expanded(
                    flex: 62,
                    child: Material(
                      color: const Color(0xFFF7F8FA),
                      clipBehavior: Clip.antiAlias,
                      borderRadius: BorderRadius.circular(12),
                      child: DailyCareReportCenterPage(
                        key: ValueKey<String>('split-$_focusBookingId'),
                        shopId: widget.shopId,
                        canOperate: true,
                        embedded: true,
                        initialBookingId: _focusBookingId,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      children: <Widget>[
        stats,
        Expanded(
          child: _roomsOverview(
            desktop: desktop,
            rooms: rooms,
            filtered: filtered,
            allRows: allRows,
            bookings: bookings,
            calendarStatus: calendarStatus,
            typeNames: typeNames,
            typeFilter: typeFilter,
            unassigned: unassigned,
            cleaningRows: cleaningRows,
            careRows: careRows,
            emptyCount: emptyCount,
            disabledCount: disabledCount,
            usingCount: usingCount,
            cleaningCount: cleaningCount,
            closedCount: closedCount,
            blockedCount: blockedCount,
            reportsOn: true,
            splitSelect: false,
          ),
        ),
      ],
    );
  }

  Widget _roomsOverview({
    required bool desktop,
    required List<Map<String, dynamic>> rooms,
    required List<_DashRoom> filtered,
    required List<_DashRoom> allRows,
    required List<QueryDocumentSnapshot> bookings,
    required Map<String, String> calendarStatus,
    required List<String> typeNames,
    required String typeFilter,
    required List<QueryDocumentSnapshot> unassigned,
    required List<_DashRoom> cleaningRows,
    required List<_DashRoom> careRows,
    required int emptyCount,
    required int disabledCount,
    required int usingCount,
    required int cleaningCount,
    required int closedCount,
    required int blockedCount,
    required bool reportsOn,
    required bool splitSelect,
  }) {
    final Widget header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        _dateBar(desktop: desktop),
        _filters(rooms: rooms, typeNames: typeNames, typeFilter: typeFilter),
        if (!reportsOn)
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
                    reportsOn: reportsOn,
                  ),
          ),
        ],
      );
    }

    final String displayRoomId = _displayRoomId(filtered);
    _syncDesktopRoomSelection(displayRoomId);
    final _DashRoom? selectedRow = _roomById(filtered, displayRoomId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: <Widget>[
          header,
          const SizedBox(height: 8),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(
                  flex: 42,
                  child: rooms.isEmpty
                      ? const Center(child: Text('尚無房間'))
                      : _groupedList(
                          filtered: filtered,
                          allRows: allRows,
                          bookings: bookings,
                          calendarStatus: calendarStatus,
                          dense: true,
                          splitSelect: false,
                          reportsOn: reportsOn,
                          workbench: true,
                          selectedRoomId: displayRoomId,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(flex: 58, child: _roomRecordPane(row: selectedRow)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _displayRoomId(List<_DashRoom> filtered) {
    if (_selectedRoomId.isNotEmpty &&
        filtered.any((_DashRoom row) => row.id == _selectedRoomId)) {
      return _selectedRoomId;
    }
    for (final _DashRoom row in filtered) {
      if (row.label == '入住中') {
        return row.id;
      }
    }
    if (filtered.isNotEmpty) {
      return filtered.first.id;
    }
    return '';
  }

  void _syncDesktopRoomSelection(String displayRoomId) {
    if (displayRoomId == _selectedRoomId) {
      return;
    }
    final String previous = _selectedRoomId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _selectedRoomId != previous) {
        return;
      }
      setState(() {
        _selectedRoomId = displayRoomId;
      });
    });
  }

  _DashRoom? _roomById(List<_DashRoom> rows, String id) {
    if (id.isEmpty) {
      return null;
    }
    for (final _DashRoom row in rows) {
      if (row.id == id) {
        return row;
      }
    }
    return null;
  }

  Widget _roomRecordPane({required _DashRoom? row}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF4F5F7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      clipBehavior: Clip.antiAlias,
      child: row == null
          ? const Center(
              child: Text(
                '請從左側選擇房間',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54,
                ),
              ),
            )
          : RoomCalendarPage(
              key: ValueKey<String>('room-record-${row.id}'),
              embedded: true,
              embeddedHeader: _recordIdentity(row),
              shopId: widget.shopId,
              roomId: row.id,
              roomName: row.name,
              roomTypeName: row.typeName,
              roomImageUrl: '',
              room: row.room,
            ),
    );
  }

  Widget _recordIdentity(_DashRoom row) {
    final String roomTypeId = (row.room['roomTypeId'] ?? '').toString();
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 6, 10, 4),
      child: Row(
        children: <Widget>[
          _RoomTypeThumb(
            shopId: widget.shopId,
            roomTypeId: roomTypeId,
            size: 28,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    RoomStatusChip(
                      presentation: row.presentation,
                      compact: true,
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  row.typeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _opsStats({
    required bool desktop,
    required int usingCount,
    required int cleaningCount,
    required int pendingHousekeeping,
    required int pendingReports,
  }) {
    final List<_OpsStat> items = <_OpsStat>[
      _OpsStat(
        icon: Icons.login,
        label: '入住中',
        count: usingCount,
        color: RoomStatusPresentation.checkedInColor,
      ),
      _OpsStat(
        icon: Icons.cleaning_services_outlined,
        label: '待清潔',
        count: cleaningCount,
        color: RoomStatusPresentation.cleaningColor,
      ),
      _OpsStat(
        icon: Icons.assignment_outlined,
        label: '待處理房務',
        count: pendingHousekeeping,
        color: const Color(0xFF6A1B9A),
      ),
      _OpsStat(
        icon: Icons.edit_note_outlined,
        label: '待填回報',
        count: pendingReports,
        color: const Color(0xFFE65100),
      ),
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: desktop
          ? Row(
              children: items
                  .map(
                    (_OpsStat item) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: _opsStatCard(item),
                      ),
                    ),
                  )
                  .toList(),
            )
          : GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              childAspectRatio: 2.6,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              children: items.map(_opsStatCard).toList(),
            ),
    );
  }

  Widget _opsStatCard(_OpsStat item) {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: <Widget>[
          Icon(item.icon, color: item.color, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  '${item.count}',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: item.color,
                  ),
                ),
                Text(
                  item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _quickRoomPane({
    required List<_DashRoom> allRows,
    required int usingCount,
    required int pendingHousekeeping,
    required List<QueryDocumentSnapshot> bookings,
    required Map<String, String> calendarStatus,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '房間快速處理',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                _compactDateRow(),
                const SizedBox(height: 6),
                Text(
                  '入住中 $usingCount 間／待處理 $pendingHousekeeping 項',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.black54,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _groupedList(
              filtered: allRows,
              allRows: allRows,
              bookings: bookings,
              calendarStatus: calendarStatus,
              dense: true,
              splitSelect: true,
              reportsOn: true,
              compact: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactDateRow() {
    return Row(
      children: <Widget>[
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () {
            setState(() {
              selectedDate = selectedDate.subtract(const Duration(days: 1));
            });
          },
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: Text(
            DateFormat('MM/dd').format(selectedDate),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        IconButton(
          visualDensity: VisualDensity.compact,
          onPressed: () {
            setState(() {
              selectedDate = selectedDate.add(const Duration(days: 1));
            });
          },
          icon: const Icon(Icons.chevron_right),
        ),
        TextButton(
          onPressed: DateUtils.isSameDay(selectedDate, DateTime.now())
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
    required bool reportsOn,
    bool compact = false,
    bool workbench = false,
    String selectedRoomId = '',
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
      primary: workbench ? false : null,
      padding: EdgeInsets.only(bottom: workbench ? 12 : 24),
      itemCount: keys.length,
      itemBuilder: (BuildContext context, int index) {
        final String type = keys[index];
        final List<_DashRoom> rows = groups[type]!;
        final int need = rows
            .where((_DashRoom row) => row.needsAction(reportsOn: reportsOn))
            .length;
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
                padding: EdgeInsets.fromLTRB(workbench ? 2 : 16, 10, 16, 6),
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
                  reportsOn: reportsOn,
                  compact: compact,
                  workbench: workbench,
                  selectedRoomId: selectedRoomId,
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
    required bool reportsOn,
    required bool compact,
    bool workbench = false,
    String selectedRoomId = '',
  }) {
    final bool busy = _busyKeys.contains(_actionKey(row.id));
    final bool vacant = row.label == DaycareOccupancyService.vacantLabel;
    final bool selected = workbench
        ? selectedRoomId == row.id
        : splitSelect && _selectedRoomId == row.id;
    final DateTime today = DateTime.now();
    final List<Color> dots = weekDays.map((DateTime day) {
      final RoomDayStatus dayStatus = resolveRoomDayStatus(
        date: day,
        today: today,
        room: Map<String, dynamic>.from(row.room),
        calendarStatus:
            (calendarStatus['${row.id}|${DateFormat('yyyy-MM-dd').format(day)}'] ??
                    '')
                .toString(),
        booking: _bookingOnDate(bookings: bookings, roomId: row.id, day: day),
      );
      // 桌機工作台才把過去無訂單的日期轉灰，手機維持原本狀態色。
      return workbench ? dayStatus.color : dayStatus.presentation.color;
    }).toList();
    if (workbench) {
      return _workbenchRoomTile(row: row, selected: selected, dots: dots);
    }
    final Widget actions = _rowActions(
      row: row,
      busy: busy,
      reportsOn: reportsOn,
      splitSelect: splitSelect,
    );
    final String pets = _petNames(row.booking);
    final Widget body = Padding(
      padding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: compact ? 8 : (vacant ? 8 : 10),
      ),
      child: compact
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        row.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(
                        row.typeName,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                      if (pets.isNotEmpty)
                        Text(
                          pets,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      if (row.booking != null)
                        Text(
                          (row.booking!['customerName'] ?? '').toString(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: <Widget>[
                          RoomStatusChip(
                            presentation: row.presentation,
                            compact: true,
                          ),
                          if (reportsOn &&
                              row.label == '入住中' &&
                              row.pendingSessions > 0)
                            _pendingChip(row.pendingSessions),
                        ],
                      ),
                    ],
                  ),
                ),
                if (row.label == '入住中' && row.pendingSessions > 0)
                  const Icon(Icons.chevron_right, color: _accent),
              ],
            )
          : Row(
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
                        if (pets.isNotEmpty)
                          Text(
                            pets,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12),
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
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                      const SizedBox(height: 6),
                      RoomWeekDots(colors: dots),
                      if (reportsOn &&
                          row.label == '入住中' &&
                          row.pendingSessions > 0) ...<Widget>[
                        const SizedBox(height: 6),
                        _pendingChip(row.pendingSessions),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    RoomStatusChip(
                      presentation: row.presentation,
                      compact: dense,
                    ),
                    const SizedBox(height: 6),
                    actions,
                  ],
                ),
              ],
            ),
    );
    return Material(
      color: selected ? const Color(0xFFF3F8FF) : Colors.white,
      child: InkWell(
        onTap: () {
          if (splitSelect) {
            setState(() {
              _selectedRoomId = row.id;
              _focusBookingId = row.label == '入住中' ? row.bookingId : '';
            });
            return;
          }
          _openCalendar(row.room);
        },
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: selected ? const Color(0xFFF3F8FF) : null,
            border: Border.all(
              color: selected
                  ? _accent
                  : (row.needsAction(reportsOn: reportsOn)
                        ? row.presentation.border
                        : Colors.grey.shade200),
            ),
          ),
          child: body,
        ),
      ),
    );
  }

  Widget _workbenchRoomTile({
    required _DashRoom row,
    required bool selected,
    required List<Color> dots,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: selected ? const Color(0xFFE8F2FC) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            setState(() {
              _selectedRoomId = row.id;
            });
          },
          child: Container(
            constraints: const BoxConstraints(minHeight: 84),
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? _accent : const Color(0xFFE5E7EB),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Flexible(
                      child: Text(
                        row.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    RoomStatusChip(
                      presentation: row.presentation,
                      compact: true,
                    ),
                  ],
                ),
                Text(
                  row.typeName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                RoomWeekDots(colors: dots),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _pendingChip(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFE65100).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        '待填 $count 場',
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: Color(0xFFE65100),
        ),
      ),
    );
  }

  Widget _rowActions({
    required _DashRoom row,
    required bool busy,
    required bool reportsOn,
    required bool splitSelect,
    bool workbench = false,
  }) {
    Widget button({required String label, required VoidCallback? onPressed}) {
      return TextButton(
        onPressed: busy ? null : onPressed,
        style: TextButton.styleFrom(
          visualDensity: VisualDensity.compact,
          minimumSize: Size(48, workbench ? 32 : 40),
          padding: EdgeInsets.symmetric(horizontal: workbench ? 6 : 8),
          tapTargetSize: workbench
              ? MaterialTapTargetSize.shrinkWrap
              : MaterialTapTargetSize.padded,
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
          if (reportsOn && row.pendingSessions > 0)
            button(
              label: '回報',
              onPressed: row.bookingId.isEmpty
                  ? null
                  : () {
                      if (splitSelect &&
                          MediaQuery.sizeOf(context).width >= _splitMin) {
                        setState(() {
                          _selectedRoomId = row.id;
                          _focusBookingId = row.bookingId;
                        });
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DailyCareReportCenterPage(
                            shopId: widget.shopId,
                            canOperate: true,
                            initialBookingId: row.bookingId,
                            focusBookingId: row.bookingId,
                          ),
                        ),
                      );
                    },
            ),
        ],
      );
    }
    if (workbench) {
      return const SizedBox.shrink();
    }
    return button(label: '查看房間', onPressed: () => _openCalendar(row.room));
  }

  // 桌機房務總覽改為單房紀錄，此面板暫不掛載；待辦計算與元件保留。
  // ignore: unused_element
  Widget _todoPane({
    required List<QueryDocumentSnapshot> unassigned,
    required List<_DashRoom> cleaningRows,
    required List<_DashRoom> careRows,
    required bool reportsOn,
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
                  if (!reportsOn) ...<Widget>[
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
                          subtitle: Text('剩餘 ${row.pendingSessions} 場'),
                          onTap: row.bookingId.isEmpty
                              ? null
                              : () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => DailyCareReportCenterPage(
                                        shopId: widget.shopId,
                                        canOperate: true,
                                        initialBookingId: row.bookingId,
                                        focusBookingId: row.bookingId,
                                      ),
                                    ),
                                  );
                                },
                        );
                      }),
                  ],
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
    required DailyCareReportCenterSnapshot? report,
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
    int pending = 0;
    if (report != null && report.settingEnabled && hit.id.isNotEmpty) {
      pending = report.items
          .where(
            (DailyCareReportCenterItem item) =>
                item.bookingId == hit.id && !item.isCompleted,
          )
          .length;
    }
    return _DashRoom(
      room: room,
      label: label,
      presentation: RoomStatusPresentation.fromHousekeepingLabel(
        label,
        booking: hit.data,
      ),
      booking: hit.data,
      bookingId: hit.id,
      pendingSessions: pending,
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
          roomImageUrl = _roomTypeImageUrl(roomTypeData);
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
    _BookingHit best = const _BookingHit();
    int bestPriority = -1;
    for (final QueryDocumentSnapshot doc in bookings) {
      final Object? raw = doc.data();
      if (raw is! Map) {
        continue;
      }
      final Map<String, dynamic> data = Map<String, dynamic>.from(raw);
      if ((data['roomId'] ?? '').toString() != roomId) {
        continue;
      }
      if (!isActiveRoomDayBooking(data) || !_occupiesDate(data, day)) {
        continue;
      }
      // 同一天有多筆時依固定順序取用，右側月曆才會選到同一筆。
      final int priority = roomDayBookingPriority(data);
      if (priority > bestPriority) {
        bestPriority = priority;
        best = _BookingHit(id: doc.id, data: data);
      }
    }
    return best;
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

  String _petNames(Map<String, dynamic>? booking) {
    if (booking == null) {
      return '';
    }
    final Object? names = booking['petNames'] ?? booking['petName'];
    if (names is List) {
      return names
          .map((Object? value) => value.toString().trim())
          .where((String value) => value.isNotEmpty)
          .join('、');
    }
    if (names is String && names.trim().isNotEmpty) {
      return names.trim();
    }
    final Object? pets = booking['pets'];
    if (pets is List) {
      return pets
          .map((Object? value) {
            if (value is Map) {
              return (value['name'] ?? '').toString().trim();
            }
            return value.toString().trim();
          })
          .where((String value) => value.isNotEmpty)
          .join('、');
    }
    return '';
  }
}

class _OpsStat {
  const _OpsStat({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;
}

class _BookingHit {
  const _BookingHit({this.id = '', this.data});

  final String id;
  final Map<String, dynamic>? data;
}

String _roomTypeImageUrl(Map<String, dynamic>? roomTypeData) {
  if (roomTypeData == null) {
    return '';
  }
  final Object? images = roomTypeData['images'];
  if (images is! List || images.isEmpty) {
    return '';
  }
  final Object? firstImage = images.first;
  if (firstImage is String) {
    return firstImage;
  }
  if (firstImage is Map) {
    return (firstImage['imageUrl'] ?? '').toString();
  }
  return '';
}

class _RoomTypeThumb extends StatefulWidget {
  const _RoomTypeThumb({
    required this.shopId,
    required this.roomTypeId,
    this.size = 40,
  });

  final String shopId;
  final String roomTypeId;
  final double size;

  @override
  State<_RoomTypeThumb> createState() => _RoomTypeThumbState();
}

class _RoomTypeThumbState extends State<_RoomTypeThumb> {
  String _url = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _RoomTypeThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.roomTypeId != widget.roomTypeId ||
        oldWidget.shopId != widget.shopId) {
      _url = '';
      _load();
    }
  }

  Future<void> _load() async {
    final String roomTypeId = widget.roomTypeId;
    if (roomTypeId.isEmpty) {
      return;
    }
    String imageUrl = '';
    try {
      final DocumentSnapshot<Map<String, dynamic>> roomTypeDoc =
          await FirebaseFirestore.instance
              .collection('shops')
              .doc(widget.shopId)
              .collection('room_types')
              .doc(roomTypeId)
              .get();
      imageUrl = _roomTypeImageUrl(roomTypeDoc.data());
    } catch (_) {}
    if (!mounted || roomTypeId != widget.roomTypeId || imageUrl.isEmpty) {
      return;
    }
    setState(() {
      _url = imageUrl;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_url.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(
          _url,
          width: widget.size,
          height: widget.size,
          fit: BoxFit.cover,
          errorBuilder:
              (BuildContext context, Object error, StackTrace? stack) {
                return const SizedBox.shrink();
              },
        ),
      ),
    );
  }
}
