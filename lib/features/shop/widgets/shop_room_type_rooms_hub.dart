import 'package:petnest_saas/features/shop/widgets/shop_room_type_workspace.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';
import 'package:petnest_saas/core/services/shop_plan_service.dart';
import 'package:petnest_saas/core/services/shop_room_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_policy_page.dart';
import 'package:petnest_saas/core/services/stay_booking_readiness.dart';
import 'package:petnest_saas/core/constants/shop_roles.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/features/shop/pages/shop_booking_settings_page.dart';
import 'package:petnest_saas/features/shop/shop_admin_welcome.dart';
import 'package:petnest_saas/features/shop/widgets/shop_setup_spotlight.dart';
import 'package:petnest_saas/features/shop/widgets/shop_setup_leave_guard.dart';
import 'package:petnest_saas/features/shop/widgets/room_enabled_action.dart';
// 檔案名稱：lib/features/shop/widgets/shop_room_type_rooms_hub.dart
// 功能說明：房型與房間同一操作畫面：左預覽、右管理，房間內嵌於房型卡片。

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:petnest_saas/core/services/action_log_service.dart';
import 'package:petnest_saas/core/services/daycare_occupancy_service.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/utils/safe_parse.dart';
import 'package:petnest_saas/core/widgets/shop_task_center_button.dart';
import 'package:petnest_saas/features/shop/widgets/room_management_section.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_editor.dart';
import 'package:petnest_saas/features/shop/widgets/shop_room_type_live_preview.dart';

class ShopRoomTypeRoomsHub extends StatefulWidget {
  const ShopRoomTypeRoomsHub({
    super.key,
    required this.shopId,
    this.embeddedInSetupCenter = false,
    this.canManageRoomTypes = true,
    this.canManageRooms = true,
    this.roomTypesStream,
    this.roomsStream,
    this.leaveGuard,
    this.saveDraft,
    this.guideUserId,
    this.onOpenBookingSettings,
    this.isActive = true,
    this.onOpenGuidedBookingSettings,
    this.canManagePolicy,
    this.loadTutorialEligibility,
    this.loadReadiness,
    this.loadStayPolicy,
  });

  final ShopSetupLeaveGuard? leaveGuard;
  final Future<String> Function(ShopRoomTypeDraft)? saveDraft;
  final String? guideUserId;
  final Future<void> Function()? onOpenBookingSettings;
  final bool isActive;
  final Future<void> Function()? onOpenGuidedBookingSettings;
  final bool? canManagePolicy;
  final Future<bool> Function()? loadTutorialEligibility, loadStayPolicy;
  final Future<StayBookingReadiness> Function()? loadReadiness;
  final String shopId;
  final bool embeddedInSetupCenter;
  final bool canManageRoomTypes;
  final bool canManageRooms;
  final Stream<List<Map<String, dynamic>>>? roomTypesStream;
  final Stream<List<Map<String, dynamic>>>? roomsStream;

  @override
  State<ShopRoomTypeRoomsHub> createState() => _ShopRoomTypeRoomsHubState();
}

class _ShopRoomTypeRoomsHubState extends State<ShopRoomTypeRoomsHub> {
  late final ShopSetupLeaveGuard _editorLeaveGuard;
  bool _leaving = false;
  late Stream<List<Map<String, dynamic>>> _typesStream;
  late Stream<List<Map<String, dynamic>>> _roomsStream;
  @override
  void initState() {
    super.initState();
    _loadTutorialEligibility();
    _editorLeaveGuard = widget.leaveGuard ?? ShopSetupLeaveGuard();
    _typesStream =
        widget.roomTypesStream ??
        ShopService.instance.streamRoomTypes(widget.shopId);
    _roomsStream =
        widget.roomsStream ?? ShopService.instance.streamRooms(widget.shopId);
  }

  String? _selectedRoomTypeId;
  final Set<String> _expandedIds = <String>{};
  bool _creating = false;
  Map<String, dynamic>? _editing;
  ShopRoomTypeDraft? _draft;
  bool _mobilePreview = false;
  bool _nextChoiceVisible = false;
  int _createFormVersion = 0;
  int _intentRevision = 0;
  bool _targetSeen = false, _targetChanged = false;
  List<Map<String, dynamic>> _latestTypes = [];
  List<Map<String, dynamic>> _latestRooms = [];
  bool _roomNextOffered = false;
  int _pauseRevision = 0;
  late final String? _sessionUser =
      widget.guideUserId ?? FirebaseAuth.instance.currentUser?.uid;
  bool _intentCurrent(int revision) =>
      mounted &&
      revision == _intentRevision &&
      (widget.guideUserId ?? FirebaseAuth.instance.currentUser?.uid) ==
          _sessionUser &&
      widget.isActive &&
      ModalRoute.of(context)?.isCurrent == true;

