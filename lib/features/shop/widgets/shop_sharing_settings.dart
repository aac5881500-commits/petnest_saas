import 'package:petnest_saas/features/shop/pages/shop_share_card_page.dart';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:petnest_saas/core/services/shop_sharing_service.dart';

typedef ShopSharingRequest =
    Future<Map<String, dynamic>> Function(String action, String searchCode);

class ShopSharingSettings extends StatefulWidget {
  const ShopSharingSettings({
    super.key,
    required this.shopId,
    this.editable = true,
    this.manageSharing,
  });
  final String shopId;
  final bool editable;
  final ShopSharingRequest? manageSharing;

  @override
  State<ShopSharingSettings> createState() => _ShopSharingSettingsState();
}

class _ShopSharingSettingsState extends State<ShopSharingSettings> {
  Map<String, dynamic>? _settings;
  bool _busy = false;
  bool _sharingImage = false;
  String? _error;
  String get _savedCode => _settings?['searchCode'] as String? ?? '';
  bool get _locked => _busy || _sharingImage;

  @override
  void initState() {
    super.initState();
    _run('get');
  }

  Future<bool> _run(String action, {String? searchCode}) async {
    if (_locked) return false;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final settings =
          await (widget.manageSharing?.call(action, searchCode ?? _savedCode) ??
              ShopSharingService.instance.manage(
                widget.shopId,
                action: action,
                searchCode: searchCode ?? _savedCode,
              ));
      if (!mounted) return false;
      setState(() => _settings = settings);
      if (action != 'get') {
        final message = switch (action) {
          'disable' => '已關閉分享入口',
          'rotate' => '已換成新的 QR Code，舊碼已失效',
          _ => '分享設定已儲存',
        };
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
      return true;
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = ShopSharingService.errorMessage(e));
    } catch (_) {
      if (mounted) setState(() => _error = '暫時無法連線，請稍後重試。');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    return false;
  }

