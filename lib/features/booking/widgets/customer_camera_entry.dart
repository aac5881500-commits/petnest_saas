// 檔案名稱：lib/features/booking/widgets/customer_camera_entry.dart
// 功能說明：照護回報與訂單詳細共用的攝影機入口，跟著目前房間與最新設備設定更新。

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:petnest_saas/core/models/camera_access_policy.dart';
import 'package:petnest_saas/core/models/camera_brand.dart';
import 'package:petnest_saas/core/models/camera_entry_watch.dart';
import 'package:petnest_saas/core/services/camera_access_service.dart';
import 'package:petnest_saas/features/booking/widgets/booking_detail/booking_detail_ui.dart';
import 'package:petnest_saas/features/booking/widgets/camera_brand_launch.dart';

typedef CustomerCameraPresenter =
    Future<void> Function(BuildContext context, CustomerRoomCamera camera);

class CustomerCameraGate extends StatefulWidget {
  const CustomerCameraGate({
    super.key,
    required this.bookingId,
    required this.builder,
    this.enabled = true,
    this.watchEntry,
    this.loadCamera,
    this.presentExternal,
    this.reloadDelay = cameraEntryReloadDelay,
  });

  final String bookingId;
  final bool enabled;
  final Widget Function(BuildContext context, CustomerCameraGateState state)
  builder;
  final Stream<CameraEntryWatch> Function(String bookingId)? watchEntry;
  final Future<CustomerRoomCameraResult> Function(String bookingId)? loadCamera;
  final CustomerCameraPresenter? presentExternal;
  final Duration reloadDelay;

  @override
  State<CustomerCameraGate> createState() => CustomerCameraGateState();
}

