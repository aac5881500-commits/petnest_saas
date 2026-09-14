// 檔案名稱：lib/features/booking/pages/customer_daily_care_page.dart
// 功能說明：讓會員在入住期間，以日誌方式查看店家每日照護紀錄。
// 🐾 客戶端每日照護紀錄頁
// 使用「日期切換 + 照護紀錄切換」，一次只顯示一筆。
// 日期規則：入住日包含、退房日不包含。
// 本頁為唯讀，不改照護資料與下載邏輯。

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/shop_permission_keys.dart';
import '../../../core/models/booking_kind.dart';
import '../../../core/models/daily_care_date_helper.dart';
import '../../../core/models/daily_care_entitlement.dart';
import '../../../core/models/daily_care_photo_model.dart';
import '../../../core/models/daily_care_record_model.dart';
import '../../../core/models/daily_care_setting_model.dart';
import '../../../core/models/daily_care_stay_info.dart';
import '../../../core/services/daily_care_daycare_access.dart';
import '../../../core/services/daily_care_photo_service.dart';
import '../../../core/services/daily_care_record_service.dart';
import '../../../core/services/daily_care_setting_service.dart';
import '../../../core/services/shop_service.dart';
import '../../../core/widgets/daily_care_card_surface.dart';
import '../../../core/widgets/daily_care_journal_renderer.dart';

class CustomerDailyCarePage extends StatefulWidget {
  const CustomerDailyCarePage({
    super.key,
    required this.shopId,
    required this.bookingId,
    required this.roomName,
    this.previewMode = false,
    this.initialDate,
    this.initialSessionIndex,
    this.journalTitle,
  });

  final String shopId;
  final String bookingId;
  final String roomName;
  final bool previewMode;
  final DateTime? initialDate;
  final int? initialSessionIndex;
  final String? journalTitle;

  /// 店家預覽：owner、可管理預約、或可看房務管理的成員。
  /// 不依賴 booking.userId，手動訂單也可預覽。
  static Future<bool> canShopPreview(String shopId) async {
    final User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return false;
    }

    final Map<String, dynamic>? member = await ShopService.instance
        .getUserMemberInShop(shopId: shopId, uid: user.uid);
    if (member == null) {
      return false;
    }

    final bool allowed =
        ShopService.instance.hasPermission(
          member,
          ShopPermissionKeys.manageRoomDashboard,
        ) ||
        ShopService.instance.hasPermission(
          member,
          ShopPermissionKeys.manageBookings,
        );
    debugPrint(
      '[DailyCarePreview] access check\n'
      'shopId=$shopId\n'
      'uid=${user.uid}\n'
      'role=${member['role']}\n'
      'manageRoomDashboard='
      '${ShopService.instance.hasPermission(member, ShopPermissionKeys.manageRoomDashboard)}\n'
      'manageBookings='
      '${ShopService.instance.hasPermission(member, ShopPermissionKeys.manageBookings)}\n'
      'allowed=$allowed',
    );
    return allowed;
  }

  @override
  State<CustomerDailyCarePage> createState() => _CustomerDailyCarePageState();
}