  Future<void> _editCode() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _SearchCodeEditor(
        initialCode: _savedCode,
        onSave: (code) async {
          final saved = await _run('save', searchCode: code);
          return saved ? null : (_error ?? '無法儲存，請再試一次。');
        },
      ),
    );
  }

  Future<void> _confirm(String action) async {
    final rotate = action == 'rotate';
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(rotate ? '更換 QR Code？' : '關閉客人分享入口？'),
        content: Text(
          rotate
              ? '舊的 QR Code 與分享連結將失效，請把新的提供給客人。搜尋碼會保留，已進店的客人不受影響。'
              : '客人將無法再用這組 QR Code、連結或搜尋碼進店。已進店的客人會保留店家綁定，既有訂單不受影響。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(rotate ? '確認更換' : '確認關閉'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _run(action);
  }

  Future<void> _copy(String text, String message) async {
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('無法複製，請稍後再試。')));
      }
    }
  }

  Future<void> _shareImage(String link) async {
    if (_locked) return;
    setState(() => _sharingImage = true);
    try {
      final qr = await QrPainter(
        data: link,
        version: QrVersions.auto,
      ).toImage(800);
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      canvas.drawColor(Colors.white, ui.BlendMode.src);
      canvas.drawImage(qr, const Offset(40, 40), Paint());
      final picture = recorder.endRecording();
      final image = await picture.toImage(880, 880);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      qr.dispose();
      image.dispose();
      picture.dispose();
      if (bytes == null) throw StateError('QR image unavailable');
      await Share.shareXFiles([
        XFile.fromData(
          bytes.buffer.asUint8List(),
          mimeType: 'image/png',
          name: 'petnest_qr.png',
        ),
      ], text: link);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('無法分享圖片，請改用「複製進店連結」。')));
      }
    } finally {
      if (mounted) setState(() => _sharingImage = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final enabled = _settings?['enabled'] == true;
    final token = _settings?['qrToken'] as String? ?? '';
    final link = ShopSharingService.shareLink(token);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: .5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.qr_code_2_rounded, color: colors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '分享給客人',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '掃碼、傳連結，輕鬆進店',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '分享入口與平台公開分開設定，不會因為產生 QR Code 就公開店家。',
                      style: TextStyle(fontSize: 12, height: 1.5),
                    ),
                  ),
                ],
              ),
            ),
            if (_busy)
              const Padding(
                padding: EdgeInsets.only(top: 16),
                child: LinearProgressIndicator(),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: TextStyle(color: colors.error)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _locked ? null : () => _run('get'),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('重新讀取'),
                ),
              ),
            ],
            if (_settings != null && enabled && token.isNotEmpty) ...[
              const SizedBox(height: 20),
              Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEDF7F1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 15,
                        color: Color(0xFF2E7453),
                      ),
                      SizedBox(width: 6),
                      Text(
                        '客人分享已啟用',
                        style: TextStyle(
                          color: Color(0xFF2E7453),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  color: Colors.white,
                  child: LayoutBuilder(
                    builder: (context, constraints) => QrImageView(
                      data: link,
                      size: min(184, constraints.maxWidth - 24).toDouble(),
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '讓客人掃描，或直接傳送下方連結',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: colors.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _locked ? null : () => _shareImage(link),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                icon: Icon(
                  _sharingImage ? Icons.hourglass_top : Icons.ios_share,
                  size: 18,
                ),
                label: Text(_sharingImage ? '正在準備圖片…' : '分享 QR 圖片'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _locked
                    ? null
                    : () => _copy(link, '已複製進店連結，可以傳給客人了'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                ),
                icon: const Icon(Icons.link, size: 18),
                label: const Text('複製網頁進店網址'),
              ),
              const SizedBox(height: 6),
              Text(
                '給網頁版或未下載 APP 的客人，點網址就能進店。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: colors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _locked
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ShopShareCardPage(
                            shopId: widget.shopId,
                            link: link,
                            searchCode: _savedCode,
                          ),
                        ),
                      ),
                icon: const Icon(Icons.contact_page_outlined, size: 18),
                label: const Text('製作分享卡・列印／傳 LINE'),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 18),
                child: Divider(height: 1),
              ),
              Row(
                children: [
                  Icon(
                    Icons.keyboard_alt_outlined,
                    size: 20,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      '手機 APP 搜尋碼',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (widget.editable)
                    TextButton(
                      onPressed: _locked ? null : _editCode,
                      child: Text(_savedCode.isEmpty ? '設定' : '修改'),
                    ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: colors.primaryContainer.withValues(alpha: .22),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colors.primary.withValues(alpha: .15),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_savedCode.isEmpty) ...[
                      Text(
                        '尚未設定搜尋碼',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: colors.primary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '選填。已下載 APP 的客人，可用這組碼找到你的店。',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ] else ...[
                      Row(
                        children: [
                          Expanded(
                            child: SelectableText(
                              _savedCode,
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                                color: colors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _locked
                                ? null
                                : () => _copy(_savedCode, '已複製搜尋碼'),
                            tooltip: '複製搜尋碼',
                            icon: const Icon(Icons.copy_outlined, size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '客人在 APP 的「掃描店家」選擇手動輸入即可進店。',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (widget.editable) ...[
                const SizedBox(height: 12),
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: Text(
                      '更多分享設定',
                      style: TextStyle(
                        fontSize: 13,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.refresh_rounded),
                        title: const Text('更換 QR Code'),
                        subtitle: const Text('舊 QR 與連結將失效'),
                        onTap: _locked ? null : () => _confirm('rotate'),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(Icons.link_off, color: colors.error),
                        title: Text(
                          '關閉分享入口',
                          style: TextStyle(color: colors.error),
                        ),
                        subtitle: const Text('停用 QR、連結與搜尋碼'),
                        onTap: _locked ? null : () => _confirm('disable'),
                      ),
                    ],
                  ),
                ),
              ],
            ] else if (_settings != null) ...[
              const SizedBox(height: 24),
              Icon(Icons.qr_code_rounded, size: 56, color: colors.outline),
              const SizedBox(height: 12),
              const Text(
                '建立客人專屬入口',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '產生後就能分享給客人；搜尋碼可稍後再設定。',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: colors.onSurfaceVariant,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.editable)
                FilledButton.icon(
                  onPressed: _locked ? null : () => _run('save'),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('產生專屬 QR Code'),
                ),
            ],
            const SizedBox(height: 16),
            Text(
              '本區操作獨立儲存，不需另外儲存營業資訊。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchCodeEditor extends StatefulWidget {
  const _SearchCodeEditor({required this.initialCode, required this.onSave});
  final String initialCode;
  final Future<String?> Function(String code) onSave;
  @override
  State<_SearchCodeEditor> createState() => _SearchCodeEditorState();
}

class _SearchCodeEditorState extends State<_SearchCodeEditor> {
  late final _controller = TextEditingController(text: widget.initialCode);
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final code = _controller.text.trim().toUpperCase();
    if (code.isNotEmpty && ShopSharingService.parse(code) != code) {
      setState(() => _error = '請使用 8–32 位英文字母、數字、_ 或 -，不要使用 SHOP 流水號。');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final error = await widget.onSave(code);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '設定手動搜尋碼',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  tooltip: '取消設定',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Text(
              '提供給不方便掃碼的客人。在 APP 選擇手動輸入後，輸入這組碼就能進店。',
              style: TextStyle(fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _controller,
              enabled: !_saving,
              maxLength: 32,
              textCapitalization: TextCapitalization.characters,
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(
                labelText: '搜尋碼',
                hintText: '例如：CATSTAY_2026',
                helperText: '8–32 位英文、數字、_ 或 -；留空可移除搜尋碼。',
                helperMaxLines: 2,
                errorText: _error,
                errorMaxLines: 4,
                border: const OutlineInputBorder(),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _saving
                    ? null
                    : () {
                        const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
                        final random = Random.secure();
                        _controller.text = List.generate(
                          12,
                          (_) => chars[random.nextInt(chars.length)],
                        ).join();
                        setState(() => _error = null);
                      },
                icon: const Icon(Icons.shuffle, size: 18),
                label: const Text('幫我產生一組'),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '搜尋碼全平台唯一，英文字母不分大小寫。儲存時會檢查重複；設定或移除後立即生效，已進店的客人不會被登出。',
              style: TextStyle(fontSize: 12, height: 1.6),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(46),
              ),
              child: Text(_saving ? '儲存中…' : '儲存搜尋碼'),
            ),
          ],
        ),
      ),
    ),
  );
}