class CustomerCameraGateState extends State<CustomerCameraGate>
    with WidgetsBindingObserver {
  CustomerRoomCameraResult? _result;
  bool _loading = false;
  int _ticket = 0;
  StreamSubscription<CameraEntryWatch>? _watchSub;
  Timer? _reloadTimer;
  CameraEntryWatch? _watch;
  bool _externalOpen = false;
  String _presentedKey = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  @override
  void didUpdateWidget(covariant CustomerCameraGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bookingId != widget.bookingId ||
        oldWidget.enabled != widget.enabled) {
      _ticket++;
      _reloadTimer?.cancel();
      _watch = null;
      _dismissExternal();
      _listen();
      setState(() {
        _result = null;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _ticket++;
    _reloadTimer?.cancel();
    _watchSub?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.enabled) {
      _load();
    }
  }

  void _listen() {
    _watchSub?.cancel();
    _watchSub = null;
    if (!widget.enabled || widget.bookingId.trim().isEmpty) {
      return;
    }
    final Stream<CameraEntryWatch> stream = widget.watchEntry != null
        ? widget.watchEntry!(widget.bookingId)
        : CameraAccessService.instance.watchCustomerCameraEntry(
            widget.bookingId,
          );
    _watchSub = stream.listen(_onWatch, onError: _onWatchError);
  }

  void _onWatch(CameraEntryWatch next) {
    if (!mounted || next.bookingId != widget.bookingId) {
      return;
    }
    final CameraEntryWatch? previous = _watch;
    if (!cameraEntryShouldReload(previous, next)) {
      return;
    }
    _watch = next;
    final bool closed = !next.serviceOpen || !next.shopCameraOn;
    if (previous != null) {
      _ticket++;
      _dismissExternal();
      setState(() {
        _result = closed ? const CustomerRoomCameraResult.hidden() : null;
        _loading = !closed;
      });
    } else if (closed) {
      setState(() {
        _result = const CustomerRoomCameraResult.hidden();
        _loading = false;
      });
    }
    _reloadTimer?.cancel();
    _reloadTimer = Timer(widget.reloadDelay, () {
      if (!mounted) {
        return;
      }
      _load(expectedRoomId: next.roomId);
    });
  }

  void _onWatchError(Object error) {
    _ticket++;
    _reloadTimer?.cancel();
    _watchSub?.cancel();
    _watchSub = null;
    _dismissExternal();
    if (!mounted) {
      return;
    }
    final String message =
        error is CameraAccessException && error.message.isNotEmpty
        ? error.message
        : '攝影機暫時無法讀取，請再試一次';
    setState(() {
      _result = CustomerRoomCameraResult.error(message);
      _loading = false;
    });
  }

  Future<CustomerRoomCameraResult> _fetch(String bookingId) {
    final Future<CustomerRoomCameraResult> Function(String bookingId)? loader =
        widget.loadCamera;
    if (loader != null) {
      return loader(bookingId);
    }
    return CameraAccessService.instance.getCustomerRoomCamera(bookingId);
  }

  Future<void> _load({String? expectedRoomId, bool clearFirst = false}) async {
    _reloadTimer?.cancel();
    final int ticket = ++_ticket;
    final String bookingId = widget.bookingId;
    final String roomId = expectedRoomId ?? _watch?.roomId ?? '';
    if (!widget.enabled || bookingId.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _result = null;
          _loading = false;
        });
      }
      return;
    }
    if (clearFirst && mounted) {
      _dismissExternal();
      setState(() {
        _result = null;
        _loading = true;
      });
    } else if (mounted && _result == null) {
      setState(() => _loading = true);
    }
    final CustomerRoomCameraResult result = await _fetch(bookingId);
    if (!mounted ||
        !cameraGateResultIsCurrent(
          requestTicket: ticket,
          currentTicket: _ticket,
          requestBookingId: bookingId,
          currentBookingId: widget.bookingId,
          requestRoomId: roomId,
          currentRoomId: _watch?.roomId ?? roomId,
        )) {
      return;
    }
    final bool locallyClosed =
        _watch != null && (!_watch!.serviceOpen || !_watch!.shopCameraOn);
    final CustomerRoomCameraResult shown = locallyClosed && result.isError
        ? const CustomerRoomCameraResult.hidden()
        : result;
    if (_externalOpen && shown.camera != null) {
      final String key = customerCameraIdentity(
        roomId: shown.camera!.roomId,
        deviceId: shown.camera!.deviceId,
        viewMode: shown.camera!.viewMode,
        provider: shown.camera!.provider,
      );
      if (_presentedKey.isNotEmpty && key != _presentedKey) {
        _dismissExternal();
      }
    }
    setState(() {
      _result = shown;
      _loading = false;
    });
  }

  void _dismissExternal() {
    if (!_externalOpen || !mounted) {
      return;
    }
    _externalOpen = false;
    _presentedKey = '';
    final NavigatorState navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    }
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(const SnackBar(content: Text('房間或攝影機已變更，請重新開啟')));
  }

  Future<void> open(BuildContext context) async {
    _reloadTimer?.cancel();
    final int ticket = ++_ticket;
    final String bookingId = widget.bookingId;
    final String roomId = _watch?.roomId ?? '';
    final CustomerRoomCameraResult result = await _fetch(bookingId);
    if (!mounted ||
        !cameraGateResultIsCurrent(
          requestTicket: ticket,
          currentTicket: _ticket,
          requestBookingId: bookingId,
          currentBookingId: widget.bookingId,
          requestRoomId: roomId,
          currentRoomId: _watch?.roomId ?? roomId,
        )) {
      return;
    }
    setState(() {
      _result = result;
      _loading = false;
    });
    if (!context.mounted) {
      return;
    }
    final CustomerRoomCamera? camera = result.camera;
    if (!result.isReady || camera == null) {
      final String message = result.isUnsupported
          ? (result.message.isEmpty ? '此品牌尚未開放，不能改用其他品牌觀看。' : result.message)
          : (result.message.isEmpty ? '目前沒有可使用的攝影機，請再試一次' : result.message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    if (!camera.isExternal) {
      await _openWeb(context, camera);
      return;
    }
    await _presentExternal(context, camera);
    if (mounted) {
      await _load(expectedRoomId: _watch?.roomId ?? roomId);
    }
  }

  Future<void> _presentExternal(
    BuildContext context,
    CustomerRoomCamera camera,
  ) async {
    _externalOpen = true;
    _presentedKey = customerCameraIdentity(
      roomId: camera.roomId,
      deviceId: camera.deviceId,
      viewMode: camera.viewMode,
      provider: camera.provider,
    );
    try {
      final CustomerCameraPresenter? presenter = widget.presentExternal;
      if (presenter != null) {
        await presenter(context, camera);
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (BuildContext dialogContext) {
          return CustomerCameraRequestDialog(
            child: _ExternalRequestSheet(
              bookingId: widget.bookingId,
              camera: camera,
            ),
          );
        },
      );
    } finally {
      _externalOpen = false;
      _presentedKey = '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || widget.bookingId.trim().isEmpty) {
      return const SizedBox.shrink();
    }
    return widget.builder(context, this);
  }

  bool get loading => _loading && _result == null;
  CustomerRoomCameraResult? get result => _result;

  Future<void> retry() {
    if (_watchSub == null) {
      _listen();
    }
    return _load(clearFirst: true);
  }
}

class CustomerCameraRequestDialog extends StatelessWidget {
  const CustomerCameraRequestDialog({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final double side = MediaQuery.sizeOf(context).width >= 720 ? 24 : 18;
    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: side, vertical: 16),
      clipBehavior: Clip.antiAlias,
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return ConstrainedBox(
            key: const Key('camera-request-card'),
            constraints: BoxConstraints(
              maxWidth: 480,
              maxHeight: constraints.maxHeight,
            ),
            child: child,
          );
        },
      ),
    );
  }
}

