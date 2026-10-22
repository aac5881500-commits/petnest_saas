import 'dart:async';
import 'package:petnest_saas/features/shop/widgets/shop_setup_spotlight.dart';
import 'package:petnest_saas/core/constants/shop_booking_settings_features.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_page.dart';
import 'package:petnest_saas/features/shop/widgets/shop_setup_leave_guard.dart';
import 'package:petnest_saas/core/services/stay_booking_readiness.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_setup_center_page.dart';
// 檔案名稱：lib/features/shop/pages/shop_booking_settings_page.dart
// 功能說明：預約管理頁（店家後台）
// 功能：
// - 預約設定區
// - 共用月曆顯示
// - 點日期可關閉 / 開放

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:petnest_saas/core/models/daycare_settings_model.dart';
import 'package:petnest_saas/core/services/action_log_service.dart';
import 'package:petnest_saas/core/services/daycare_settings_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/shared/widgets/booking_calendar.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/services/shop_plan_service.dart';
import 'package:petnest_saas/core/services/operator_display.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/core/navigation/shop_operations_workbench.dart';
import 'package:petnest_saas/features/shop/widgets/unsaved_booking_settings_dialog.dart';

class ShopBookingSettingsLeaveGuard extends ShopSetupLeaveGuard {}

enum _StayOpeningStep {
  waiting,
  switchFocus,
  dateExplanation,
  freeSettings,
  complete,
}

class ShopBookingSettingsPage extends StatefulWidget {
  const ShopBookingSettingsPage({
    super.key,
    required this.shopId,
    this.embeddedInSetupCenter = false,
    this.leaveGuard,
    this.onManageRooms,
    this.loadMember,
    this.shopStream,
    this.readinessStream,
    this.actionLogsStream,
    this.onReturnToOpening,
    this.loadStayPolicy,
    this.daycareSettingsStream,
    this.guideStayOpening = false,
    this.isActive = true,
    this.onTutorialLockChanged,
    this.loadRoomReadiness,
  });
  final bool guideStayOpening, isActive;
  final ValueChanged<bool>? onTutorialLockChanged;
  final Future<StayBookingReadiness> Function()? loadRoomReadiness;

  final Future<void> Function()? onManageRooms;
  final Future<void> Function()? onReturnToOpening;
  final Future<bool> Function()? loadStayPolicy;
  final Stream<DaycareSettingsModel>? daycareSettingsStream;
  final Future<Map<String, dynamic>?> Function()? loadMember;
  final Stream<Map<String, dynamic>?>? shopStream;
  final Stream<StayBookingReadiness>? readinessStream;
  final Stream<List<Map<String, dynamic>>>? actionLogsStream;
  final String shopId;
  final bool embeddedInSetupCenter;
  final ShopBookingSettingsLeaveGuard? leaveGuard;

  @override
  State<ShopBookingSettingsPage> createState() =>
      _ShopBookingSettingsPageState();
}

class _ShopBookingSettingsPageState extends State<ShopBookingSettingsPage> {
  _StayOpeningStep _openingStep = _StayOpeningStep.waiting;
  final _staySwitchKey = GlobalKey();
  final _dateHelpKey = GlobalKey();
  final _staySwitchFocus = FocusNode();
  final _dateReadFocus = FocusNode();
  bool _tutorialCheckScheduled = false;
  double _tutorialHeight = 600;
  late final String _tutorialShop = widget.shopId;
  late final String? _tutorialUser = FirebaseAuth.instance.currentUser?.uid;
  bool get _tutorialCurrent =>
      mounted &&
      widget.isActive &&
      widget.shopId == _tutorialShop &&
      FirebaseAuth.instance.currentUser?.uid == _tutorialUser &&
      (ModalRoute.of(context)?.isCurrent ?? true);
  bool get _tutorialLocked =>
      widget.guideStayOpening &&
      widget.isActive &&
      (_openingStep == _StayOpeningStep.switchFocus ||
          _openingStep == _StayOpeningStep.dateExplanation);
  bool get _dateAcknowledged =>
      _openingStep == _StayOpeningStep.freeSettings ||
      _openingStep == _StayOpeningStep.complete;

