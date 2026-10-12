import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/web/web_build_info.dart';
import 'package:petnest_saas/core/web/web_update_client_stub.dart';
import 'package:petnest_saas/core/web/web_update_controller.dart';
import 'package:petnest_saas/core/web/web_update_prompt.dart';
import 'package:petnest_saas/features/auth/widgets/desktop_pwa_install_button.dart';
import 'package:petnest_saas/core/services/pwa_install_status.dart';

void main() {
  test('沒有部署識別碼的內容不算新版本', () {
    expect(parseWebBuildInfo('{"version":"1.0.1","build_number":"4"}'), isNull);
    expect(parseWebBuildInfo('{'), isNull);
    expect(
      parseWebBuildInfo('{"buildId":"20261012T000000Z-abcd1234","builtAt":"2026-10-12T00:00:00Z"}')
          ?.buildId,
      '20261012T000000Z-abcd1234',
    );
  });

  test('版本相同不提示，失敗不提示，開發版不和正式站比較', () async {
    final _FakeClient same = _FakeClient(
      remote: const WebBuildInfo(buildId: 'build-a', builtAt: 't'),
    );
    final WebUpdateController current = WebUpdateController(
      client: same,
      localBuildId: 'build-a',
    );
    await current.check();
    expect(current.phase, WebUpdatePhase.current);
    expect(current.showPrompt, isFalse);

    final WebUpdateController failed = WebUpdateController(
      client: _FakeClient(remote: null),
      localBuildId: 'build-a',
    );
    await failed.check();
    expect(failed.phase, WebUpdatePhase.failed);
    expect(failed.showPrompt, isFalse);

    final WebUpdateController dev = WebUpdateController(
      client: _FakeClient(
        remote: const WebBuildInfo(buildId: 'build-b', builtAt: 't'),
      ),
      localBuildId: 'dev',
    );
    await dev.check();
    expect(dev.phase, WebUpdatePhase.idle);
    await dev.check(manual: true);
    expect(dev.phase, WebUpdatePhase.development);
    expect(dev.showPrompt, isFalse);
    expect(dev.client, isA<_FakeClient>());
    expect((_FakeClient.of(dev)).fetches, 0);
  });

  test('同一新版本略過後不再跳出，另一個版本才會再提示', () async {
    final _FakeClient client = _FakeClient(
      remote: const WebBuildInfo(buildId: 'build-b', builtAt: 't'),
    );
    final WebUpdateController controller = WebUpdateController(
      client: client,
      localBuildId: 'build-a',
    );
    await controller.check();
    expect(controller.showPrompt, isTrue);
    expect(webUpdatePhaseLabel(controller.phase), '發現新版本');
    controller.dismissPrompt();
    expect(controller.showPrompt, isFalse);
    await controller.check();
    expect(controller.showPrompt, isFalse);
    client.remote = const WebBuildInfo(buildId: 'build-c', builtAt: 't2');
    await controller.check();
    expect(controller.showPrompt, isTrue);
  });

  test('檢查進行中不會再發第二次請求', () async {
    final _GateClient client = _GateClient();
    final WebUpdateController controller = WebUpdateController(
      client: client,
      localBuildId: 'build-a',
    );
    final Future<void> first = controller.check();
    final Future<void> second = controller.check(manual: true);
    client.finish(const WebBuildInfo(buildId: 'build-a', builtAt: 't'));
    await Future.wait(<Future<void>>[first, second]);
    expect(client.fetches, 1);
    expect(controller.phase, WebUpdatePhase.current);
  });

  testWidgets('稍後再說後可以繼續操作，確認前不會重新載入', (WidgetTester tester) async {
    final _FakeClient client = _FakeClient(
      remote: const WebBuildInfo(buildId: 'build-b', builtAt: 't'),
    );
    final WebUpdateController controller = WebUpdateController(
      client: client,
      localBuildId: 'build-a',
    );
    await controller.check();
    await _surface(tester, const Size(1100, 800));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebUpdateOverlay(
            enabled: true,
            controller: controller,
            child: const Text('店家內容'),
          ),
        ),
      ),
    );
    expect(find.text('PetNest 有新版本'), findsOneWidget);
    expect(find.text('店家內容'), findsOneWidget);
    await tester.tap(find.text('稍後再說'));
    await tester.pump();
    expect(find.text('PetNest 有新版本'), findsNothing);
    expect(find.text('店家內容'), findsOneWidget);
    expect(client.applies, 0);
  });

  testWidgets('確認後才執行更新，手機寬度不溢位', (WidgetTester tester) async {
    final _FakeClient client = _FakeClient(
      remote: const WebBuildInfo(buildId: 'build-b', builtAt: 't'),
    );
    final WebUpdateController controller = WebUpdateController(
      client: client,
      localBuildId: 'build-a',
    );
    await controller.check();
    await _surface(tester, const Size(390, 800));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: WebUpdateOverlay(
            enabled: true,
            controller: controller,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();
    expect(find.textContaining('無法確認每一個畫面是否都已儲存'), findsOneWidget);
    expect(client.applies, 0);
    await tester.tap(find.text('返回'));
    await tester.pumpAndSettle();
    expect(client.applies, 0);
    await tester.tap(find.text('立即更新'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('仍要更新'));
    await tester.pumpAndSettle();
    expect(client.applies, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('電腦版視窗可以手動檢查，安裝狀態與版本狀態分開', (WidgetTester tester) async {
    final _FakeClient client = _FakeClient(
      remote: const WebBuildInfo(buildId: 'build-a', builtAt: 't'),
    );
    final WebUpdateController controller = WebUpdateController(
      client: client,
      localBuildId: 'build-a',
    );
    await _surface(tester, const Size(520, 900));
    await tester.pumpWidget(
      MaterialApp(
        home: ShopDesktopAppDialog(
          preview: const PwaInstallStatus(
            standalone: true,
            canPrompt: false,
            rememberedInstalled: true,
            secureContext: true,
            browser: 'edge',
          ),
          updates: controller,
        ),
      ),
    );
    expect(find.text('目前正在使用電腦版'), findsOneWidget);
    expect(find.text('尚未檢查'), findsOneWidget);
    expect(find.text('已是最新版本'), findsNothing);
    await tester.tap(find.text('檢查更新'));
    await tester.pump();
    expect(find.text('已是最新版本'), findsOneWidget);
    expect(find.text('目前正在使用電腦版'), findsOneWidget);
    expect(find.text('立即更新'), findsNothing);
  });
}

class _FakeClient implements WebUpdateClient {
  _FakeClient({required this.remote});

  WebBuildInfo? remote;
  int fetches = 0;
  int applies = 0;

  static _FakeClient of(WebUpdateController controller) {
    return controller.client as _FakeClient;
  }

  @override
  Future<void> applyUpdate() async {
    applies += 1;
  }

  @override
  Future<WebBuildInfo?> fetchRemote() async {
    fetches += 1;
    return remote;
  }
}

class _GateClient implements WebUpdateClient {
  final Completer<WebBuildInfo?> gate = Completer<WebBuildInfo?>();
  int fetches = 0;

  void finish(WebBuildInfo? value) {
    if (!gate.isCompleted) gate.complete(value);
  }

  @override
  Future<void> applyUpdate() async {}

  @override
  Future<WebBuildInfo?> fetchRemote() {
    fetches += 1;
    return gate.future;
  }
}

Future<void> _surface(WidgetTester tester, Size size) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