class CustomerCameraDetailEntry extends StatelessWidget {
  const CustomerCameraDetailEntry({
    super.key,
    required this.bookingId,
    this.watchEntry,
    this.loadCamera,
    this.presentExternal,
    this.reloadDelay = cameraEntryReloadDelay,
  });

  final String bookingId;
  final Stream<CameraEntryWatch> Function(String bookingId)? watchEntry;
  final Future<CustomerRoomCameraResult> Function(String bookingId)? loadCamera;
  final CustomerCameraPresenter? presentExternal;
  final Duration reloadDelay;

  @override
  Widget build(BuildContext context) {
    return CustomerCameraGate(
      bookingId: bookingId,
      watchEntry: watchEntry,
      loadCamera: loadCamera,
      presentExternal: presentExternal,
      reloadDelay: reloadDelay,
      builder: (BuildContext context, CustomerCameraGateState state) {
        return customerCameraDetailRow(context, state);
      },
    );
  }
}

Widget customerCameraDetailRow(
  BuildContext context,
  CustomerCameraGateState state,
) {
  final CustomerRoomCameraResult? result = state.result;
  final CustomerCameraEntryPresentation presentation =
      customerCameraEntryPresentation(result);
  if (presentation.kind == CustomerCameraEntryKind.none) {
    return const SizedBox.shrink();
  }
  if (presentation.kind == CustomerCameraEntryKind.retry) {
    return BookingDetailEntryRow(
      icon: Icons.videocam_outlined,
      title: presentation.label,
      subtitle: '點一下重新讀取',
      onTap: state.retry,
    );
  }
  if (presentation.kind == CustomerCameraEntryKind.unsupported) {
    final String message = result?.message.trim().isNotEmpty == true
        ? result!.message.trim()
        : '此品牌尚未開放，不能改用其他品牌觀看。';
    return BookingDetailEntryRow(
      icon: Icons.videocam_outlined,
      title: presentation.label,
      subtitle: message,
      onTap: () => showUnsupportedCamera(context, message),
    );
  }
  final CustomerRoomCamera camera = result!.camera!;
  return BookingDetailEntryRow(
    icon: Icons.videocam_outlined,
    title: presentation.label,
    subtitle: customerCameraEntrySubtitle(
      viewMode: camera.viewMode,
      provider: camera.provider,
      appName: camera.appName,
    ),
    onTap: () => state.open(context),
  );
}

class CustomerCameraServiceButtons extends StatelessWidget {
  const CustomerCameraServiceButtons({
    super.key,
    required this.bookingId,
    required this.previewMode,
    required this.photoButton,
    this.watchEntry,
    this.loadCamera,
    this.presentExternal,
    this.reloadDelay = cameraEntryReloadDelay,
  });

