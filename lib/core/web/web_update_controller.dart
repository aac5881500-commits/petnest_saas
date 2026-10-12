// 檔案名稱：lib/core/web/web_update_controller.dart
// 功能說明：在開啟、回到視窗與固定間隔時比對部署版本，並記住已略過的提示。

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:petnest_saas/core/web/web_build_info.dart';
import 'package:petnest_saas/core/web/web_build_stamp.dart';
import 'package:petnest_saas/core/web/web_update_client.dart';

class WebUpdateController extends ChangeNotifier {
  WebUpdateController({
    required this.client,
    required this.localBuildId,
    this.interval = const Duration(minutes: 30),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  static final WebUpdateController instance = WebUpdateController(
    client: createWebUpdateClient(),
    localBuildId: kWebBuildId,
  );

  final WebUpdateClient client;
  final String localBuildId;
  final Duration interval;
  final DateTime Function() _now;

  WebUpdatePhase phase = WebUpdatePhase.idle;
  WebBuildInfo? remote;
  String? dismissedBuildId;

  Timer? _timer;
  Future<void>? _inFlight;
  bool _started = false;
  DateTime _lastCheck = DateTime.fromMillisecondsSinceEpoch(0);

  bool get showPrompt =>
      phase == WebUpdatePhase.updateAvailable &&
      remote != null &&
      dismissedBuildId != remote!.buildId;

  void start() {
    if (!kIsWeb || _started) return;
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      check();
    });
    _timer = Timer.periodic(interval, (_) => check());
  }

  void onResumed() {
    if (!_started) return;
    if (_now().difference(_lastCheck) < const Duration(seconds: 20)) return;
    check();
  }

  Future<void> check({bool manual = false}) {
    final Future<void>? current = _inFlight;
    if (current != null) return current;
    final Future<void> task = _check(manual: manual);
    _inFlight = task;
    return task.whenComplete(() {
      if (identical(_inFlight, task)) _inFlight = null;
    });
  }

  void dismissPrompt() {
    final String? buildId = remote?.buildId;
    if (buildId == null || dismissedBuildId == buildId) return;
    dismissedBuildId = buildId;
    notifyListeners();
  }

  Future<void> applyUpdate() => client.applyUpdate();

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _check({required bool manual}) async {
    if (!tracksWebDeployment(localBuildId)) {
      if (!manual) return;
      phase = WebUpdatePhase.development;
      remote = null;
      notifyListeners();
      return;
    }
    _lastCheck = _now();
    phase = WebUpdatePhase.checking;
    notifyListeners();
    final WebBuildInfo? latest = await client.fetchRemote();
    if (latest == null) {
      phase = WebUpdatePhase.failed;
      notifyListeners();
      return;
    }
    remote = latest;
    if (latest.buildId == localBuildId) {
      phase = WebUpdatePhase.current;
      dismissedBuildId = null;
    } else {
      phase = WebUpdatePhase.updateAvailable;
    }
    notifyListeners();
  }
}