class _CustomerDailyCarePageState extends State<CustomerDailyCarePage> {
  String? _selectedDateKey;
  int? _selectedSessionIndex;
  Future<bool>? _previewAccessFuture;
  Object? _loggedLoadError;

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) {
      _selectedDateKey = DailyCareDateHelper.dateKey(widget.initialDate!);
    }
    if (widget.initialSessionIndex != null) {
      _selectedSessionIndex = widget.initialSessionIndex;
    }
    if (widget.previewMode) {
      _previewAccessFuture = CustomerDailyCarePage.canShopPreview(
        widget.shopId,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.previewMode) {
      return FutureBuilder<bool>(
        future: _previewAccessFuture,
        builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
          if (!snapshot.hasData) {
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }
          if (snapshot.data != true) {
            return Scaffold(
              appBar: AppBar(title: Text(widget.journalTitle ?? '每日照護日誌')),
              body: const Center(child: Text('沒有預覽客戶照護日誌的權限')),
            );
          }
          return _buildJournal();
        },
      );
    }

    return _buildJournal();
  }

  Widget _buildJournal() {
    return StreamBuilder<DailyCareSettingModel>(
      stream: DailyCareSettingService.instance.streamSetting(widget.shopId),
      builder: (context, settingSnapshot) {
        final DailyCareSettingModel setting =
            settingSnapshot.data ?? const DailyCareSettingModel();
        if (settingSnapshot.hasData) {
          debugPrint(
            'DailyCare cardBackground '
            'type=${setting.cardBackgroundType} '
            'preset=${setting.cardBackgroundPreset} '
            'fit=${setting.cardBackgroundImageFit} '
            'fade=${setting.cardBackgroundImageFade} '
            'urlEmpty=${setting.cardBackgroundImageUrl.trim().isEmpty} '
            'urlLen=${setting.cardBackgroundImageUrl.trim().length} '
            'hasCustom=${setting.hasCustomCardBackgroundImage} '
            'hasVisual=${setting.hasCardBackgroundVisual}',
          );
        }

        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('bookings')
              .doc(widget.bookingId)
              .snapshots(),
          builder: (context, bookingSnapshot) {
            if (bookingSnapshot.hasError) {
              _logLoadFailure(
                stage: 'booking',
                error: bookingSnapshot.error,
                stackTrace: bookingSnapshot.stackTrace,
              );
              return _journalScaffold(
                setting: setting,
                child: _errorView(_loadErrorMessage(bookingSnapshot.error)),
              );
            }

            if (!bookingSnapshot.hasData) {
              return _journalScaffold(
                setting: setting,
                child: const Center(child: CircularProgressIndicator()),
              );
            }

            if (!bookingSnapshot.data!.exists) {
              return _journalScaffold(
                setting: setting,
                child: _errorView('找不到這筆住宿資料'),
              );
            }

            final Map<String, dynamic> bookingData =
                bookingSnapshot.data?.data() ?? <String, dynamic>{};
            final String bookingUserId = (bookingData['userId'] ?? '')
                .toString()
                .trim();
            final String bookingShopId = (bookingData['shopId'] ?? '')
                .toString()
                .trim();
            final String? currentUid = FirebaseAuth.instance.currentUser?.uid;

            if (widget.previewMode) {
              if (bookingShopId.isNotEmpty && bookingShopId != widget.shopId) {
                return _journalScaffold(
                  setting: setting,
                  child: _errorView('你沒有權限查看這筆照護紀錄'),
                );
              }
            } else if (currentUid == null ||
                bookingUserId.isEmpty ||
                bookingUserId != currentUid) {
              debugPrint(
                '[DailyCarePreview] customer ownership blocked\n'
                'shopId=${widget.shopId}\n'
                'bookingId=${widget.bookingId}\n'
                'previewMode=false\n'
                'bookingUserId=$bookingUserId\n'
                'currentUid=$currentUid',
              );
              return _journalScaffold(
                setting: setting,
                child: _errorView('你沒有權限查看這筆照護紀錄'),
              );
            }

            final bool isDaycare = BookingKind.isDaycare(bookingData);
            final String journalTitle =
                widget.journalTitle ?? (isDaycare ? '本次安親回報' : '每日照護日誌');
            final DailyCareStayInfo stay = DailyCareStayInfo.fromBookingMap(
              bookingData,
              fallbackRoomName: widget.roomName,
            );
            final List<DateTime> careDates = isDaycare
                ? <DateTime>[
                    DailyCareDaycareAccess.serviceCalendarDate(bookingData) ??
                        DailyCareDateHelper.todayInTaipei(),
                  ]
                : stay
                      .careDateKeys()
                      .map(DailyCareDateHelper.parseDateKey)
                      .whereType<DateTime>()
                      .toList();
            final DailyCareEntitlement entitlement =
                DailyCareEntitlement.fromMap(
                  bookingData['dailyCareEntitlement'] is Map
                      ? Map<String, dynamic>.from(
                          bookingData['dailyCareEntitlement'] as Map,
                        )
                      : null,
                );
            final int sessionCount = entitlement.finalReports > 0
                ? entitlement.finalReports
                : (isDaycare
                      ? setting.daycareSessionCount
                      : setting.sessionCount);

            return StreamBuilder<List<DailyCareRecordModel>>(
              stream: DailyCareRecordService.instance.streamBookingRecords(
                bookingId: widget.bookingId,
                shopId: widget.previewMode ? widget.shopId : null,
                careDates: widget.previewMode ? careDates : null,
                sessionCount: sessionCount,
              ),
              builder: (context, recordSnapshot) {
                if (recordSnapshot.hasError) {
                  _logLoadFailure(
                    stage: 'daily_care_records',
                    error: recordSnapshot.error,
                    stackTrace: recordSnapshot.stackTrace,
                    selectedDate: _selectedDateKey,
                  );
                  return _journalScaffold(
                    setting: setting,
                    title: journalTitle,
                    child: _errorView(_loadErrorMessage(recordSnapshot.error)),
                  );
                }

                if (!recordSnapshot.hasData) {
                  return _journalScaffold(
                    setting: setting,
                    title: journalTitle,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                }

                final List<DailyCareRecordModel> records =
                    recordSnapshot.data ?? <DailyCareRecordModel>[];
                final Map<String, List<DailyCareRecordModel>> grouped =
                    _groupRecords(records);
                final List<String> dateKeys = _resolveDateKeys(
                  stay: stay,
                  recordDateKeys: grouped.keys.toList()..sort(),
                  extraDateKeys: isDaycare
                      ? careDates.map(DailyCareDateHelper.dateKey).toList()
                      : const <String>[],
                );

                if (dateKeys.isEmpty) {
                  return _journalScaffold(
                    setting: setting,
                    title: journalTitle,
                    child: const _EmptyCareView(),
                  );
                }

                final String selectedDateKey = _resolveSelectedDateKey(
                  dateKeys,
                );
                final List<DailyCareRecordModel> selectedDateRecords =
                    List<DailyCareRecordModel>.from(
                      grouped[selectedDateKey] ?? <DailyCareRecordModel>[],
                    )..sort((DailyCareRecordModel a, DailyCareRecordModel b) {
                      return a.sessionIndex.compareTo(b.sessionIndex);
                    });

                final List<DailyCareJournalSessionTab> sessionTabs =
                    _buildSessionTabs(
                      setting: setting,
                      records: selectedDateRecords,
                      sessionCount: sessionCount,
                      sessionLabels: entitlement.sessionLabels,
                    );
                final int selectedSessionIndex = _resolveSelectedSessionIndex(
                  sessionTabs,
                  selectedDateRecords,
                );
                final DailyCareRecordModel? record = _recordForSession(
                  selectedDateRecords,
                  selectedSessionIndex,
                );

                return _journalScaffold(
                  setting: setting,
                  title: journalTitle,
                  child: _journalRenderer(
                    setting: setting,
                    stay: stay,
                    dateKeys: dateKeys,
                    selectedDateKey: selectedDateKey,
                    sessionTabs: sessionTabs,
                    selectedSessionIndex: selectedSessionIndex,
                    record: record,
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _journalScaffold({
    required DailyCareSettingModel setting,
    required Widget child,
    String? title,
  }) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(title ?? widget.journalTitle ?? '每日照護日誌'),
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      body: Stack(
        children: <Widget>[
          Positioned.fill(
            child: DailyCareJournalPageBackground(setting: setting),
          ),
          Column(
            children: <Widget>[
              SizedBox(
                height: MediaQuery.paddingOf(context).top + kToolbarHeight,
              ),
              if (widget.previewMode) _previewBanner(),
              Expanded(child: child),
            ],
          ),
        ],
      ),
    );
  }

  Widget _previewBanner() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F1F8),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFB7D0E5)),
      ),
      child: const Row(
        children: <Widget>[
          Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF3D6F9F)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              '店家預覽・此畫面為客戶看到的內容',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF3D6F9F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<String> _resolveDateKeys({
    required DailyCareStayInfo stay,
    required List<String> recordDateKeys,
    List<String> extraDateKeys = const <String>[],
  }) {
    if (extraDateKeys.isNotEmpty) {
      return extraDateKeys;
    }
    final List<String> stayKeys = stay.careDateKeys();
    if (stayKeys.isNotEmpty) {
      return stayKeys;
    }

    final List<String> fallback = recordDateKeys.toList()..sort();
    return fallback;
  }

  Map<String, List<DailyCareRecordModel>> _groupRecords(
    List<DailyCareRecordModel> records,
  ) {
    final Map<String, List<DailyCareRecordModel>> grouped =
        <String, List<DailyCareRecordModel>>{};

    for (final DailyCareRecordModel record in records) {
      final String dateKey = _dateKey(record.recordDate);
      grouped.putIfAbsent(dateKey, () => <DailyCareRecordModel>[]);
      grouped[dateKey]!.add(record);
    }

    return grouped;
  }

  String _resolveSelectedDateKey(List<String> dateKeys) {
    if (_selectedDateKey != null && dateKeys.contains(_selectedDateKey)) {
      return _selectedDateKey!;
    }

    _selectedDateKey = dateKeys.last;
    return _selectedDateKey!;
  }

  int _resolveSelectedSessionIndex(
    List<DailyCareJournalSessionTab> tabs,
    List<DailyCareRecordModel> records,
  ) {
    if (_selectedSessionIndex != null &&
        tabs.any(
          (DailyCareJournalSessionTab tab) =>
              tab.sessionIndex == _selectedSessionIndex,
        )) {
      return _selectedSessionIndex!;
    }

    if (records.isNotEmpty) {
      _selectedSessionIndex = records.first.sessionIndex;
    } else {
      _selectedSessionIndex = tabs.first.sessionIndex;
    }

    return _selectedSessionIndex!;
  }

  DailyCareRecordModel? _recordForSession(
    List<DailyCareRecordModel> records,
    int sessionIndex,
  ) {
    for (final DailyCareRecordModel record in records) {
      if (record.sessionIndex == sessionIndex) {
        return record;
      }
    }

    return null;
  }

  Widget _journalRenderer({
    required DailyCareSettingModel setting,
    required DailyCareStayInfo stay,
    required List<String> dateKeys,
    required String selectedDateKey,
    required List<DailyCareJournalSessionTab> sessionTabs,
    required int selectedSessionIndex,
    required DailyCareRecordModel? record,
  }) {
    if (record == null || !setting.photoEnabled) {
      return DailyCareJournalRenderer(
        setting: setting,
        stay: stay,
        dateKeys: dateKeys,
        selectedDateKey: selectedDateKey,
        sessionTabs: sessionTabs,
        selectedSessionIndex: selectedSessionIndex,
        record: record,
        fallbackRoomName: widget.roomName,
        showPhotoSection: false,
        onDateSelected: (String dateKey) {
          setState(() {
            _selectedDateKey = dateKey;
            _selectedSessionIndex = null;
          });
        },
        onSessionSelected: (int sessionIndex) {
          setState(() {
            _selectedSessionIndex = sessionIndex;
          });
        },
      );
    }

    return StreamBuilder<List<DailyCarePhotoModel>>(
      stream: DailyCarePhotoService.instance.streamSessionPhotos(
        shopId: widget.shopId,
        bookingId: widget.bookingId,
        recordDate: record.recordDate,
        sessionIndex: record.sessionIndex,
      ),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<DailyCarePhotoModel>> snapshot,
          ) {
            return DailyCareJournalRenderer(
              setting: setting,
              stay: stay,
              dateKeys: dateKeys,
              selectedDateKey: selectedDateKey,
              sessionTabs: sessionTabs,
              selectedSessionIndex: selectedSessionIndex,
              record: record,
              fallbackRoomName: widget.roomName,
              photos: snapshot.data ?? const <DailyCarePhotoModel>[],
              photosLoading:
                  snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData,
              showPhotoSection: true,
              onDateSelected: (String dateKey) {
                setState(() {
                  _selectedDateKey = dateKey;
                  _selectedSessionIndex = null;
                });
              },
              onSessionSelected: (int sessionIndex) {
                setState(() {
                  _selectedSessionIndex = sessionIndex;
                });
              },
            );
          },
    );
  }

  List<DailyCareJournalSessionTab> _buildSessionTabs({
    required DailyCareSettingModel setting,
    required List<DailyCareRecordModel> records,
    int? sessionCount,
    List<String> sessionLabels = const <String>[],
  }) {
    int tabCount = sessionCount ?? setting.sessionCount;
    if (records.isNotEmpty) {
      final int maxIndex = records
          .map((DailyCareRecordModel record) => record.sessionIndex)
          .reduce((int a, int b) => a > b ? a : b);
      if (maxIndex + 1 > tabCount) {
        tabCount = maxIndex + 1;
      }
    }

    if (tabCount < 1) {
      tabCount = 1;
    }

    return List<DailyCareJournalSessionTab>.generate(tabCount, (int index) {
      return DailyCareJournalSessionTab(
        sessionIndex: index,
        sessionName: index < sessionLabels.length &&
                sessionLabels[index].trim().isNotEmpty
            ? sessionLabels[index]
            : setting.sessionLabel(index),
      );
    });
  }

  static String _dateKey(DateTime value) {
    return DailyCareDateHelper.dateKey(value);
  }

  void _logLoadFailure({
    required String stage,
    required Object? error,
    StackTrace? stackTrace,
    String? selectedDate,
  }) {
    if (identical(_loggedLoadError, error)) {
      return;
    }
    _loggedLoadError = error;
    final Object? raw = error;
    final String code = raw is FirebaseException ? raw.code : '';
    final String message = raw is FirebaseException
        ? (raw.message ?? raw.toString())
        : raw?.toString() ?? 'null';
    debugPrint(
      '[DailyCarePreview] load failed\n'
      'stage=$stage\n'
      'shopId=${widget.shopId}\n'
      'bookingId=${widget.bookingId}\n'
      'selectedDate=${selectedDate ?? _selectedDateKey ?? ''}\n'
      'previewMode=${widget.previewMode}\n'
      'currentUser.uid=${FirebaseAuth.instance.currentUser?.uid ?? ''}\n'
      'errorType=${raw?.runtimeType}\n'
      'errorCode=$code\n'
      'message=$message\n'
      '${stackTrace ?? ''}',
    );
  }

  String _loadErrorMessage(Object? error) {
    if (error is FirebaseException) {
      if (error.code == 'permission-denied') {
        return '你沒有權限查看這筆照護紀錄';
      }
      if (error.code == 'not-found') {
        return '找不到這筆住宿資料';
      }
    }
    return '讀取每日照護紀錄失敗';
  }

  Widget _errorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.error_outline_rounded,
              size: 50,
              color: Colors.red.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCareView extends StatelessWidget {
  const _EmptyCareView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.pets_outlined, size: 54, color: Colors.grey.shade400),
            const SizedBox(height: 14),
            const Text(
              '目前還沒有照護紀錄',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              '店家完成每日照護後，紀錄會顯示在這裡。',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
    );
  }
}