  Future<void> _retryTarget() async {
    final id = _recentCreatedId;
    final revision = _intentRevision;
    if (id == null) return;
    try {
      final snapshot = await ShopRoomService.instance
          .roomTypesRef(widget.shopId)
          .doc(id)
          .get(const GetOptions(source: Source.server));
      if (!mounted || !_intentCurrent(revision)) return;
      setState(() {
        if (!snapshot.exists) {
          _targetSeen = true;
          _targetChanged = true;
        }
      });
      if (snapshot.exists) _reloadRoomData();
    } catch (e) {
      if (mounted && _intentCurrent(revision)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('指定房型讀取失敗，可重試或返回管理：$e')));
      }
    }
  }

  void _reloadRoomData() {
    setState(() {
      _typesStream =
          widget.roomTypesStream ??
          ShopService.instance.streamRoomTypes(widget.shopId);
      _roomsStream =
          widget.roomsStream ?? ShopService.instance.streamRooms(widget.shopId);
    });
  }

  Widget _loadError(String message) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        TextButton(onPressed: _reloadRoomData, child: const Text('重新讀取房型與房間')),
      ],
    ),
  );

  Widget _targetNotice() => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _targetChanged
                ? '指定房型狀態已變更，請返回管理確認；不會改選其他房型。'
                : '正在等候新房型資料，尚未顯示前不會改選其他房型。',
          ),
          TextButton(onPressed: _retryTarget, child: const Text('重新確認指定房型')),
          TextButton(
            onPressed: () {
              _intentRevision++;
              setState(() {
                _recentCreatedId = _guideTypeId = _pendingScrollId = null;
                _awaitingCreatedSelection = _targetChanged = false;
              });
              _pauseTutorial(true);
            },
            child: const Text('返回管理'),
          ),
        ],
      ),
    ),
  );

  @override
  void didUpdateWidget(covariant ShopRoomTypeRoomsHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId ||
        oldWidget.isActive != widget.isActive) {
      _intentRevision++;
      _nextChoiceVisible = false;
    }
    if (oldWidget.shopId != widget.shopId) {
      _pauseRevision++;
      _roomNextOffered = false;
      _recentCreatedId = _guideTypeId = _selectedRoomTypeId = _pendingScrollId =
          null;
      _awaitingCreatedSelection = _targetSeen = _targetChanged = false;
      _tutorialEligible = _tutorialStarted = _completed = _paused = false;
      _expandedIds.clear();
      _typesStream =
          widget.roomTypesStream ??
          ShopService.instance.streamRoomTypes(widget.shopId);
      _roomsStream =
          widget.roomsStream ?? ShopService.instance.streamRooms(widget.shopId);
      _loadTutorialEligibility();
    }
  }

  @override
  void dispose() {
    _intentRevision++;
    super.dispose();
  }

  Future<bool> _canOpenBookingSettings() async {
    if (widget.embeddedInSetupCenter) {
      return widget.onOpenBookingSettings != null;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final member = await ShopService.instance.getUserMemberInShop(
      shopId: widget.shopId,
      uid: uid,
    );
    return FirebaseAuth.instance.currentUser?.uid == uid &&
        ShopService.instance.hasPermission(
          member,
          ShopPermissionKeys.manageBookingSettings,
        );
  }

  Future<bool> _canOpenPolicy() async {
    if (widget.canManagePolicy != null) return widget.canManagePolicy!;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final shop = await ShopService.instance.getShop(widget.shopId);
    final member = await ShopService.instance.getUserMemberInShop(
      shopId: widget.shopId,
      uid: uid,
    );
    return FirebaseAuth.instance.currentUser?.uid == uid &&
        shop != null &&
        ShopPlanService.canUsePolicySettings(shop) &&
        ShopService.instance.hasPermission(
          member,
          ShopPermissionKeys.managePolicy,
        );
  }

  Future<void> _offerNextStep(String roomTypeId) async {
    if (!mounted || _nextChoiceVisible) return;
    final revision = _intentRevision;
    setState(() => _nextChoiceVisible = true);
    String? choice;
    try {
      choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('房型建立成功！'),
          content: const SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Text('接著建立這個房型的實際房號，顧客才有可預約的房間。剛才設定的房間數量是上限，不會自動建立房間。'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'later'),
              child: const Text('稍後繼續'),
            ),
            OutlinedButton(
              onPressed: widget.canManageRoomTypes
                  ? () => Navigator.pop(dialogContext, 'create')
                  : null,
              child: const Text('繼續新增房型'),
            ),
            FilledButton(
              onPressed: widget.canManageRooms
                  ? () => Navigator.pop(dialogContext, 'rooms')
                  : null,
              child: const Text('建立此房型的房間'),
            ),
            if (!widget.canManageRooms) const Text('請由有房間管理權限的人員建立實際房間。'),
          ],
        ),
      );
    } finally {
      if (mounted && revision == _intentRevision) {
        setState(() => _nextChoiceVisible = false);
      }
    }
    if (!mounted || !_intentCurrent(revision)) return;
    if (choice == 'create' && widget.canManageRoomTypes) {
      if (!await _editorLeaveGuard.confirmLeave() ||
          !_intentCurrent(revision)) {
        return;
      }
      setState(() {
        _createFormVersion++;
        _creating = true;
        _editing = null;
        _draft = null;
        _mobilePreview = false;
      });
    } else if (choice == 'rooms' && widget.canManageRooms) {
      setState(() {
        _recentCreatedId = _selectedRoomTypeId = roomTypeId;
        _guideTypeId = _tutorialEligible && !_completed ? roomTypeId : null;
        _tutorialStarted = _guideTypeId != null;
        _awaitingCreatedSelection = true;
        _expandedIds.add(roomTypeId);
        _guideStep = 2;
        _mobilePreview = false;
        _pendingScrollId = roomTypeId;
      });
      await _pauseTutorial(false);
      if (mounted && _intentCurrent(revision)) _scrollGuideTarget();
    } else {
      await _pauseTutorial(true);
    }
  }

  Future<StayBookingReadiness> _loadReadiness() =>
      widget.loadReadiness?.call() ?? StayBookingReadiness.load(widget.shopId);
  Future<bool> _loadPolicy() =>
      widget.loadStayPolicy?.call() ??
      ShopPolicyService.instance.hasEffectiveStayPolicy(widget.shopId);

  Future<void> _offerRoomNext(String roomTypeId) async {
    if (!_tutorialEligible ||
        !_tutorialStarted ||
        _paused ||
        _nextChoiceVisible ||
        !widget.isActive) {
      return;
    }
    final revision = _intentRevision;
    bool continueAfterPublished = false;
    Future<void> openBooking() async {
      if (!await _canOpenBookingSettings() || !_intentCurrent(revision)) {
        return;
      }
      if (widget.onOpenGuidedBookingSettings != null) {
        await widget.onOpenGuidedBookingSettings!();
      } else if (widget.onOpenBookingSettings != null) {
        await widget.onOpenBookingSettings!();
      } else if (!widget.embeddedInSetupCenter &&
          await _editorLeaveGuard.confirmLeave() &&
          mounted &&
          _intentCurrent(revision)) {
        await Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ShopBookingSettingsPage(
              shopId: widget.shopId,
              guideStayOpening: true,
              onManageRooms: () async {
                Navigator.of(context).pop();
              },
            ),
          ),
        );
      }
    }

    setState(() => _nextChoiceVisible = true);
    try {
      while (_intentCurrent(revision)) {
        bool? policy;
        bool canProceed = false;
        Object? error;
        try {
          final state = await _loadReadiness();
          if (!state.ready ||
              !state.rooms.any(
                (r) =>
                    r['roomTypeId'] == roomTypeId &&
                    !DaycareOccupancyService.isRoomDocumentUnsellable(r),
              )) {
            throw StateError('此房型尚無已啟用且可提供住宿的實際房間，請確認現有房間狀態。');
          }
          policy = await _loadPolicy();
          if (policy) {
            canProceed = await _canOpenBookingSettings();
          } else {
            canProceed = await _canOpenPolicy();
          }
        } catch (e) {
          error = e;
        }
        if (!mounted || !_intentCurrent(revision)) return;
        if (continueAfterPublished &&
            policy == true &&
            canProceed &&
            error == null) {
          await openBooking();
          return;
        }
        final choice = await showDialog<String>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('確認開店下一步'),
            content: Text(
              error != null
                  ? '尚無法確認房間與入住條款資格：$error'
                  : policy == true
                  ? '房間與入住條款已準備好，接著確認日期並手動開放住宿預約。'
                  : '房間已準備好，接著發布顧客預約前需要閱讀的入住條款。',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('繼續建立房間'),
              ),
              if (error != null)
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, 'retry'),
                  child: const Text('重新確認'),
                ),
              if (error == null && canProceed)
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, 'next'),
                  child: Text(policy == true ? '前往預約設定' : '前往設定入住條款'),
                ),
              if (error == null && !canProceed)
                const Text('請由店主或具有對應設定權限的人員完成下一步。'),
            ],
          ),
        );
        if (!mounted || !_intentCurrent(revision) || choice == null) return;
        if (choice == 'retry') continue;
        // Re-read after the choice: the dialog does not authorize stale data.
        final latest = await _loadReadiness();
        final latestPolicy = await _loadPolicy();
        if (!mounted || !_intentCurrent(revision)) return;
        if (!latest.ready ||
            !latest.rooms.any(
              (r) =>
                  r['roomTypeId'] == roomTypeId &&
                  !DaycareOccupancyService.isRoomDocumentUnsellable(r),
            ) ||
            latestPolicy != policy) {
          continue;
        }
        if (latestPolicy) {
          await openBooking();
          return;
        }
        if (!await _canOpenPolicy()) {
          return;
        }
        if (!mounted || !_intentCurrent(revision)) return;
        final published = await Navigator.of(context).push<bool>(
          MaterialPageRoute<bool>(
            settings: const RouteSettings(name: 'opening-stay-policy'),
            builder: (_) => ShopPolicyPage(
              shopId: widget.shopId,
              continueOpeningAfterPublish: true,
            ),
          ),
        );
        continueAfterPublished = published == true;
        // Returning without publishing keeps the policy step incomplete.
      }
    } catch (e) {
      if (mounted && _intentCurrent(revision)) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('下一步資格確認失敗，請重新確認：$e')));
      }
    } finally {
      if (mounted && revision == _intentRevision) {
        setState(() => _nextChoiceVisible = false);
      }
    }
  }

  String? _recentCreatedId;
  String? _guideTypeId;
  bool _awaitingCreatedSelection = false;
  String? _pendingScrollId;
  final Map<String, GlobalKey> _expandKeys = {};
  final Map<String, GlobalKey> _roomAreaKeys = {};
  final Map<String, GlobalKey> _addKeys = {}, _formKeys = {};
  final Set<String> _openForms = {};
  bool _tutorialEligible = false, _paused = false, _completed = false;
  bool _tutorialStarted = false, _verifying = false;
  bool _confirmationFailed = false;
  bool _quickCreateActive = false;
  int _guideStep = 1;

  String get _pauseKey =>
      'firstRoomTutorialPaused:${widget.guideUserId ?? FirebaseAuth.instance.currentUser?.uid}:${widget.shopId}';

  Future<void> _loadTutorialEligibility() async {
    final shopId = widget.shopId;
    final pauseRevision = _pauseRevision;
    try {
      if (widget.loadTutorialEligibility != null) {
        final eligible = await widget.loadTutorialEligibility!();
        final prefs = await SharedPreferences.getInstance();
        if (mounted && widget.shopId == shopId) {
          setState(() {
            _tutorialEligible = eligible;
            if (pauseRevision == _pauseRevision) {
              _paused = _paused || (prefs.getBool(_pauseKey) ?? false);
            }
          });
        }
        return;
      }
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final shop = await ShopService.instance.getShop(widget.shopId);
      final member = await ShopService.instance.getUserMemberInShop(
        shopId: widget.shopId,
        uid: uid,
      );
      final prefs = await SharedPreferences.getInstance();
      if (!mounted ||
          widget.shopId != shopId ||
          FirebaseAuth.instance.currentUser?.uid != uid) {
        return;
      }
      setState(() {
        _tutorialEligible =
            shop != null &&
            shop['ownerUid'] == uid &&
            member?['role'] == ShopRoles.owner &&
            ShopAdminWelcome.isNewShop(shop);
        if (pauseRevision == _pauseRevision) {
          _paused = _paused || (prefs.getBool(_pauseKey) ?? false);
        }
      });
    } catch (_) {
      // Failure to establish eligibility leaves normal management available.
    }
  }

  Future<void> _pauseTutorial(bool pause) async {
    if (!mounted) return;
    final revision = ++_pauseRevision;
    final key = _pauseKey;
    setState(() => _paused = pause);
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || revision != _pauseRevision || key != _pauseKey) return;
      await prefs.setBool(key, pause);
    } catch (_) {
      /* Pausing never marks the task complete. */
    }
    if (!pause && mounted) _scrollGuideTarget();
  }

  GlobalKey? get _guideTarget => _guideTypeId == null
      ? null
      : _guideStep == 1
      ? _expandKeys[_guideTypeId]
      : _guideStep == 2
      ? _addKeys[_guideTypeId]
      : _formKeys[_guideTypeId];

  void _scrollGuideTarget() {
    final revision = _intentRevision;
    final id = _guideTypeId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_intentCurrent(revision) &&
          id == _guideTypeId &&
          !_paused &&
          _guideTarget != null) {
        _scrollTo(_guideTarget!);
      }
    });
  }

  Future<void> _verifyCompletion({String? createdForType}) async {
    if (!_tutorialEligible ||
        _verifying ||
        (_completed && createdForType == null) ||
        _quickCreateActive ||
        _nextChoiceVisible) {
      return;
    }
    if (createdForType != null && _roomNextOffered) return;
    if (createdForType != null &&
        _guideTypeId != null &&
        createdForType != _guideTypeId) {
      return;
    }
    _verifying = true;
    final revision = _intentRevision;
    try {
      final state = await _loadReadiness();
      if (!mounted ||
          !_intentCurrent(revision) ||
          !state.ready ||
          _quickCreateActive ||
          _nextChoiceVisible) {
        return;
      }
      if (createdForType != null &&
          !state.rooms.any(
            (r) =>
                r['roomTypeId'] == createdForType &&
                !DaycareOccupancyService.isRoomDocumentUnsellable(r),
          )) {
        return;
      }
      final celebrate = createdForType != null && _tutorialStarted && !_paused;
      setState(() {
        _completed = true;
        _confirmationFailed = false;
        _guideTypeId = null;
        if (createdForType != null) _recentCreatedId ??= createdForType;
        if (celebrate) _roomNextOffered = true;
      });
      if (mounted && celebrate && ModalRoute.of(context)?.isCurrent == true) {
        await _offerRoomNext(createdForType);
      }
    } catch (_) {
      // Server confirmation is required; a local optimistic snapshot is insufficient.
      if (mounted && !_confirmationFailed) {
        setState(() => _confirmationFailed = true);
      }
    } finally {
      _verifying = false;
    }
  }

  void _syncTutorial(
    List<Map<String, dynamic>> types,
    List<Map<String, dynamic>> rooms,
  ) {
    if (!_tutorialEligible ||
        !widget.canManageRooms ||
        !widget.canManageRoomTypes ||
        _completed ||
        _quickCreateActive) {
      return;
    }
    final readiness = StayBookingReadiness(types, rooms, shopId: widget.shopId);
    if (readiness.ready) {
      if (_confirmationFailed || _tutorialStarted || _recentCreatedId != null) {
        return;
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _verifyCompletion();
      });
      return;
    }
    if (types.isEmpty) return;
    final candidates = readiness.rooms.isNotEmpty
        ? types
              .where(
                (t) => readiness.rooms.any((r) => r['roomTypeId'] == t['id']),
              )
              .toList()
        : types;
    if (candidates.isEmpty) return;
    final requested = _recentCreatedId ?? _guideTypeId;
    final matches = requested == null
        ? candidates
        : types.where((t) => t['id'] == requested).toList();
    if (matches.isEmpty) return;
    final id = SafeParse.parseString(matches.first['id']);
    final revision = _intentRevision;
    if (id.isEmpty || _guideTypeId == id) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_intentCurrent(revision) ||
          !_latestTypes.any((t) => t['id'] == id) ||
          (_recentCreatedId != null && _recentCreatedId != id) ||
          _creating ||
          _nextChoiceVisible) {
        return;
      }
      setState(() {
        _guideTypeId = id;
        _selectedRoomTypeId = id;
        _tutorialStarted = true;
        _guideStep = _expandedIds.contains(id)
            ? (_openForms.contains(id) ? 3 : 2)
            : 1;
      });
      if (!_paused) _scrollGuideTarget();
    });
  }

  void _scrollTo(GlobalKey target) {
    final revision = _intentRevision;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !_intentCurrent(revision) ||
          _creating ||
          _mobilePreview ||
          target.currentContext == null) {
        return;
      }
      final reduced = MediaQuery.disableAnimationsOf(context);
      Scrollable.ensureVisible(
        target.currentContext!,
        alignment: .35,
        duration: reduced ? Duration.zero : const Duration(milliseconds: 300),
      );
    });
  }

  Future<void> _showCreationGuide(String id) async {
    // Ignore the old seen preference: actual data drives the task.
    if (!_tutorialEligible || !mounted) return;
    setState(() => _recentCreatedId = id);
  }

  void _ensureSelection(List<Map<String, dynamic>> types) {
    _latestTypes = types;
    if (_recentCreatedId != null) {
      final found = types.any((t) => t['id'] == _recentCreatedId);
      if (found) {
        if (!_targetSeen || _targetChanged) _pendingScrollId = _recentCreatedId;
        _targetSeen = true;
        _targetChanged = false;
      } else {
        _targetChanged = _targetSeen;
        return;
      }
    }
    if (_awaitingCreatedSelection &&
        types.any((type) => type['id'] == _recentCreatedId)) {
      _selectedRoomTypeId = _recentCreatedId;
      _awaitingCreatedSelection = false;
    }
    if (_pendingScrollId != null &&
        types.any((type) => type['id'] == _pendingScrollId)) {
      _scrollTo(
        (_expandedIds.contains(_pendingScrollId) ? _roomAreaKeys : _expandKeys)
            .putIfAbsent(_pendingScrollId!, GlobalKey.new),
      );
      _pendingScrollId = null;
    }
    if (_awaitingCreatedSelection) return;
    if (types.isEmpty) {
      _selectedRoomTypeId = null;
      return;
    }
    final bool exists = types.any(
      (Map<String, dynamic> item) =>
          SafeParse.parseString(item['id']) == _selectedRoomTypeId,
    );
    if (!exists) {
      _selectedRoomTypeId = SafeParse.parseString(types.first['id']);
    }
  }

  Future<void> _deleteRoomType(Map<String, dynamic> item) async {
    final String roomTypeId = SafeParse.parseString(item['id']);
    final String roomTypeName = SafeParse.parseString(
      item['name'],
      fallback: '此房型',
    );
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('確認刪除房型'),
          content: Text('確定要刪除「$roomTypeName」嗎？刪除後，這個房型底下建立的房間也會一併刪除，且無法復原。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('確認刪除'),
            ),
          ],
        );
      },
    );
    if (confirm != true) {
      return;
    }
    final List<Map<String, dynamic>> rooms = await ShopService.instance
        .getRooms(widget.shopId);
    final Iterable<Map<String, dynamic>> targetRooms = rooms.where(
      (Map<String, dynamic> room) =>
          SafeParse.parseString(room['roomTypeId']) == roomTypeId,
    );
    try {
      if (!mounted) return;
      if (!await deleteRoomsWithStayGuard(
        context,
        widget.shopId,
        targetRooms.map((room) => SafeParse.parseString(room['id'])).toSet(),
        roomTypeId: roomTypeId,
      )) {
        return;
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
      return;
    }
    final User? user = FirebaseAuth.instance.currentUser;
    await ActionLogService.instance.logAction(
      shopId: widget.shopId,
      targetType: 'room_type',
      targetId: roomTypeId,
      action: '刪除房型',
      operatorUid: user?.uid ?? '',
      operatorRole: 'owner',
      payload: <String, dynamic>{
        'roomTypeName': roomTypeName,
        'deletedRoomCount': targetRooms.length,
      },
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('已刪除房型與其底下房間')));
  }

  ShopRoomTypeDraft _previewDraft(List<Map<String, dynamic>> types) {
    if (_creating || _editing != null) {
      return _draft ??
          ShopRoomTypeDraft.fromRoomType(_editing ?? <String, dynamic>{});
    }
    if (types.isEmpty) {
      return ShopRoomTypeDraft.fromRoomType(<String, dynamic>{});
    }
    if (_awaitingCreatedSelection || _targetChanged) {
      return ShopRoomTypeDraft.fromRoomType(<String, dynamic>{});
    }
    final Map<String, dynamic> selected = types.firstWhere(
      (Map<String, dynamic> item) =>
          SafeParse.parseString(item['id']) == _selectedRoomTypeId,
      orElse: () => types.first,
    );
    return ShopRoomTypeDraft.fromRoomType(selected);
  }

  @override
  Widget build(BuildContext context) {
    final Widget body = StreamBuilder<List<Map<String, dynamic>>>(
      stream: _typesStream,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<Map<String, dynamic>>> typeSnap,
          ) {
            if (typeSnap.hasError) {
              return _loadError('房型資料讀取失敗，請重試或返回管理');
            }
            if (typeSnap.connectionState == ConnectionState.waiting &&
                !typeSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            return StreamBuilder<List<Map<String, dynamic>>>(
              stream: _roomsStream,
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<Map<String, dynamic>>> roomSnap,
                  ) {
                    if (roomSnap.hasError) {
                      return _loadError('房間資料讀取失敗，請重試或返回管理');
                    }
                    if (roomSnap.connectionState == ConnectionState.waiting &&
                        !roomSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final List<Map<String, dynamic>> types =
                        typeSnap.data ?? <Map<String, dynamic>>[];
                    final List<Map<String, dynamic>> rooms =
                        roomSnap.data ?? <Map<String, dynamic>>[];
                    _latestRooms = rooms;
                    // Allocate the stable key before the delayed target is mounted.
                    for (final type in types) {
                      final id = SafeParse.parseString(type['id']);
                      _expandKeys.putIfAbsent(id, GlobalKey.new);
                      _roomAreaKeys.putIfAbsent(id, GlobalKey.new);
                      _addKeys.putIfAbsent(id, GlobalKey.new);
                      _formKeys.putIfAbsent(id, GlobalKey.new);
                    }
                    _ensureSelection(types);
                    _syncTutorial(types, rooms);
                    final guideHasRooms = rooms.any(
                      (r) => r['roomTypeId'] == _guideTypeId,
                    );
                    final active =
                        !_awaitingCreatedSelection &&
                        !_targetChanged &&
                        _tutorialEligible &&
                        !_paused &&
                        !_completed &&
                        !_nextChoiceVisible &&
                        widget.isActive &&
                        !_quickCreateActive &&
                        widget.canManageRooms &&
                        widget.canManageRoomTypes &&
                        !_creating &&
                        _editing == null &&
                        !_mobilePreview &&
                        !guideHasRooms;
                    return ShopSetupSpotlight(
                      target: active ? _guideTarget : null,
                      step: _guideStep,
                      description: _guideStep == 2
                          ? '只建立一間可選「新增房間」；需要多間可選「快速建房」。請建立店內實際使用的房號。'
                          : null,
                      onPause: () => _pauseTutorial(true),
                      child: ShopRoomTypeWorkspace(
                        previewAvailable:
                            types.isNotEmpty || _creating || _editing != null,
                        editor: _rightPane(types, rooms),
                        preview: types.isEmpty && !_creating && _editing == null
                            ? const Center(child: Text('新增房型後即可在此預覽'))
                            : ShopRoomTypeLivePreview(
                                draft: _previewDraft(types),
                              ),
                        showPreview: _mobilePreview,
                        onPreviewChanged: (value) =>
                            setState(() => _mobilePreview = value),
                      ),
                    );
                  },
            );
          },
    );

    if (widget.embeddedInSetupCenter) {
      return Material(color: const Color(0xFFF6F8FB), child: body);
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) await _leavePage();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF6F8FB),
        appBar: AppBar(
          title: const Text('房型與房間管理'),
          leading: IconButton(
            icon: const BackButtonIcon(),
            onPressed: _leavePage,
          ),
          actions: <Widget>[ShopTaskCenterButton(shopId: widget.shopId)],
        ),
        body: body,
      ),
    );
  }

  Future<void> _leavePage() async {
    if (_leaving) return;
    _leaving = true;
    try {
      if (await _editorLeaveGuard.confirmLeave() && mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      _leaving = false;
    }
  }

  Widget _rightPane(
    List<Map<String, dynamic>> types,
    List<Map<String, dynamic>> rooms,
  ) {
    if (_creating || _editing != null) {
      return ShopRoomTypeEditorPage(
        key: ValueKey<String>(
          _creating
              ? 'create-room-type-$_createFormVersion'
              : 'edit-${SafeParse.parseString(_editing?['id'])}',
        ),
        shopId: widget.shopId,
        existing: _editing,
        embedded: true,
        leaveGuard: _editorLeaveGuard,
        saveDraft: widget.saveDraft,
        onDraftChanged: (ShopRoomTypeDraft draft) {
          if (mounted) setState(() => _draft = draft);
        },
        onCancel: () {
          setState(() {
            _creating = false;
            _editing = null;
            _draft = null;
          });
        },
        onSaved: (String id) {
          final created = _creating;
          setState(() {
            if (created &&
                StayBookingReadiness(
                  _latestTypes,
                  _latestRooms,
                  shopId: widget.shopId,
                ).ready &&
                !_tutorialStarted) {
              _completed = true;
            }
            _creating = false;
            _editing = null;
            _draft = null;
            if (id.isNotEmpty) {
              _selectedRoomTypeId = id;
              if (created) {
                _recentCreatedId = id;
                _awaitingCreatedSelection = true;
                _pendingScrollId = id;
              }
            }
          });
          if (created && id.isNotEmpty) {
            _intentRevision++;
            _targetSeen = _targetChanged = false;
            _showCreationGuide(id);
            _offerNextStep(id);
          }
        },
      );
    }

    if (types.isEmpty && (_awaitingCreatedSelection || _targetChanged)) {
      return _targetNotice();
    }
    if (types.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.home_work_outlined,
                    size: 48,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    '建立你的第一個房型',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '先設定房型與價格，再建立實際房號，準備開放住宿預約。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  if (widget.canManageRoomTypes)
                    FilledButton.icon(
                      onPressed: () => setState(() {
                        _creating = true;
                        _mobilePreview = false;
                      }),
                      icon: const Icon(Icons.add),
                      label: const Text('新增第一個房型'),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 24),
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    '房型與房間管理',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '先建立客戶看到的房型，再於房型下建立實際房號。',
                    style: TextStyle(fontSize: 13, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (widget.canManageRoomTypes)
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _creating = true;
                    _editing = null;
                    _draft = null;
                    _mobilePreview = false;
                  });
                },
                icon: const Icon(Icons.add),
                label: const Text('新增房型'),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (_awaitingCreatedSelection || _targetChanged) _targetNotice(),
        if (_completed &&
            _tutorialEligible &&
            _tutorialStarted &&
            _recentCreatedId != null)
          TextButton(
            onPressed: () => _offerRoomNext(_recentCreatedId!),
            child: const Text('確認條款與預約下一步'),
          ),
        if (_tutorialEligible &&
            widget.canManageRooms &&
            widget.canManageRoomTypes &&
            !_completed &&
            _guideTypeId != null) ...[
          if (_confirmationFailed)
            TextButton(
              onPressed: () => _verifyCompletion(createdForType: _guideTypeId),
              child: const Text('尚無法向伺服器確認房間狀態，點此重試'),
            ),
          if (rooms.any((r) => r['roomTypeId'] == _guideTypeId))
            const Text('房間已建立，請確認房間已啟用，且不是永久維修或停用狀態；不需要再新增房間。'),
          if (rooms.any((r) => r['roomTypeId'] == _guideTypeId))
            TextButton(
              onPressed: _quickCreateActive
                  ? null
                  : () => _verifyCompletion(createdForType: _guideTypeId),
              child: const Text('確認房間狀態並繼續'),
            ),
          TextButton(
            onPressed: () => _pauseTutorial(!_paused),
            child: Text(_paused ? '繼續開店教學' : '稍後繼續'),
          ),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF5F6F8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE8D4B8)),
          ),
          child: const Text(
            '刪除房型時，該房型底下的房間也會一併刪除。若只是暫停開放，請停用房間或關閉可預約日期。',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF5C4A38),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...[
          ...types.where((type) => type['id'] == _recentCreatedId),
          ...types.where((type) => type['id'] != _recentCreatedId),
        ].map((Map<String, dynamic> type) {
          final id = SafeParse.parseString(type['id']);
          return _RoomTypeManageCard(
            key: ValueKey('room-type-card-$id'),
            expandKey: _expandKeys.putIfAbsent(id, GlobalKey.new),
            roomAreaKey: _roomAreaKeys.putIfAbsent(id, GlobalKey.new),
            addKey: _addKeys.putIfAbsent(id, GlobalKey.new),
            formKey: _formKeys.putIfAbsent(id, GlobalKey.new),
            onAddingChanged: (adding) {
              setState(() {
                if (adding) {
                  _openForms.add(id);
                } else {
                  _openForms.remove(id);
                }
                if (_guideTypeId == id) _guideStep = adding ? 3 : 2;
              });
              if (!_paused) _scrollGuideTarget();
            },
            onRoomCreated: () => _verifyCompletion(createdForType: id),
            onQuickCreateChanged: (active) {
              setState(() {
                _quickCreateActive = active;
                if (_guideTypeId == id) _guideStep = 2;
              });
              if (!active && !_paused) _scrollGuideTarget();
            },
            shopId: widget.shopId,
            roomType: type,
            rooms: rooms
                .where(
                  (Map<String, dynamic> room) =>
                      SafeParse.parseString(room['roomTypeId']) ==
                      SafeParse.parseString(type['id']),
                )
                .toList(),
            selected: SafeParse.parseString(type['id']) == _selectedRoomTypeId,
            expanded: _expandedIds.contains(SafeParse.parseString(type['id'])),
            canManageTypes: widget.canManageRoomTypes,
            canManageRooms: widget.canManageRooms,
            onSelect: () {
              setState(() {
                _selectedRoomTypeId = SafeParse.parseString(type['id']);
              });
            },
            onToggleExpand: () {
              final String id = SafeParse.parseString(type['id']);
              setState(() {
                if (_expandedIds.contains(id)) {
                  _expandedIds.remove(id);
                } else {
                  _expandedIds.add(id);
                }
                _selectedRoomTypeId = id;
                if (_guideTypeId == id) {
                  _guideStep = _expandedIds.contains(id)
                      ? (_openForms.contains(id) ? 3 : 2)
                      : 1;
                }
              });
              if (_guideTypeId == id && !_paused) {
                _scrollGuideTarget();
              } else if (_expandedIds.contains(id)) {
                _scrollTo(_roomAreaKeys[id]!);
              }
            },
            onEdit: () {
              setState(() {
                _editing = type;
                _creating = false;
                _draft = ShopRoomTypeDraft.fromRoomType(type);
                _selectedRoomTypeId = SafeParse.parseString(type['id']);
                _mobilePreview = false;
              });
            },
            onDelete: () => _deleteRoomType(type),
          );
        }),
      ],
    );
  }
}