  final String bookingId;
  final bool previewMode;
  final Widget? photoButton;
  final Stream<CameraEntryWatch> Function(String bookingId)? watchEntry;
  final Future<CustomerRoomCameraResult> Function(String bookingId)? loadCamera;
  final CustomerCameraPresenter? presentExternal;
  final Duration reloadDelay;

  @override
  Widget build(BuildContext context) {
    if (previewMode) {
      return _cameraServiceButtons(camera: null);
    }
    return CustomerCameraGate(
      bookingId: bookingId,
      watchEntry: watchEntry,
      loadCamera: loadCamera,
      presentExternal: presentExternal,
      reloadDelay: reloadDelay,
      builder: (BuildContext context, CustomerCameraGateState state) {
        final CustomerCameraEntryPresentation presentation =
            customerCameraEntryPresentation(state.result);
        final Widget? camera = switch (presentation.kind) {
          CustomerCameraEntryKind.none => null,
          CustomerCameraEntryKind.retry => OutlinedButton.icon(
            onPressed: state.retry,
            icon: const Icon(Icons.refresh),
            label: Text(
              presentation.label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          CustomerCameraEntryKind.unsupported => OutlinedButton.icon(
            onPressed: () =>
                showUnsupportedCamera(context, state.result?.message ?? ''),
            icon: const Icon(Icons.info_outline),
            label: Text(presentation.label),
          ),
          CustomerCameraEntryKind.ready => OutlinedButton.icon(
            onPressed: () => state.open(context),
            icon: const Icon(Icons.videocam_outlined),
            label: Text(presentation.label),
          ),
        };
        return _cameraServiceButtons(camera: camera);
      },
    );
  }

  Widget _cameraServiceButtons({required Widget? camera}) {
    if (photoButton == null && camera == null) {
      return const SizedBox.shrink();
    }
    if (photoButton == null) {
      return SizedBox(width: double.infinity, child: camera);
    }
    if (camera == null) {
      return SizedBox(width: double.infinity, child: photoButton);
    }
    return Row(
      children: <Widget>[
        Expanded(child: photoButton!),
        const SizedBox(width: 10),
        Expanded(child: camera),
      ],
    );
  }
}

Future<void> showUnsupportedCamera(BuildContext context, String message) {
  final String text = message.trim().isEmpty
      ? '此品牌尚未開放，不能改用其他品牌觀看。'
      : message.trim();
  return showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('品牌尚未開放'),
        content: Text(text),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      );
    },
  );
}

Future<void> _openWeb(BuildContext context, CustomerRoomCamera camera) async {
  final bool? confirm = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: const Text('前往外部攝影機頁面'),
        content: const Text(
          '即將開啟店家提供的攝影機連結。這個網址一旦被開啟或保存，PetNest 無法自動撤銷該網址本身的權限。',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('前往'),
          ),
        ],
      );
    },
  );
  if (confirm != true || !context.mounted) {
    return;
  }
  final Uri? uri = Uri.tryParse(camera.url.trim());
  if (uri == null || !cameraIsDirectHttps(camera.url)) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('攝影機網址無法開啟，請稍後再試')));
    return;
  }
  try {
    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('無法開啟攝影機連結')));
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('無法開啟攝影機連結')));
    }
  }
}

class _ExternalRequestSheet extends StatefulWidget {
  const _ExternalRequestSheet({required this.bookingId, required this.camera});

  final String bookingId;
  final CustomerRoomCamera camera;

  @override
  State<_ExternalRequestSheet> createState() => _ExternalRequestSheetState();
}

class _ExternalRequestSheetState extends State<_ExternalRequestSheet> {
  final TextEditingController _account = TextEditingController();
  late Stream<List<Map<String, dynamic>>> _requests;
  bool _submitting = false;
  bool _changingAccount = false;
  String? _error;
  bool _filled = false;

  @override
  void initState() {
    super.initState();
    _requests = _openStream();
  }

  Stream<List<Map<String, dynamic>>> _openStream() {
    return CameraAccessService.instance.watchMyRequests(
      shopId: widget.camera.shopId,
      bookingId: widget.bookingId,
    );
  }

