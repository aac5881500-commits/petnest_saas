import 'package:petnest_saas/features/shop/widgets/shop_room_type_workspace.dart';
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
  });

  final ShopSetupLeaveGuard? leaveGuard;
  final Future<String> Function(ShopRoomTypeDraft)? saveDraft;
  final String? guideUserId;
  final Future<void> Function()? onOpenBookingSettings;
  final bool isActive;
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

  Future<void> _offerNextStep() async {
    // Invoked only by the successful creation callback, never by a stream/build.
    if (!mounted || _nextChoiceVisible) return;
    setState(() {
      _nextChoiceVisible = true;
      _paused = true;
    });
    try {
      bool canBook = false;
      try {
        canBook = await _canOpenBookingSettings();
      } catch (_) {
        /* Fail closed. */
      }
      if (!mounted ||
          !widget.isActive ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      bool submitted = false;
      void choose(BuildContext dialogContext, String? choice) {
        if (submitted) return;
        submitted = true;
        Navigator.pop(dialogContext, choice);
      }

      final choice = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('房型建立成功！'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('你可以繼續新增其他房型，或前往預約設定。'),
                  const SizedBox(height: 16),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final buttons = <Widget>[
                        OutlinedButton(
                          onPressed: widget.canManageRoomTypes
                              ? () => choose(dialogContext, 'create')
                              : null,
                          child: const Text('繼續新增房型'),
                        ),
                        FilledButton(
                          onPressed: canBook
                              ? () => choose(dialogContext, 'booking')
                              : null,
                          child: const Text('前往預約設定'),
                        ),
                      ];
                      if (constraints.maxWidth < 380 ||
                          MediaQuery.textScalerOf(context).scale(1) > 1.2) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            buttons[0],
                            const SizedBox(height: 8),
                            buttons[1],
                          ],
                        );
                      }
                      return Row(
                        children: [
                          Expanded(child: buttons[0]),
                          const SizedBox(width: 8),
                          Expanded(child: buttons[1]),
                        ],
                      );
                    },
                  ),
                  if (!canBook) const Text('目前無法確認預約設定權限，請從既有授權入口操作。'),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => choose(dialogContext, null),
              child: const Text('稍後再說'),
            ),
          ],
        ),
      );
      if (!mounted ||
          !widget.isActive ||
          ModalRoute.of(context)?.isCurrent != true) {
        return;
      }
      if (choice == 'create' && widget.canManageRoomTypes) {
        if (!await _editorLeaveGuard.confirmLeave() || !mounted) return;
        setState(() {
          _createFormVersion++;
          _creating = true;
          _editing = null;
          _draft = null;
          _mobilePreview = false;
        });
      } else if (choice == 'booking') {
        if (!await _canOpenBookingSettings() || !mounted) return;
        if (widget.onOpenBookingSettings != null) {
          await widget.onOpenBookingSettings!();
        } else if (!widget.embeddedInSetupCenter &&
            await _editorLeaveGuard.confirmLeave() &&
            mounted) {
          await Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => ShopBookingSettingsPage(
                shopId: widget.shopId,
                onManageRooms: () async {
                  Navigator.of(context).pop();
                },
              ),
            ),
          );
        }
      }
    } catch (_) {
      if (mounted &&
          widget.isActive &&
          ModalRoute.of(context)?.isCurrent == true) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('暫時無法開啟預約設定，請稍後再試')));
      }
    } finally {
      if (mounted) setState(() => _nextChoiceVisible = false);
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
      'firstRoomTutorialPaused:${FirebaseAuth.instance.currentUser?.uid}:${widget.shopId}';

  Future<void> _loadTutorialEligibility() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final shop = await ShopService.instance.getShop(widget.shopId);
      final member = await ShopService.instance.getUserMemberInShop(
        shopId: widget.shopId,
        uid: uid,
      );
      final prefs = await SharedPreferences.getInstance();
      if (!mounted || FirebaseAuth.instance.currentUser?.uid != uid) return;
      setState(() {
        _tutorialEligible =
            shop != null &&
            shop['ownerUid'] == uid &&
            member?['role'] == ShopRoles.owner &&
            ShopAdminWelcome.isNewShop(shop);
        _paused =
            _nextChoiceVisible ||
            _paused ||
            (prefs.getBool(_pauseKey) ?? false);
      });
    } catch (_) {
      // Failure to establish eligibility leaves normal management available.
    }
  }

  Future<void> _pauseTutorial(bool pause) async {
    setState(() => _paused = pause);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_pauseKey, pause);
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _guideTarget != null) _scrollTo(_guideTarget!);
    });
  }

  Future<void> _verifyCompletion() async {
    if (!_tutorialEligible ||
        _verifying ||
        _completed ||
        _quickCreateActive ||
        _nextChoiceVisible) {
      return;
    }
    _verifying = true;
    try {
      final state = await StayBookingReadiness.load(widget.shopId);
      if (!mounted ||
          !state.ready ||
          _quickCreateActive ||
          _nextChoiceVisible) {
        return;
      }
      final celebrate = _tutorialStarted;
      setState(() {
        _completed = true;
        _confirmationFailed = false;
        _guideTypeId = null;
      });
      if (celebrate && ModalRoute.of(context)?.isCurrent == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('第一間房間準備好了！接著可前往預約設定，確認後再手動開放。')),
        );
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
      if (_confirmationFailed) return;
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
    final id = SafeParse.parseString(
      candidates.firstWhere(
        (t) => t['id'] == (_recentCreatedId ?? _guideTypeId),
        orElse: () => candidates.first,
      )['id'],
    );
    if (id.isEmpty || _guideTypeId == id) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || target.currentContext == null) return;
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
    if (_awaitingCreatedSelection &&
        types.any((type) => type['id'] == _recentCreatedId)) {
      _selectedRoomTypeId = _recentCreatedId;
      _awaitingCreatedSelection = false;
    }
    if (_pendingScrollId != null &&
        types.any((type) => type['id'] == _pendingScrollId)) {
      _scrollTo(_expandKeys.putIfAbsent(_pendingScrollId!, GlobalKey.new));
      _pendingScrollId = null;
    }
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
              return const Center(child: Text('房型資料讀取失敗，請稍後再試'));
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
                      return const Center(child: Text('房間資料讀取失敗，請稍後再試'));
                    }
                    if (roomSnap.connectionState == ConnectionState.waiting &&
                        !roomSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final List<Map<String, dynamic>> types =
                        typeSnap.data ?? <Map<String, dynamic>>[];
                    final List<Map<String, dynamic>> rooms =
                        roomSnap.data ?? <Map<String, dynamic>>[];
                    _ensureSelection(types);
                    _syncTutorial(types, rooms);
                    final guideHasRooms = rooms.any(
                      (r) => r['roomTypeId'] == _guideTypeId,
                    );
                    final active =
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
            _showCreationGuide(id);
            _offerNextStep();
          }
        },
      );
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
        if (_tutorialEligible &&
            widget.canManageRooms &&
            widget.canManageRoomTypes &&
            !_completed &&
            _guideTypeId != null) ...[
          if (_confirmationFailed)
            TextButton(
              onPressed: _verifyCompletion,
              child: const Text('尚無法向伺服器確認房間狀態，點此重試'),
            ),
          if (rooms.any((r) => r['roomTypeId'] == _guideTypeId))
            const Text('房間已建立，請確認房間已啟用，且不是永久維修或停用狀態；不需要再新增房間。'),
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
            onRoomCreated: _verifyCompletion,
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