class _RoomTypeManageCard extends StatelessWidget {
  const _RoomTypeManageCard({
    super.key,
    required this.expandKey,
    required this.addKey,
    required this.formKey,
    required this.onAddingChanged,
    required this.onRoomCreated,
    required this.onQuickCreateChanged,
    required this.roomAreaKey,
    required this.shopId,
    required this.roomType,
    required this.rooms,
    required this.selected,
    required this.expanded,
    required this.canManageTypes,
    required this.canManageRooms,
    required this.onSelect,
    required this.onToggleExpand,
    required this.onEdit,
    required this.onDelete,
  });

  final String shopId;
  final GlobalKey expandKey;
  final GlobalKey addKey, formKey;
  final ValueChanged<bool> onAddingChanged;
  final Future<void> Function() onRoomCreated;
  final ValueChanged<bool> onQuickCreateChanged;
  final GlobalKey roomAreaKey;
  final Map<String, dynamic> roomType;
  final List<Map<String, dynamic>> rooms;
  final bool selected;
  final bool expanded;
  final bool canManageTypes;
  final bool canManageRooms;
  final VoidCallback onSelect;
  final VoidCallback onToggleExpand;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final String name = SafeParse.parseString(
      roomType['name'],
      fallback: '未命名房型',
    );
    final int price = SafeParse.parseInt(roomType['price']);
    final int capacity = SafeParse.parseInt(roomType['capacity']);
    final int limit = SafeParse.parseInt(roomType['totalRooms']);
    final int enabledCount = rooms.where((Map<String, dynamic> room) {
      return !DaycareOccupancyService.isRoomDocumentUnsellable(room);
    }).length;
    final List<String> images = SafeParse.parseList(roomType['images'])
        .map((dynamic e) => e.toString())
        .where((String url) => url.isNotEmpty)
        .toList();
    final bool bookable = enabledCount > 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      color: selected ? colors.primary.withValues(alpha: 0.06) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: selected ? colors.primary : const Color(0xFFE6EAF0),
          width: selected ? 1.6 : 1,
        ),
      ),
      child: Column(
        children: <Widget>[
          InkWell(
            onTap: onSelect,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: SizedBox(
                      width: 64,
                      height: 64,
                      child: images.isEmpty
                          ? ColoredBox(
                              color: const Color(0xFFF1F3F7),
                              child: Icon(
                                Icons.bed_outlined,
                                color: Colors.grey.shade500,
                              ),
                            )
                          : Image.network(
                              images.first,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (
                                    BuildContext context,
                                    Object error,
                                    StackTrace? stackTrace,
                                  ) {
                                    return ColoredBox(
                                      color: const Color(0xFFF1F3F7),
                                      child: Icon(
                                        Icons.broken_image_outlined,
                                        color: Colors.grey.shade500,
                                      ),
                                    );
                                  },
                            ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'NT\$ $price / 晚　可住 $capacity 隻',
                          style: const TextStyle(fontSize: 12),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '已建立 ${rooms.length}／上限 $limit　啟用中 $enabledCount　${bookable ? '可預約' : '不可預約'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (canManageTypes)
                    IconButton(
                      tooltip: '編輯房型',
                      icon: const Icon(Icons.edit_outlined),
                      onPressed: onEdit,
                    ),
                  PopupMenuButton<String>(
                    onSelected: (String value) {
                      if (value == 'edit') {
                        onEdit();
                      } else if (value == 'delete') {
                        onDelete();
                      }
                    },
                    itemBuilder: (BuildContext context) {
                      return <PopupMenuEntry<String>>[
                        if (canManageTypes)
                          const PopupMenuItem<String>(
                            value: 'edit',
                            child: Text('編輯房型'),
                          ),
                        if (canManageTypes)
                          const PopupMenuItem<String>(
                            value: 'delete',
                            child: Text(
                              '刪除房型',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                      ];
                    },
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Column(
            children: [
              ListTile(
                key: expandKey,
                dense: true,
                title: const Text('展開／收合房間'),
                subtitle: rooms.isEmpty ? const Text('尚未建立實際房間') : null,
                trailing: Icon(
                  expanded ? Icons.expand_less : Icons.expand_more,
                ),
                onTap: onToggleExpand,
              ),
              if (rooms.isEmpty && !expanded && canManageRooms)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: onToggleExpand,
                    icon: const Icon(Icons.add_home_outlined, size: 18),
                    label: const Text('建立房間'),
                  ),
                ),
            ],
          ),
          Offstage(
            offstage: !expanded,
            child: RoomManagementSection(
              key: roomAreaKey,
              addButtonKey: addKey,
              addFormKey: formKey,
              onAddingChanged: onAddingChanged,
              onRoomCreated: onRoomCreated,
              onQuickCreateChanged: onQuickCreateChanged,
              shopId: shopId,
              roomType: roomType,
              rooms: rooms,
              canManage: canManageRooms,
            ),
          ),
        ],
      ),
    );
  }
}