  @override
  void dispose() {
    _account.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _requests,
      builder:
          (
            BuildContext context,
            AsyncSnapshot<List<Map<String, dynamic>>> snapshot,
          ) {
            final Widget body;
            if (snapshot.hasError) {
              body = Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                child: _ErrorNotice(
                  message: '分享申請讀取失敗，請再試一次',
                  onRetry: () => setState(() => _requests = _openStream()),
                ),
              );
            } else if (!snapshot.hasData) {
              body = const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Center(child: CircularProgressIndicator()),
              );
            } else {
              final Map<String, dynamic>? request = _currentRequest(
                snapshot.data ?? const <Map<String, dynamic>>[],
              );
              _rememberAccount(request);
              body = _sheet(request);
            }
            return CustomScrollView(
              shrinkWrap: true,
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.manual,
              slivers: <Widget>[
                PinnedHeaderSliver(child: _header()),
                SliverToBoxAdapter(child: body),
              ],
            );
          },
    );
  }

  Widget _header() {
    final String room = widget.camera.roomName.trim().isEmpty
        ? '房間'
        : widget.camera.roomName.trim();
    final String cameraName = widget.camera.name.trim().isEmpty
        ? widget.camera.providerLabel
        : widget.camera.name.trim();
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    room,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    cameraName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: '關閉',
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheet(Map<String, dynamic>? request) {
    final String status = (request?['status'] ?? '').toString();
    final bool showForm = request == null || _changingAccount;
    final bool canReplace =
        status == cameraRequestInvited || status == cameraRequestConfirmed;
    final CameraBrand? brand = cameraBrandById(widget.camera.provider);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _scrollBody(
            request: request,
            status: status,
            showForm: showForm,
            canReplace: canReplace,
            brand: brand,
          ),
          if (_error != null) ...<Widget>[
            const SizedBox(height: 8),
            CameraRequestFailureBanner(message: _error!),
          ],
          if (showForm && brand != null) ...<Widget>[
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submitting
                  ? null
                  : () => _submit(replacing: canReplace),
              child: Text(_submitting ? '送出中' : '送出申請'),
            ),
          ],
          if (!showForm && status == cameraRequestInvited) ...<Widget>[
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _submitting
                  ? null
                  : () {
                      _confirmWatching((request['id'] ?? '').toString());
                    },
              child: const Text('已可觀看'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _scrollBody({
    required Map<String, dynamic>? request,
    required String status,
    required bool showForm,
    required bool canReplace,
    required CameraBrand? brand,
  }) {
    final String accountLabel = brand?.accountLabel ?? '分享帳號';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          widget.camera.name,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          cameraExternalWatchReminder(widget.camera.provider),
          style: const TextStyle(height: 1.4),
        ),
        const SizedBox(height: 8),
        Text(
          '${widget.camera.bookingKindLabel}　${widget.camera.roomName}　${widget.camera.servicePeriodLabel}',
          style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
        ),
        if (widget.camera.customerShareNote.trim().isNotEmpty) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            '店家地區說明：${widget.camera.customerShareNote.trim()}',
            style: const TextStyle(fontSize: 13, height: 1.4),
          ),
        ],
        const SizedBox(height: 12),
        CameraBrandActions(providerId: widget.camera.provider),
        if (brand != null)
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('如何設定？'),
            children: <Widget>[
              for (final String step in brand.guide)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(step, style: const TextStyle(height: 1.35)),
                  ),
                ),
            ],
          ),
        if (request != null && !showForm) ...<Widget>[
          const SizedBox(height: 8),
          _StatusCard(status: status, request: request),
        ],
        if (showForm && brand != null) ...<Widget>[
          const SizedBox(height: 8),
          TextField(
            controller: _account,
            enabled: !_submitting,
            decoration: InputDecoration(
              labelText: accountLabel,
              helperText: brand.accountHint,
              helperMaxLines: 3,
            ),
          ),
        ],
        if ((status == cameraRequestNeedsInfo || canReplace) && !showForm)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () => setState(() {
                _changingAccount = true;
                _error = null;
              }),
              child: Text(
                status == cameraRequestNeedsInfo ? '修改後重新送出' : '更換分享帳號',
              ),
            ),
          ),
        if (status == cameraRequestInvited && !showForm)
          const Text(
            '這只表示你自行確認已在原廠 App 接受邀請，不代表系統已向原廠核對權限。',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
      ],
    );
  }

  Map<String, dynamic>? _currentRequest(List<Map<String, dynamic>> items) {
    final List<Map<String, dynamic>> matched = items.where((
      Map<String, dynamic> item,
    ) {
      final String roomId = (item['roomId'] ?? '').toString();
      final String deviceId = (item['deviceId'] ?? '').toString();
      final bool sameRoom = roomId == widget.camera.roomId;
      final bool sameDevice =
          deviceId.isEmpty || deviceId == widget.camera.deviceId;
      final String status = (item['status'] ?? '').toString();
      return sameRoom &&
          sameDevice &&
          status != cameraRequestClosed &&
          status != cameraRequestRevocationPending;
    }).toList();
    if (matched.isEmpty) {
      return null;
    }
    matched.sort((Map<String, dynamic> a, Map<String, dynamic> b) {
      return _millis(b['updatedAt']).compareTo(_millis(a['updatedAt']));
    });
    return matched.first;
  }

  void _rememberAccount(Map<String, dynamic>? request) {
    if (_filled || request == null || _account.text.isNotEmpty) {
      return;
    }
    final String account = (request['externalAccount'] ?? '').toString();
    if (account.isEmpty) {
      return;
    }
    _filled = true;
    _account.text = account;
  }

  Future<void> _submit({required bool replacing}) async {
    final String account = _account.text.trim();
    if (!plausibleCameraBrandAccount(widget.camera.provider, account)) {
      final CameraBrand? brand = cameraBrandById(widget.camera.provider);
      setState(() {
        _error = brand?.accountHint ?? '分享帳號格式不正確，且不會用其他品牌代替。';
      });
      return;
    }
    if (replacing) {
      final bool? ok = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('更換分享帳號'),
            content: const Text('舊帳號會保留為待取消分享，店家需要到原廠 App 移除權限。新帳號會另開一筆申請。'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('繼續'),
              ),
            ],
          );
        },
      );
      if (ok != true) {
        return;
      }
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await CameraAccessService.instance.submitRequest(
        bookingId: widget.bookingId,
        externalAccount: account,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _changingAccount = false;
        _error = null;
      });
    } on CameraAccessException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _error = error.message;
      });
    }
  }

  Future<void> _confirmWatching(String requestId) async {
    if (requestId.isEmpty) {
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await CameraAccessService.instance.confirmWatching(
        shopId: widget.camera.shopId,
        requestId: requestId,
      );
      if (mounted) {
        setState(() => _submitting = false);
      }
    } on CameraAccessException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitting = false;
        _error = error.message;
      });
    }
  }
}