  void _scheduleTutorial() {
    if (!widget.guideStayOpening || _tutorialCheckScheduled) return;
    _tutorialCheckScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tutorialCheckScheduled = false;
      if (!_tutorialCurrent ||
          !_settingsInitialized ||
          _checkingStay ||
          _dateAcknowledged) {
        return;
      }
      if (_persistedBookingEnabled && !_dirty) {
        _enterOpeningStep(_StayOpeningStep.complete);
        return;
      }
      final ready =
          ShopService.instance.hasPermission(
            _memberData,
            ShopPermissionKeys.manageBookingSettings,
          ) &&
          _readinessSnapshot.data?.ready == true &&
          !_readinessSnapshot.hasError &&
          _policyState.data == true &&
          !_policyState.hasError;
      if (!ready) {
        if (_tutorialLocked) _enterOpeningStep(_StayOpeningStep.waiting);
      } else if (_openingStep == _StayOpeningStep.waiting) {
        _enterOpeningStep(
          _bookingEnabled
              ? _StayOpeningStep.dateExplanation
              : _StayOpeningStep.switchFocus,
        );
      }
    });
  }

  void _enterOpeningStep(_StayOpeningStep step) {
    if (!mounted) return;
    setState(() {
      _openingStep = step;
      if (step == _StayOpeningStep.switchFocus ||
          step == _StayOpeningStep.waiting) {
        _datePanel = false;
      }
      if (step == _StayOpeningStep.dateExplanation) _datePanel = true;
    });
    widget.onTutorialLockChanged?.call(_tutorialLocked);
    if (_tutorialLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!_tutorialCurrent || _openingStep != step) return;
        final target =
            (step == _StayOpeningStep.switchFocus
                    ? _staySwitchKey
                    : _dateHelpKey)
                .currentContext;
        if (target == null) return;
        await Scrollable.ensureVisible(target, alignment: 0.1);
        if (!_tutorialCurrent || _openingStep != step) return;
        (step == _StayOpeningStep.switchFocus
                ? _staySwitchFocus
                : _dateReadFocus)
            .requestFocus();
      });
    }
  }

  Widget _backgroundControl(Widget child) =>
      ExcludeFocus(excluding: _tutorialLocked, child: child);

  @override
  void didUpdateWidget(covariant ShopBookingSettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.leaveGuard != widget.leaveGuard) {
      oldWidget.leaveGuard?.unbind();
      widget.leaveGuard?.bind(_handleLeave);
    }
    if (oldWidget.isActive != widget.isActive) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        widget.onTutorialLockChanged?.call(_tutorialLocked);
        _scheduleTutorial();
      });
    }
  }

  final _maxAdvanceBookingDaysController = TextEditingController();

  bool _bookingEnabled = false;
  bool _datePanel = false;
  bool _showingOpened = false;
  bool _confirmingFormal = false;
  String? _formalError;
  final ScrollController _pageScroll = ScrollController();
  final GlobalKey _calendarKey = GlobalKey();
  late final StreamSubscription<DaycareSettingsModel> _daycareSubscription;
  AsyncSnapshot<DaycareSettingsModel> _daycareSnapshot =
      const AsyncSnapshot.waiting();
  Map<String, dynamic> _latestShop = {};
  bool get _daycareEditing => ShopBookingSettingsFeatures.daycareEditingEnabled;
  bool get _daycareKnown {
    final flag = _latestShop['daycareEnabled'];
    return (flag != null && flag.toString().trim().isNotEmpty) ||
        _daycareSnapshot.hasData;
  }

  bool get _currentDaycare => DaycareSettingsService.instance.isEnabledForShop(
    shop: _latestShop,
    settings: _daycareSnapshot.data,
  );
  AsyncSnapshot<bool> _policyState = const AsyncSnapshot.waiting();
  bool _checkingStay = false;
  bool _openingPolicy = false;
  int _policyRequest = 0;

  Future<void> _refreshPolicy() async {
    final request = ++_policyRequest;
    setState(() => _policyState = const AsyncSnapshot.waiting());
    try {
      final ready =
          await (widget.loadStayPolicy?.call() ??
              ShopPolicyService.instance.hasEffectiveStayPolicy(widget.shopId));
      if (mounted && request == _policyRequest) {
        setState(
          () => _policyState = AsyncSnapshot.withData(
            ConnectionState.done,
            ready,
          ),
        );
      }
    } catch (e, stack) {
      if (mounted && request == _policyRequest) {
        setState(
          () => _policyState = AsyncSnapshot.withError(
            ConnectionState.done,
            e,
            stack,
          ),
        );
      }
    }
  }

  Future<void> _openPolicy() async {
    if (_openingPolicy ||
        !ShopService.instance.hasPermission(
          _memberData,
          ShopPermissionKeys.managePolicy,
        )) {
      return;
    }
    _openingPolicy = true;
    try {
      // Keep this editor mounted so dates, service switches and days remain drafts.
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ShopPolicyPage(shopId: widget.shopId),
        ),
      );
    } finally {
      _openingPolicy = false;
      if (mounted) await _refreshPolicy();
    }
  }

  Widget _policyStatus() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _policyState.hasError
            ? '已發布住宿入住條款：讀取失敗或權限不足'
            : !_policyState.hasData
            ? '已發布住宿入住條款：資格確認中…'
            : _policyState.data == true
            ? '已發布住宿入住條款：已完成'
            : '已發布住宿入住條款：尚未完成',
      ),
      if (_policyState.hasError)
        TextButton(onPressed: _refreshPolicy, child: const Text('重試條款確認')),
      if (_policyState.hasData && _policyState.data != true)
        if (ShopService.instance.hasPermission(
          _memberData,
          ShopPermissionKeys.managePolicy,
        ))
          TextButton(onPressed: _openPolicy, child: const Text('前往條款設定'))
        else
          const Text('請由店主或有條款管理權限的人完成設定。'),
    ],
  );
  bool _daycareEnabled = false;
  bool _settingsInitialized = false;
  bool _savingSettings = false;
  late final Stream<StayBookingReadiness> _readinessStream;
  late final Stream<Map<String, dynamic>?> _shopStream;
  late final Stream<List<Map<String, dynamic>>> _logsStream;
  late final StreamSubscription<StayBookingReadiness> _readinessSubscription;
  late final StreamSubscription<List<Map<String, dynamic>>> _logsSubscription;
  AsyncSnapshot<StayBookingReadiness> _readinessSnapshot =
      const AsyncSnapshot.waiting();
  AsyncSnapshot<List<Map<String, dynamic>>> _logsSnapshot =
      const AsyncSnapshot.waiting();
  Set<String> _draftBlockedDates = <String>{};
  Set<String> _savedBlockedDates = <String>{};
  bool _savedBookingEnabled = false;
  bool _persistedBookingEnabled = false;
  bool _savedDaycareEnabled = false;
  String _savedMaxAdvanceDays = '30';

  String? _currentUserRole;
  bool _roleLoaded = false;
  Map<String, dynamic>? _memberData;

  DateTime? _selectedCalendarDate;
  bool _showAllLogs = false;
  bool _exitingPage = false;
  bool _openingRooms = false;
  bool _confirmingLeave = false;

  @override
  void initState() {
    super.initState();
    _refreshPolicy();
    _readinessStream =
        widget.readinessStream ?? StayBookingReadiness.watch(widget.shopId);
    _shopStream =
        widget.shopStream ??
        FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .snapshots(includeMetadataChanges: true)
            .where((snapshot) => !snapshot.metadata.hasPendingWrites)
            .map((snapshot) => snapshot.data());
    _daycareSubscription =
        (widget.daycareSettingsStream ??
                DaycareSettingsService.instance.stream(widget.shopId))
            .listen(
              (settings) {
                if (mounted) {
                  setState(
                    () => _daycareSnapshot = AsyncSnapshot.withData(
                      ConnectionState.active,
                      settings,
                    ),
                  );
                }
              },
              onError: (Object error, StackTrace stack) {
                if (mounted) {
                  setState(
                    () => _daycareSnapshot = AsyncSnapshot.withError(
                      ConnectionState.active,
                      error,
                      stack,
                    ),
                  );
                }
              },
            );
    _logsStream =
        widget.actionLogsStream ??
        ActionLogService.instance.streamShopLogs(widget.shopId);
    _readinessSubscription = _readinessStream.listen(
      (state) {
        if (mounted) {
          setState(
            () => _readinessSnapshot = AsyncSnapshot.withData(
              ConnectionState.active,
              state,
            ),
          );
        }
      },
      onError: (Object error, StackTrace stack) {
        if (mounted) {
          setState(
            () => _readinessSnapshot = AsyncSnapshot.withError(
              ConnectionState.active,
              error,
              stack,
            ),
          );
        }
      },
    );
    _logsSubscription = _logsStream.listen(
      (logs) {
        if (mounted) {
          setState(
            () => _logsSnapshot = AsyncSnapshot.withData(
              ConnectionState.active,
              logs,
            ),
          );
        }
      },
      onError: (Object error, StackTrace stack) {
        if (mounted) {
          setState(
            () => _logsSnapshot = AsyncSnapshot.withError(
              ConnectionState.active,
              error,
              stack,
            ),
          );
        }
      },
    );
    widget.leaveGuard?.bind(_handleLeave);
    _loadRole();
  }

  @override
  void dispose() {
    _readinessSubscription.cancel();
    _daycareSubscription.cancel();
    _staySwitchFocus.dispose();
    _dateReadFocus.dispose();
    _pageScroll.dispose();
    _logsSubscription.cancel();
    widget.leaveGuard?.unbind();
    _maxAdvanceBookingDaysController.dispose();
    super.dispose();
  }

  bool get _stayConfigurationReady =>
      _readinessSnapshot.hasData &&
      !_readinessSnapshot.hasError &&
      _readinessSnapshot.data!.ready;

  bool get _dirty {
    if (!_settingsInitialized) {
      return false;
    }
    final String days = _maxAdvanceBookingDaysController.text.trim();
    return _bookingEnabled != _savedBookingEnabled ||
        (_daycareEditing && _daycareEnabled != _savedDaycareEnabled) ||
        days != _savedMaxAdvanceDays ||
        !_sameSet(_draftBlockedDates, _savedBlockedDates);
  }

  bool _sameSet(Set<String> a, Set<String> b) {
    if (a.length != b.length) {
      return false;
    }
    return a.containsAll(b);
  }

  Future<bool> _handleLeave() async {
    if (_confirmingLeave) return false;
    _confirmingLeave = true;
    try {
      return await _confirmLeaveDraft();
    } finally {
      _confirmingLeave = false;
    }
  }

  Future<bool> _confirmLeaveDraft() async {
    if (_savingSettings) return false;
    if (!_dirty) {
      return true;
    }
    final UnsavedBookingSettingsAction? action =
        await showUnsavedBookingSettingsDialog(context);
    if (!mounted) return false;
    if (action == UnsavedBookingSettingsAction.discard) {
      setState(() {
        _bookingEnabled = _savedBookingEnabled;
        _daycareEnabled = _savedDaycareEnabled;
        _maxAdvanceBookingDaysController.text = _savedMaxAdvanceDays;
        _draftBlockedDates = Set<String>.from(_savedBlockedDates);
      });
      return true;
    }
    if (action == UnsavedBookingSettingsAction.saveAndLeave) {
      return _saveSettings(showOpeningConfirmation: false);
    }
    return false;
  }

  Future<void> _loadRole() async {
    if (widget.loadMember != null) {
      try {
        final member = await widget.loadMember!();
        if (!mounted) return;
        setState(() {
          _memberData = member;
          _currentUserRole = member?['role']?.toString();
          _roleLoaded = true;
        });
      } catch (_) {
        if (mounted) setState(() => _roleLoaded = true);
      }
      return;
    }
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      if (!mounted) return;
      setState(() {
        _currentUserRole = null;
        _roleLoaded = true;
      });
      return;
    }

    try {
      final memberData = await ShopService.instance.getUserMemberInShop(
        shopId: widget.shopId,
        uid: user.uid,
      );

      final role = memberData?['role']?.toString();

      if (!mounted) return;
      setState(() {
        _currentUserRole = role;
        _memberData = memberData;
        _roleLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _currentUserRole = null;
        _roleLoaded = true;
      });
    }
  }

  Future<void> _manageRooms() async {
    if (_openingRooms) return;
    _openingRooms = true;
    try {
      if (widget.onManageRooms != null) {
        await widget.onManageRooms!();
      } else if (await _handleLeave() && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ShopBookingSetupCenterPage(shopId: widget.shopId),
          ),
        );
      }
    } finally {
      _openingRooms = false;
    }
  }

  Widget _wrapPage(Widget body) {
    if (widget.embeddedInSetupCenter) {
      return body;
    }
    return PopScope(
      canPop: !_dirty && !_savingSettings,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) {
          return;
        }
        await _exitPage();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('預約管理'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _exitPage,
          ),
          actions: <Widget>[ShopTaskCenterButton(shopId: widget.shopId)],
        ),
        body: body,
      ),
    );
  }

  Future<void> _exitPage() async {
    if (_exitingPage) return;
    _exitingPage = true;
    try {
      if (await _handleLeave() && mounted) Navigator.of(context).pop();
    } finally {
      _exitingPage = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_roleLoaded) {
      return _wrapPage(const Center(child: CircularProgressIndicator()));
    }

    if (_currentUserRole == null) {
      return _wrapPage(const Center(child: Text('查無店家權限')));
    }

    final canManageBookings = ShopService.instance.hasPermission(
      _memberData,
      ShopPermissionKeys.manageBookingSettings,
    );

    if (!canManageBookings) {
      if (widget.embeddedInSetupCenter) {
        return const Center(child: Text('你沒有管理權限'));
      }
      return Scaffold(
        appBar: AppBar(
          title: const Text('權限限制'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              if (Navigator.canPop(context)) {
                Navigator.pop(context);
              } else {
                Navigator.pushReplacementNamed(context, '/home');
              }
            },
          ),
        ),
        body: const Center(child: Text('你沒有管理權限')),
      );
    }
    return _wrapPage(
      StreamBuilder<Map<String, dynamic>?>(
        stream: _shopStream,
        builder: (context, shopSnapshot) {
          if (shopSnapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (shopSnapshot.hasError) {
            return Center(child: Text('店家資料載入失敗：${shopSnapshot.error}'));
          }

          final shop = shopSnapshot.data;
          if (shop == null) {
            return const Center(child: Text('找不到店家資料'));
          }

          _latestShop = shop;
          if (!_savingSettings) {
            _persistedBookingEnabled = StayBookingReadiness.requested(shop);
          }
          if (!_daycareEditing) _daycareEnabled = _currentDaycare;
          // The room tab may close accommodation while this page stays mounted.
          // Adopt that change only when there is no draft to preserve.
          if (_settingsInitialized && !_dirty) {
            _bookingEnabled = _persistedBookingEnabled;
            _savedBookingEnabled = _persistedBookingEnabled;
          }
          if (!_settingsInitialized) {
            _initSettingsIfNeeded(shop);
          }

          _scheduleTutorial();
          final today = _dateOnly(DateTime.now());
          final savedMaxAdvanceBookingDays = _toInt(
            shop['maxAdvanceBookingDays'],
            fallback: 30,
          );

          final planLimit = ShopPlanService.bookingOpenDaysLimit(shop);
          final draftDays = _toInt(
            _maxAdvanceBookingDaysController.text,
            fallback: savedMaxAdvanceBookingDays,
          );
          final maxAdvanceBookingDays = draftDays > planLimit
              ? planLimit
              : (draftDays <= 0 ? savedMaxAdvanceBookingDays : draftDays);

          final lastDate = today.add(Duration(days: maxAdvanceBookingDays));
          final _CalendarPayload payload = _CalendarPayload(
            blockedDateKeys: Set<String>.from(_draftBlockedDates),
            unbookableDateKeys: <String>{},
            remainingRoomsMap: const <String, int>{},
            occupiedRoomsMap: const <String, int>{},
          );

          return LayoutBuilder(
            builder: (context, bounds) {
              _tutorialHeight = bounds.maxHeight;
              return ShopSetupSpotlight(
                target: _tutorialCurrent && _tutorialLocked
                    ? (_openingStep == _StayOpeningStep.switchFocus
                          ? _staySwitchKey
                          : _dateHelpKey)
                    : null,
                strictFocus: true,
                title: _openingStep == _StayOpeningStep.switchFocus
                    ? '先開啟住宿預約'
                    : '設定全店可預約日期',
                description: _openingStep == _StayOpeningStep.switchFocus
                    ? '請點選開關，接著帶你確認可接受住宿預約的日期。所有變更都會在儲存後生效。'
                    : '請閱讀下方說明，再點「我了解，開始設定」。',
                progressLabel: _openingStep == _StayOpeningStep.switchFocus
                    ? '住宿開放引導 1／3'
                    : '住宿開放引導 2／3',
                pauseLabel: '返回／離開',
                onPause: () {
                  if (widget.onReturnToOpening != null) {
                    widget.onReturnToOpening!();
                  } else {
                    _exitPage();
                  }
                },
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                      child: SegmentedButton<bool>(
                        showSelectedIcon: false,
                        segments: const [
                          ButtonSegment(value: false, label: Text('預約開放')),
                          ButtonSegment(value: true, label: Text('日期管理')),
                        ],
                        selected: {_datePanel},
                        onSelectionChanged: _tutorialLocked
                            ? null
                            : (value) {
                                setState(() => _datePanel = value.first);
                                if (_pageScroll.hasClients) {
                                  _pageScroll.jumpTo(0);
                                }
                              },
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _pageScroll,
                        padding: const EdgeInsets.all(16),
                        child: Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1440),
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final compact = constraints.maxWidth < 720;
                                return Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Offstage(
                                      offstage: _datePanel,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          _buildBookingSettingsCard(
                                            planLimit: planLimit,
                                            compact: compact,
                                          ),
                                          const SizedBox(height: 12),
                                          _backgroundControl(_daycareCard()),
                                        ],
                                      ),
                                    ),
                                    Offstage(
                                      offstage: !_datePanel,
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.stretch,
                                        children: [
                                          const Text(
                                            '選取日期後，可設定是否接受新的住宿預約；儲存後生效。',
                                          ),
                                          _buildDateHelpCard(
                                            initiallyExpanded: false,
                                          ),
                                          const SizedBox(height: 12),
                                          if (constraints.maxWidth >= 1000)
                                            Row(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    children: [
                                                      _buildCalendarSection(
                                                        firstDate: today,
                                                        lastDate: lastDate,
                                                        payload: payload,
                                                        compact: false,
                                                      ),
                                                      const SizedBox(
                                                        height: 12,
                                                      ),
                                                      _buildDateLegend(),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                SizedBox(
                                                  width: 320,
                                                  child:
                                                      _buildSelectedDateActions(),
                                                ),
                                              ],
                                            )
                                          else ...[
                                            _buildCalendarSection(
                                              firstDate: today,
                                              lastDate: lastDate,
                                              payload: payload,
                                              compact: compact,
                                            ),
                                            const SizedBox(height: 12),
                                            _buildDateLegend(),
                                            const SizedBox(height: 12),
                                            _buildSelectedDateActions(),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    _backgroundControl(
                                      ExpansionTile(
                                        key: const PageStorageKey(
                                          'bookingLogsCollapsed',
                                        ),
                                        title: const Text('操作紀錄'),
                                        children: [
                                          _buildBookingActionLogs(
                                            compact: compact,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                    _backgroundControl(_saveBar()),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBookingSettingsCard({
    required int planLimit,
    required bool compact,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '住宿預約',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Chip(
            label: Text(
              _formalError != null
                  ? '正式狀態待確認'
                  : _persistedBookingEnabled
                  ? '已開放'
                  : '尚未開放',
            ),
          ),
          if (_formalError != null) Text(_formalError!),
          if (_formalError != null)
            TextButton(
              onPressed: _confirmingFormal ? null : _refreshFormal,
              child: const Text('重新確認正式狀態'),
            ),
          const SizedBox(height: 12),
          _backgroundControl(_roomCondition()),
          _backgroundControl(_policyStatus()),
          const Divider(height: 24),
          _buildSwitchRow(
            title: '開放住宿預約',
            subtitle: '開啟並儲存後，顧客可依可預約日期與房間供應情況提出住宿預約。',
            value: _bookingEnabled,
            onChanged: _savingSettings || _checkingStay ? null : _toggleStay,
          ),
          if (_checkingStay) const Text('正在確認開放資格…'),
          const SizedBox(height: 16),
          const Text(
            '顧客可提前幾天預約',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: TextFormField(
              controller: _maxAdvanceBookingDaysController,
              canRequestFocus: !_tutorialLocked,
              readOnly: _savingSettings || _tutorialLocked,
              keyboardType: TextInputType.number,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '請輸入天數',
                suffixText: '天',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text('目前方案最多可設定 $planLimit 天'),
        ],
      ),
    ),
  );

  Future<void> _toggleStay(bool value) async {
    if (_checkingStay || _savingSettings || !_tutorialCurrent) return;
    if (!value) {
      setState(() => _bookingEnabled = false);
      return;
    }
    setState(() => _checkingStay = true);
    try {
      final ready =
          await (widget.loadRoomReadiness?.call() ??
              StayBookingReadiness.load(widget.shopId));
      if (!_tutorialCurrent) return;
      setState(
        () => _readinessSnapshot = AsyncSnapshot.withData(
          ConnectionState.done,
          ready,
        ),
      );
      if (!ready.ready) throw StateError(ready.reason);
      await _refreshPolicy();
      if (!_tutorialCurrent) return;
      if (_policyState.hasError) throw StateError('住宿條款讀取失敗或權限不足，請重試');
      if (_policyState.data != true) throw StateError('請先設定並發布入住條款，才能開放住宿預約。');
      setState(() => _bookingEnabled = true);
      if (widget.guideStayOpening && !_dateAcknowledged) {
        _enterOpeningStep(_StayOpeningStep.dateExplanation);
      }
    } catch (e) {
      if (mounted) _showSnackBar('無法確認住宿預約條件：$e');
    } finally {
      if (mounted) setState(() => _checkingStay = false);
    }
  }

  Future<void> _retryRooms() async {
    setState(() => _readinessSnapshot = const AsyncSnapshot.waiting());
    try {
      final ready = await StayBookingReadiness.load(widget.shopId);
      if (mounted) {
        setState(
          () => _readinessSnapshot = AsyncSnapshot.withData(
            ConnectionState.done,
            ready,
          ),
        );
      }
    } catch (e, stack) {
      if (mounted) {
        setState(
          () => _readinessSnapshot = AsyncSnapshot.withError(
            ConnectionState.done,
            e,
            stack,
          ),
        );
      }
    }
  }

  Widget _roomCondition() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        _readinessSnapshot.hasError
            ? '可用房型與實際房間：讀取失敗'
            : !_readinessSnapshot.hasData
            ? '可用房型與實際房間：資格確認中…'
            : _stayConfigurationReady
            ? '可用房型與實際房間：已完成'
            : '可用房型與實際房間：尚未完成',
      ),
      if (_readinessSnapshot.hasError)
        TextButton(onPressed: _retryRooms, child: const Text('重試房間確認')),
      if (_readinessSnapshot.hasData && !_stayConfigurationReady) ...[
        Text(_readinessSnapshot.data!.reason),
        if (ShopService.instance.hasPermission(
              _memberData,
              ShopPermissionKeys.manageRooms,
            ) ||
            ShopService.instance.hasPermission(
              _memberData,
              ShopPermissionKeys.manageRoomTypes,
            ))
          TextButton(
            onPressed: _manageRooms,
            child: Text(_readinessSnapshot.data!.action),
          ),
      ],
    ],
  );

  Widget _daycareCard() => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_daycareEditing ? Icons.pets_outlined : Icons.lock_outline),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  '安親服務',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              if (_daycareKnown)
                Switch(
                  value: _daycareEditing ? _daycareEnabled : _currentDaycare,
                  onChanged: _daycareEditing && !_savingSettings
                      ? (value) => setState(() => _daycareEnabled = value)
                      : null,
                ),
            ],
          ),
          Text(
            !_daycareKnown
                ? (_daycareSnapshot.hasError
                      ? '安親狀態讀取失敗，本頁暫不提供調整'
                      : '正在確認安親狀態…')
                : _daycareEditing
                ? '可調整安親服務（儲存後生效）'
                : _currentDaycare
                ? '目前已啟用，本頁暫不提供調整'
                : '暫未開放設定',
          ),
          if (!_daycareEditing && !_currentDaycare)
            const Text('目前先完成住宿開店流程，安親服務將於後續開放設定。'),
        ],
      ),
    ),
  );

  Widget _saveBar() => Material(
    elevation: 3,
    child: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                _savingSettings
                    ? '正在儲存…'
                    : _dirty
                    ? '尚未儲存'
                    : '目前沒有未儲存變更',
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: FilledButton(
                onPressed:
                    _dirty &&
                        !_savingSettings &&
                        !_checkingStay &&
                        !_tutorialLocked
                    ? () => _saveSettings()
                    : null,
                child: _savingSettings
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('儲存預約設定'),
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _buildSwitchRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 44),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            key: _staySwitchKey,
            focusNode: _staySwitchFocus,
            value: value,
            onChanged:
                _openingStep == _StayOpeningStep.dateExplanation &&
                    _tutorialLocked
                ? null
                : onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDateHelpCard({required bool initiallyExpanded}) => ExcludeFocus(
    excluding: !_datePanel,
    child: _dateHelpContent(initiallyExpanded: initiallyExpanded),
  );

  Widget _dateHelpContent({required bool initiallyExpanded}) {
    final reading =
        _tutorialLocked && _openingStep == _StayOpeningStep.dateExplanation;
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _helpLine('這裡控制全店的住宿預約日期。'),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.event_busy),
          title: Text('全店停止接受新的住宿預約'),
        ),
        _helpLine('選取日期並設為關閉、儲存後，顧客就無法選擇該日期提出新的住宿預約。適合用在店休、包場或全店暫停接待。'),
        _helpLine('這裡關閉的是顧客要預約的住宿日期，不是禁止顧客在當天預約其他開放日期。'),
        _helpLine('顧客選取的住宿區間會檢查關閉日期，部分選取流程也會檢查退房日期；實際可選範圍依預約頁顯示。'),
        const ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(Icons.meeting_room_outlined),
          title: Text('單間房間請至房務管理'),
        ),
        _helpLine('如果只有某一間房間需要維修、清潔或暫停使用，請到「房務管理」設定該房間，其他房間仍可依供應情況接受預約。'),
        _helpLine('關閉日期不會自動取消或更動既有訂單，已成立的訂單仍需另外處理。'),
        _helpLine('重新開放日期後，仍須符合住宿預約開關、可預約天數及房間供應等條件，並不代表一定有空房。'),
        _helpLine('所有變更都要按下「儲存預約設定」才會生效。'),
        if (reading)
          FilledButton(
            onPressed: () {
              _enterOpeningStep(_StayOpeningStep.freeSettings);
              ScaffoldMessenger.of(context).clearSnackBars();
              _showSnackBar('沒有需要關閉的日期，可直接儲存預約設定');
            },
            child: const Text('我了解，開始設定'),
          ),
        if (!reading)
          TextButton(
            onPressed: () => Navigator.of(
              context,
            ).push(shopOperationsWorkbenchRoute(widget.shopId)),
            child: const Text('前往房務管理'),
          ),
      ],
    );
    return Card(
      key: _dateHelpKey,
      child: reading
          ? SizedBox(
              height: (_tutorialHeight * 0.45).clamp(100.0, 500.0),
              child: SingleChildScrollView(
                child: Focus(
                  focusNode: _dateReadFocus,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          '設定全店可預約日期',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        content,
                      ],
                    ),
                  ),
                ),
              ),
            )
          : ExpansionTile(
              key: const PageStorageKey<String>('shopBookingDateHelp'),
              initiallyExpanded: initiallyExpanded,
              leading: const Icon(Icons.info_outline),
              title: const Text('設定全店可預約日期'),
              childrenPadding: const EdgeInsets.all(16),
              children: [content],
            ),
    );
  }

  Widget _helpLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          height: 1.5,
          color: Color(0xFF424242),
        ),
      ),
    );
  }

  Widget _buildDateLegend() => Wrap(
    spacing: 16,
    runSpacing: 10,
    children: [
      _legendItem(Colors.white, Colors.grey.shade300, '可預約'),
      _legendItem(Colors.grey.shade200, Colors.red.shade200, '已關閉'),
      _legendItem(Colors.blue, Colors.blue.shade900, '已選取'),
      _legendItem(Colors.grey.shade100, Colors.grey.shade300, '不可選／超出範圍'),
    ],
  );

  Widget _legendItem(Color fill, Color border, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: border),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildCalendarSection({
    required DateTime firstDate,
    required DateTime lastDate,
    required _CalendarPayload? payload,
    required bool compact,
  }) => _backgroundControl(
    _calendarContent(
      firstDate: firstDate,
      lastDate: lastDate,
      payload: payload,
      compact: compact,
    ),
  );

  Widget _calendarContent({
    required DateTime firstDate,
    required DateTime lastDate,
    required _CalendarPayload? payload,
    required bool compact,
  }) {
    final loading = payload == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          '日期管理月曆',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (loading)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
          )
        else
          BookingCalendar(
            key: _calendarKey,
            initialMonth: _selectedCalendarDate ?? firstDate,
            firstDate: firstDate,
            lastDate: lastDate,
            allowBlockedTap: true,
            compactCells: compact,
            rangeStart: _selectedCalendarDate,
            rangeEnd: _selectedCalendarDate,
            blockedDateKeys: payload.blockedDateKeys,
            unbookableDateKeys: payload.unbookableDateKeys,
            onDayTap: (DateTime date) {
              if (_savingSettings || _tutorialLocked) return;
              final DateTime selected = _dateOnly(date);
              _toggleDraftBlockedDate(date: selected);
              setState(() {
                _selectedCalendarDate = selected;
              });
            },
          ),
      ],
    );
  }

  Widget _buildSelectedDateActions() =>
      _backgroundControl(_selectedDateActionsContent());

  Widget _selectedDateActionsContent() {
    final DateTime? selected = _selectedCalendarDate;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: selected == null
            ? const Text('請選擇要管理的日期')
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    DateFormat('yyyy年M月d日').format(selected),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text('目前草稿狀態：${_draftStatusLabel(selected)}'),
                  if (_dirty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        '尚未儲存',
                        style: TextStyle(
                          color: Colors.orange.shade800,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    children: <Widget>[
                      if (!_isDraftBlocked(selected))
                        FilledButton(
                          onPressed: _savingSettings
                              ? null
                              : () => _setDraftBlocked(selected, true),
                          child: const Text('關閉此日預約'),
                        )
                      else
                        FilledButton.tonal(
                          onPressed: _savingSettings
                              ? null
                              : () => _setDraftBlocked(selected, false),
                          child: const Text('重新開放此日'),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }

  bool _isDraftBlocked(DateTime date) {
    return _draftBlockedDates.contains(
      ShopService.instance.formatDateKey(date),
    );
  }

  String _draftStatusLabel(DateTime date) {
    final String key = ShopService.instance.formatDateKey(date);
    final bool inDraft = _draftBlockedDates.contains(key);
    final bool inSaved = _savedBlockedDates.contains(key);
    if (inDraft && !inSaved) {
      return '將關閉';
    }
    if (!inDraft && inSaved) {
      return '將重新開放';
    }
    if (inDraft) {
      return '已關閉';
    }
    return '可預約';
  }

  void _setDraftBlocked(DateTime date, bool blocked) {
    final String dateKey = ShopService.instance.formatDateKey(date);
    setState(() {
      if (blocked) {
        _draftBlockedDates.add(dateKey);
      } else {
        _draftBlockedDates.remove(dateKey);
      }
    });
  }

  Widget _buildBookingActionLogs({required bool compact}) {
    return Builder(
      builder: (context) {
        final snapshot = _logsSnapshot;
        final logs = (snapshot.data ?? [])
            .where((log) {
              final action = log['action']?.toString() ?? '';

              return [
                'update_booking_settings',
                'block_date',
                'unblock_date',
              ].contains(action);
            })
            .take(20)
            .toList();

        final bool canExpand = compact && logs.length > 5;
        final List<Map<String, dynamic>> visible = canExpand && !_showAllLogs
            ? logs.take(5).toList()
            : logs;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '預約管理操作紀錄',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                if (logs.isEmpty) const Text('目前沒有預約管理操作紀錄'),

                ...visible.map((log) {
                  final action = log['action']?.toString() ?? '';

                  final payload = Map<String, dynamic>.from(
                    log['payload'] ?? {},
                  );

                  final dateKey = payload['dateKey']?.toString() ?? '-';

                  final createdAt = log['createdAt'];

                  String formattedTime = '-';

                  if (createdAt is Timestamp) {
                    formattedTime = DateFormat(
                      'yyyy-MM-dd HH:mm',
                    ).format(createdAt.toDate());
                  }

                  String title = action;

                  String settingDetail = '';

                  if (action == 'update_booking_settings') {
                    title = '更新預約設定';

                    final bookingEnabled = payload['bookingEnabled'] == true;

                    final maxDays = payload['maxAdvanceBookingDays'];

                    settingDetail =
                        '前台預約：${bookingEnabled ? '開啟' : '關閉'}\n'
                        '最遠預約天數：$maxDays 天';
                  } else if (action == 'block_date') {
                    title = '關閉預約日期';
                  } else if (action == 'unblock_date') {
                    title = '恢復預約日期';
                  }

                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.history),
                    title: Text(title),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        if (settingDetail.isNotEmpty) Text(settingDetail),
                        Text('異動日期：$dateKey'),
                        Text('操作時間：$formattedTime'),
                        OperatorActorLabel(
                          shopId: widget.shopId,
                          log: log,
                          prefix: '操作人：',
                          style: const TextStyle(height: 1.4),
                        ),
                      ],
                    ),
                  );
                }),
                if (canExpand)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _showAllLogs = !_showAllLogs;
                      });
                    },
                    child: Text(_showAllLogs ? '收合' : '顯示更多'),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _initSettingsIfNeeded(Map<String, dynamic> shop) {
    if (_settingsInitialized) return;

    _bookingEnabled = StayBookingReadiness.requested(shop);
    _daycareEnabled = _currentDaycare;
    _savedBookingEnabled = _bookingEnabled;
    _savedDaycareEnabled = _daycareEnabled;

    _maxAdvanceBookingDaysController.text = _toInt(
      shop['maxAdvanceBookingDays'],
      fallback: 30,
    ).toString();
    _savedMaxAdvanceDays = _maxAdvanceBookingDaysController.text;

    _draftBlockedDates = List<String>.from(shop['blockedDates'] ?? <dynamic>[])
        .map((dynamic e) => e.toString())
        .where((String e) => e.isNotEmpty)
        .toSet();
    _savedBlockedDates = Set<String>.from(_draftBlockedDates);

    _settingsInitialized = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() {});
    });
    if (_daycareEditing && !shop.containsKey('daycareEnabled')) {
      _loadLegacyDaycareEnabled();
    }
  }

  Future<void> _loadLegacyDaycareEnabled() async {
    try {
      final settings = await DaycareSettingsService.instance.get(widget.shopId);
      if (!mounted || _dirty || _daycareEnabled) {
        return;
      }
      if (settings.enabled) {
        setState(() {
          _daycareEnabled = true;
          _savedDaycareEnabled = true;
        });
      }
    } catch (_) {}
  }

  void _toggleDraftBlockedDate({required DateTime date}) {
    final String dateKey = ShopService.instance.formatDateKey(date);
    setState(() {
      if (_draftBlockedDates.contains(dateKey)) {
        _draftBlockedDates.remove(dateKey);
      } else {
        _draftBlockedDates.add(dateKey);
      }
    });
  }

  Set<String> _blockedKeys(Map<String, dynamic> shop) => List<dynamic>.from(
    shop['blockedDates'] ?? const [],
  ).map((e) => e.toString()).where((e) => e.isNotEmpty).toSet();

  void _adoptConfirmed(Map<String, dynamic> shop) {
    _latestShop = shop;
    _persistedBookingEnabled = StayBookingReadiness.requested(shop);
    _savedBookingEnabled = _persistedBookingEnabled;
    _savedMaxAdvanceDays = _toInt(
      shop['maxAdvanceBookingDays'],
      fallback: 30,
    ).toString();
    _savedBlockedDates = _blockedKeys(shop);
    if (_daycareEditing) {
      _savedDaycareEnabled = DaycareSettingsService.instance.isEnabledForShop(
        shop: shop,
        settings: _daycareSnapshot.data,
      );
    }
    _formalError = null;
  }

  Future<void> _refreshFormal() async {
    if (_confirmingFormal) return;
    setState(() => _confirmingFormal = true);
    try {
      final doc = await FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId)
          .get(const GetOptions(source: Source.server));
      if (!doc.exists) throw StateError('找不到店家資料');
      if (mounted) setState(() => _adoptConfirmed(doc.data()!));
    } catch (_) {
      if (mounted) setState(() => _formalError = '正式狀態讀取失敗，草稿已保留，請重試確認。');
    } finally {
      if (mounted) setState(() => _confirmingFormal = false);
    }
  }

  Future<bool> _saveSettings({bool showOpeningConfirmation = true}) async {
    if (_savingSettings || _checkingStay || _showingOpened) return false;
    if (widget.guideStayOpening &&
        !_dateAcknowledged &&
        (_bookingEnabled || _tutorialLocked)) {
      _showSnackBar('請先完成住宿開關與日期說明；也可以放棄草稿後離開。');
      if (_tutorialLocked) {
        _enterOpeningStep(_openingStep);
      } else {
        _scheduleTutorial();
      }
      return false;
    }
    if (!_dirty) return true;
    setState(() => _savingSettings = true);
    final desiredBooking = _bookingEnabled;
    final desiredDaycare = _daycareEnabled;
    final desiredDaysText = _maxAdvanceBookingDaysController.text.trim();
    final desiredDays = int.tryParse(desiredDaysText) ?? 0;
    final desiredBlocked = Set<String>.from(_draftBlockedDates);
    bool attemptedWrite = false;
    try {
      final ref = FirebaseFirestore.instance
          .collection('shops')
          .doc(widget.shopId);
      final beforeDoc = await ref.get(const GetOptions(source: Source.server));
      if (!mounted) return false;
      final before = beforeDoc.data();
      if (before == null) throw StateError('找不到店家資料');
      final maxLimit = ShopPlanService.bookingOpenDaysLimit(before);
      if (desiredDays > maxLimit) throw StateError('目前方案最多只能設定 $maxLimit 天');
      if (desiredDays <= 0) throw StateError('顧客可提前預約天數至少要 1');
      if (desiredBooking) {
        final readiness = await StayBookingReadiness.load(widget.shopId);
        if (!readiness.ready) throw StateError(readiness.reason);
        await ShopPolicyService.instance.requireEffectiveStayPolicy(
          widget.shopId,
        );
        if (!mounted) return false;
      }
      attemptedWrite = true;
      if (_daycareEditing) {
        await ShopService.instance.updateBookingSettings(
          shopId: widget.shopId,
          bookingEnabled: desiredBooking,
          daycareEnabled: desiredDaycare,
          maxAdvanceBookingDays: desiredDays,
        );
      } else {
        // Locked editor deliberately omits daycareEnabled; concurrent daycare changes survive.
        await ShopService.instance.updateBookingSettings(
          shopId: widget.shopId,
          bookingEnabled: desiredBooking,
          maxAdvanceBookingDays: desiredDays,
        );
      }
      await ShopService.instance.updateBlockedDates(
        shopId: widget.shopId,
        blockedDates: desiredBlocked.toList(),
      );
      if (_daycareEditing) {
        await DaycareSettingsService.instance.syncEnabledFlag(
          shopId: widget.shopId,
          enabled: desiredDaycare,
        );
      }
      final afterDoc = await ref.get(const GetOptions(source: Source.server));
      final after = afterDoc.data();
      if (after == null ||
          StayBookingReadiness.requested(after) != desiredBooking ||
          _toInt(after['maxAdvanceBookingDays'], fallback: 30) != desiredDays ||
          !_sameSet(_blockedKeys(after), desiredBlocked) ||
          (_daycareEditing &&
              DaycareSettingsService.instance.isEnabledForShop(
                    shop: after,
                    settings: _daycareSnapshot.data,
                  ) !=
                  desiredDaycare)) {
        throw StateError('儲存結果與送出內容不一致，可能已有其他管理者更新設定');
      }
      if (!mounted) return false;
      setState(() {
        _adoptConfirmed(after);
        // The integer persisted by the service is the new baseline; no draft reset elsewhere.
        if (_maxAdvanceBookingDaysController.text.trim() == desiredDaysText) {
          _maxAdvanceBookingDaysController.text = desiredDays.toString();
        }
      });
      if (widget.guideStayOpening && _dateAcknowledged && desiredBooking) {
        _enterOpeningStep(_StayOpeningStep.complete);
      }
      String? logWarning;
      try {
        await _recordSavedChanges(
          before,
          desiredBooking,
          desiredDaycare,
          desiredDays,
          desiredBlocked,
        );
      } catch (_) {
        logWarning = '設定已儲存，但部分操作紀錄寫入失敗';
      }
      if (!mounted) return true;
      setState(() => _savingSettings = false);
      final openedNow =
          !StayBookingReadiness.requested(before) && desiredBooking;
      if (logWarning != null) _showSnackBar(logWarning);
      if (openedNow && showOpeningConfirmation) {
        await _showOpenedConfirmation();
      } else {
        _showSnackBar(openedNow ? '住宿預約已開放，顧客可依開放日期與房間供應情況提出住宿預約。' : '預約設定已儲存');
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      if (attemptedWrite) await _refreshFormal();
      if (mounted) {
        _showSnackBar(
          attemptedWrite
              ? '未能完成全部儲存，已重新確認正式狀態；未儲存的草稿保留：$error'
              : '儲存失敗，草稿已保留：$error',
        );
      }
      return false;
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  Future<void> _recordSavedChanges(
    Map<String, dynamic> before,
    bool booking,
    bool daycare,
    int days,
    Set<String> blocked,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _currentUserRole == null) return;
    if (booking != StayBookingReadiness.requested(before) ||
        days != _toInt(before['maxAdvanceBookingDays'], fallback: 30) ||
        (_daycareEditing &&
            daycare !=
                DaycareSettingsService.instance.isEnabledForShop(
                  shop: before,
                  settings: _daycareSnapshot.data,
                ))) {
      await ActionLogService.instance.logAction(
        shopId: widget.shopId,
        targetType: 'shop_booking_settings',
        targetId: widget.shopId,
        action: 'update_booking_settings',
        operatorUid: user.uid,
        operatorRole: _currentUserRole!,
        payload: {
          'bookingEnabled': booking,
          'maxAdvanceBookingDays': days,
          if (_daycareEditing) 'daycareEnabled': daycare,
        },
      );
    }
    final previous = _blockedKeys(before);
    for (final action in ['block_date', 'unblock_date']) {
      final dates = action == 'block_date'
          ? blocked.difference(previous)
          : previous.difference(blocked);
      for (final key in dates) {
        await ActionLogService.instance.logAction(
          shopId: widget.shopId,
          targetType: 'shop_calendar_date',
          targetId: key,
          action: action,
          operatorUid: user.uid,
          operatorRole: _currentUserRole!,
          payload: {'dateKey': key},
        );
      }
    }
  }

  Future<void> _showOpenedConfirmation() async {
    if (_showingOpened ||
        !mounted ||
        ModalRoute.of(context)?.isCurrent != true) {
      return;
    }
    _showingOpened = true;
    try {
      final back = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('住宿預約已開放'),
          content: const Text('顧客現在可以依開放日期與房間供應情況提出住宿預約。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('留在此頁'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('返回開店導覽'),
            ),
          ],
        ),
      );
      if (back == true && mounted) {
        if (widget.onReturnToOpening != null) {
          await widget.onReturnToOpening!();
        } else {
          await _exitPage();
        }
      }
    } finally {
      _showingOpened = false;
    }
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}

class _CalendarPayload {
  const _CalendarPayload({
    required this.blockedDateKeys,
    required this.unbookableDateKeys,
    required this.remainingRoomsMap,
    required this.occupiedRoomsMap,
  });

  final Set<String> blockedDateKeys;
  final Set<String> unbookableDateKeys;
  final Map<String, int> remainingRoomsMap;
  final Map<String, int> occupiedRoomsMap;
}
