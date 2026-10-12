import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/pwa_install_status.dart';
import 'package:petnest_saas/features/auth/widgets/desktop_pwa_install_button.dart';

void main() {
  test('只有獨立視窗才算正在使用電腦版', () {
    const PwaInstallStatus status = PwaInstallStatus(
      standalone: true,
      canPrompt: false,
      rememberedInstalled: false,
      secureContext: true,
      browser: 'chrome',
    );
    expect(status.usingDesktopApp, isTrue);
    expect(pwaStatusLabel(status), '目前正在使用電腦版');
  });

  test('沒有安裝提示或舊紀錄，都不視為已安裝', () {
    const PwaInstallStatus remembered = PwaInstallStatus(
      standalone: false,
      canPrompt: false,
      rememberedInstalled: true,
      secureContext: true,
      browser: 'edge',
    );
    const PwaInstallStatus prompt = PwaInstallStatus(
      standalone: false,
      canPrompt: true,
      rememberedInstalled: true,
      secureContext: true,
      browser: 'edge',
    );
    expect(remembered.usingDesktopApp, isFalse);
    expect(remembered.canInstallNow, isFalse);
    expect(pwaStatusLabel(remembered), '無法從這個視窗確認安裝狀態');
    expect(prompt.canInstallNow, isTrue);
    expect(pwaInstallOutcomeMessage('dismissed'), '已取消安裝，沒有變更。');
    expect(pwaInstallOutcomeMessage('unavailable'), isEmpty);
  });

  test('各瀏覽器說明不宣稱都能一鍵安裝', () {
    const List<String> browsers = <String>[
      'chrome',
      'edge',
      'safari',
      'firefox',
      'other',
    ];
    for (final String browser in browsers) {
      final String guide = pwaInstallGuide(
        PwaInstallStatus(
          standalone: false,
          canPrompt: false,
          rememberedInstalled: false,
          secureContext: true,
          browser: browser,
        ),
      );
      expect(guide.contains('所有瀏覽器'), isFalse);
      expect(guide, isNotEmpty);
    }
    expect(
      pwaInstallGuide(
        const PwaInstallStatus(
          standalone: false,
          canPrompt: false,
          rememberedInstalled: false,
          secureContext: true,
          browser: 'safari',
        ),
      ),
      contains('加入 Dock'),
    );
    expect(
      pwaInstallGuide(
        const PwaInstallStatus(
          standalone: false,
          canPrompt: false,
          rememberedInstalled: false,
          secureContext: false,
          browser: 'chrome',
        ),
      ),
      contains('https'),
    );
  });

  test('解除安裝步驟依瀏覽器區分，且不刪除帳號資料', () {
    expect(pwaUninstallWarning, contains('不會刪除 PetNest 帳號'));
    expect(
      pwaUninstallSteps(browser: 'edge', macOS: false).join('\n'),
      contains('edge://apps'),
    );
    expect(
      pwaUninstallSteps(browser: 'chrome', macOS: true).join('\n'),
      contains('chrome://apps'),
    );
    expect(
      pwaUninstallSteps(browser: 'safari', macOS: true).join('\n'),
      contains('從 Dock 移除'),
    );
    expect(pwaAppsSettingsUrl('edge'), 'edge://apps');
    expect(pwaAppsSettingsUrl('safari'), isNull);
  });

  testWidgets('可安裝時顯示安裝按鈕，並可展開解除安裝說明', (WidgetTester tester) async {
    await _wideSurface(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: ShopDesktopAppDialog(
          preview: PwaInstallStatus(
            standalone: false,
            canPrompt: true,
            rememberedInstalled: false,
            secureContext: true,
            browser: 'edge',
          ),
        ),
      ),
    );
    expect(find.text('安裝店家管理電腦版'), findsOneWidget);
    expect(find.text('尚未安裝'), findsOneWidget);
    await tester.tap(find.text('如何解除安裝？'));
    await tester.pumpAndSettle();
    expect(find.textContaining('不會刪除 PetNest 帳號'), findsOneWidget);
    expect(find.textContaining('edge://apps'), findsWidgets);
    await tester.tap(find.text('安裝店家管理電腦版'));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  testWidgets('沒有安裝事件時不顯示無效按鈕', (WidgetTester tester) async {
    await _wideSurface(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: ShopDesktopAppDialog(
          preview: PwaInstallStatus(
            standalone: false,
            canPrompt: false,
            rememberedInstalled: true,
            secureContext: true,
            browser: 'chrome',
          ),
        ),
      ),
    );
    expect(find.text('安裝店家管理電腦版'), findsNothing);
    expect(find.textContaining('Chrome 目前沒有跳出安裝確認'), findsOneWidget);
    expect(find.text('目前正在使用電腦版'), findsNothing);
  });

  testWidgets('獨立視窗顯示開啟與釘選說明', (WidgetTester tester) async {
    await _wideSurface(tester);
    await tester.pumpWidget(
      const MaterialApp(
        home: ShopDesktopAppDialog(
          preview: PwaInstallStatus(
            standalone: true,
            canPrompt: false,
            rememberedInstalled: true,
            secureContext: true,
            browser: 'edge',
          ),
        ),
      ),
    );
    expect(find.text('目前正在使用電腦版'), findsOneWidget);
    expect(find.textContaining('釘選到工作列'), findsOneWidget);
    expect(find.text('安裝店家管理電腦版'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('導覽列電腦版按鈕開啟同一個安裝視窗，窄桌機寬度不溢位', (
    WidgetTester tester,
  ) async {
    await _wideSurface(tester, const Size(1100, 700));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          appBar: AppBar(
            toolbarHeight: 64,
            title: const SizedBox(width: 60, height: 40),
            actions: <Widget>[
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.search, size: 18),
                label: const Text('找店'),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add_business, size: 18),
                label: const Text('開店'),
              ),
              const ShopDesktopAppNavButton(),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.notifications_outlined),
              ),
              TextButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.admin_panel_settings, size: 18),
                label: const Text('平台後台'),
              ),
              const CircleAvatar(
                radius: 16,
                child: Icon(Icons.person, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
    expect(find.text('電腦版'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('電腦版'));
    await tester.pumpAndSettle();
    expect(find.text('PetNest 店家管理電腦版'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<void> _wideSurface(
  WidgetTester tester, [
  Size size = const Size(520, 900),
]) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