int _millis(Object? value) {
  if (value is Timestamp) {
    return value.millisecondsSinceEpoch;
  }
  if (value is DateTime) {
    return value.millisecondsSinceEpoch;
  }
  return 0;
}

String _statusHint(String status) {
  switch (status) {
    case cameraRequestPending:
      return '等待店家在原廠 App 發送邀請。';
    case cameraRequestInvited:
      return '店家已記錄已發送邀請。請到原廠 App 接受邀請。這不代表系統已確認開通。';
    case cameraRequestConfirmed:
      return '你已自行確認可觀看。若要換帳號，舊帳號會留下取消分享待辦。';
    case cameraRequestNeedsInfo:
      return '請依店家說明修正後重新送出。';
    default:
      return '請依畫面狀態處理。';
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.status, required this.request});

  final String status;
  final Map<String, dynamic> request;

  @override
  Widget build(BuildContext context) {
    final String reason = (request['needsInfoReason'] ?? '').toString().trim();
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              cameraRequestStatusLabel(status),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(_statusHint(status), style: const TextStyle(height: 1.35)),
            if (status == cameraRequestNeedsInfo &&
                reason.isNotEmpty) ...<Widget>[
              const SizedBox(height: 6),
              Text('店家說明：$reason'),
            ],
          ],
        ),
      ),
    );
  }
}

class _ErrorNotice extends StatelessWidget {
  const _ErrorNotice({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(message),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: onRetry, child: const Text('重試')),
      ],
    );
  }
}
