// 檔案名稱：lib/core/services/pwa_install_status.dart
// 功能說明：判斷店家管理電腦版的安裝狀態，以及各瀏覽器的安裝與移除說明。

class PwaInstallStatus {
  const PwaInstallStatus({
    required this.standalone,
    required this.canPrompt,
    required this.rememberedInstalled,
    required this.secureContext,
    required this.browser,
  });

  final bool standalone;
  final bool canPrompt;
  final bool rememberedInstalled;
  final bool secureContext;
  final String browser;

  static const PwaInstallStatus unavailable = PwaInstallStatus(
    standalone: false,
    canPrompt: false,
    rememberedInstalled: false,
    secureContext: true,
    browser: 'other',
  );

  /// 只有正在 PWA 獨立視窗時，才能確認正在使用電腦版。
  /// 沒有安裝提示，不代表已經安裝。
  bool get usingDesktopApp => standalone;

  bool get canInstallNow => canPrompt && !standalone;
}

String pwaStatusLabel(PwaInstallStatus status) {
  if (status.usingDesktopApp) return '目前正在使用電腦版';
  if (status.canInstallNow) return '尚未安裝';
  return '無法從這個視窗確認安裝狀態';
}

String pwaInstallGuide(PwaInstallStatus status) {
  if (!status.secureContext) {
    return '這個網址不是安全連線，瀏覽器不會提供安裝。請改用正式的 https 網址。本機 localhost 可以安裝。';
  }
  switch (status.browser) {
    case 'edge':
      return 'Edge 目前沒有跳出安裝確認。請點右上角「…」＞「應用程式」＞「將此網站安裝為應用程式」。安裝後可釘選工作列或放到桌面。';
    case 'chrome':
      return 'Chrome 目前沒有跳出安裝確認。請點網址列右側的安裝圖示，或右上角「⋮」＞「安裝 PetNest」。安裝後可釘選工作列或放到桌面。';
    case 'safari':
      return 'Safari 沒有與 Chrome 相同的一鍵安裝。在 macOS 可使用選單「檔案」＞「加入 Dock」。';
    case 'firefox':
      return 'Firefox 不提供一鍵安裝。請改用 Chrome 或 Edge 開啟 PetNest 後再安裝。';
    default:
      return '這個瀏覽器沒有提供一鍵安裝。請改用 Windows 的 Chrome 或 Edge，或 macOS 上支援安裝網站的瀏覽器。';
  }
}

const String pwaUninstallWarning =
    '解除安裝只會移除這台電腦的應用程式，不會刪除 PetNest 帳號、店家、訂單或雲端資料。';

String? pwaAppsSettingsUrl(String browser) {
  switch (browser) {
    case 'edge':
      return 'edge://apps';
    case 'chrome':
      return 'chrome://apps';
    default:
      return null;
  }
}

List<String> pwaUninstallSteps({
  required String browser,
  required bool macOS,
}) {
  if (browser == 'safari') {
    return const <String>[
      '在 Dock 上對 PetNest 按住 Control 並點一下。',
      '選擇「選項」，再選擇「從 Dock 移除」。',
      '若「應用程式」或 Launchpad 裡也有 PetNest，把它移到垃圾桶。',
    ];
  }
  if (browser == 'edge') {
    return <String>[
      '開啟 Microsoft Edge。',
      '在網址列輸入 edge://apps。',
      '找到 PetNest。',
      '進入詳細資料或選單。',
      '選擇解除安裝。',
      if (macOS) '在 Mac 上也可以從 Dock 移除圖示，並到「應用程式」資料夾刪除對應項目。',
    ];
  }
  if (browser == 'chrome') {
    return <String>[
      '開啟 Google Chrome。',
      '在網址列輸入 chrome://apps。',
      '找到 PetNest。',
      '使用應用程式選單移除，或依你目前的 Chrome 版本選擇解除安裝。',
      if (macOS) '在 Mac 上也可以從 Dock 移除圖示，並到「應用程式」資料夾刪除對應項目。',
    ];
  }
  return const <String>[
    '請用當初安裝時的瀏覽器，依該瀏覽器的應用程式清單或 Dock 移除 PetNest。',
    '網站無法代替你完成解除安裝。',
  ];
}

String pwaInstallOutcomeMessage(String outcome) {
  if (outcome == 'accepted') {
    return '已開始安裝 PetNest。完成後可從桌面、開始選單或工作列開啟。';
  }
  if (outcome == 'dismissed') return '已取消安裝，沒有變更。';
  return '';
}

const List<String> pwaDesktopOpenHints = <String>[
  '之後從桌面、開始選單或工作列的 PetNest 圖示開啟即可。',
  'Windows 可在開始選單對 PetNest 按右鍵，選擇「釘選到工作列」。',
  'macOS 可從 Dock 或「應用程式」開啟。',
  '這個網頁無法直接啟動已安裝的電腦版。',
];
