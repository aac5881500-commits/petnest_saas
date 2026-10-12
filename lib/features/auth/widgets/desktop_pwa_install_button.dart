// 檔案名稱：lib/features/auth/widgets/desktop_pwa_install_button.dart
// 功能說明：店家管理電腦版的安裝狀態、安裝與解除安裝說明。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/services/pwa_install.dart';

Future<void> showShopDesktopAppDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) => const ShopDesktopAppDialog(),
  );
}

class ShopDesktopAppNavButton extends StatelessWidget {
  const ShopDesktopAppNavButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '安裝 PetNest 店家管理電腦版',
      child: TextButton.icon(
        onPressed: () => showShopDesktopAppDialog(context),
        icon: const Icon(Icons.install_desktop, size: 18),
        label: const Text('電腦版'),
      ),
    );
  }
}

class ShopDesktopAppDialog extends StatefulWidget {
  const ShopDesktopAppDialog({super.key, this.preview});

  /// 測試用狀態。正式畫面不傳入，改讀瀏覽器。
  final PwaInstallStatus? preview;

  @override
  State<ShopDesktopAppDialog> createState() => _ShopDesktopAppDialogState();
}

class _ShopDesktopAppDialogState extends State<ShopDesktopAppDialog> {
  PwaInstallStatus _status = PwaInstallStatus.unavailable;
  bool _busy = false;
  bool _showUninstall = false;

  bool get _macOS => defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void initState() {
    super.initState();
    final PwaInstallStatus? preview = widget.preview;
    if (preview != null) {
      _status = preview;
      return;
    }
    if (!kIsWeb) return;
    _status = PwaInstallBridge.read();
    PwaInstallBridge.listen(() {
      if (!mounted) return;
      setState(() => _status = PwaInstallBridge.read());
    });
  }

  Future<void> _install() async {
    if (_busy || widget.preview != null) return;
    setState(() => _busy = true);
    final String outcome = await PwaInstallBridge.promptInstall();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _status = PwaInstallBridge.read();
    });
    final String message = pwaInstallOutcomeMessage(outcome);
    if (message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _copy(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已複製。請自行貼到瀏覽器網址列，這個網頁無法直接打開該頁面。')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final double height = MediaQuery.sizeOf(context).height;
    return Dialog(
      backgroundColor: const Color(0xFFFFF8F0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 460, maxHeight: height * 0.86),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    tooltip: '關閉',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'PetNest 店家管理電腦版',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '專為店主與員工設計，快速進入店家管理後台。',
                style: TextStyle(color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              const Text(
                '將 PetNest 安裝到電腦後，可以從桌面、開始選單或工作列直接開啟，不需要每次開啟瀏覽器輸入網址。電腦版與網頁版使用相同帳號及資料，無須另外註冊。',
              ),
              const SizedBox(height: 12),
              const Text('支援 Windows 的 Chrome、Edge，以及 macOS 上支援安裝網站的瀏覽器。並非每個瀏覽器都能一鍵安裝。'),
              const SizedBox(height: 14),
              _StatusChip(label: pwaStatusLabel(_status)),
              const SizedBox(height: 14),
              if (_status.usingDesktopApp) ...<Widget>[
                const Text('如何開啟', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                for (final String line in pwaDesktopOpenHints)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('・$line'),
                  ),
              ] else if (_status.canInstallNow) ...<Widget>[
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _busy ? null : _install,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      backgroundColor: const Color(0xFFD4894C),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(_busy ? '請稍候' : '安裝店家管理電腦版'),
                  ),
                ),
              ] else ...<Widget>[
                const Text('安裝方式', style: TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(pwaInstallGuide(_status)),
                const SizedBox(height: 8),
                const Text('若你已經安裝過，請從桌面、開始選單或工作列自行開啟。這個網頁無法直接啟動已安裝的電腦版，也無法跨視窗確認安裝狀態。'),
              ],
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: () => setState(() => _showUninstall = !_showUninstall),
                icon: Icon(
                  _showUninstall ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: const Text('如何解除安裝？'),
              ),
              if (_showUninstall) ...<Widget>[
                Text(
                  pwaUninstallWarning,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final String step in pwaUninstallSteps(
                  browser: _status.browser,
                  macOS: _macOS,
                ))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('・$step'),
                  ),
                if (pwaAppsSettingsUrl(_status.browser) case final String url)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: OutlinedButton.icon(
                      onPressed: () => _copy(url),
                      icon: const Icon(Icons.copy, size: 16),
                      label: Text('複製 $url'),
                    ),
                  ),
                const SizedBox(height: 6),
                const Text('網站無法直接解除安裝，也不能替你打開瀏覽器的應用程式管理頁。'),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE7D3C4)),
      ),
      child: Text(label),
    );
  }
}
