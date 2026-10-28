import 'dart:ui' as ui;
import 'package:share_plus/share_plus.dart';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:petnest_saas/core/services/shop_sharing_service.dart';

class ShopSharingSettings extends StatefulWidget {
  const ShopSharingSettings({
    super.key,
    required this.shopId,
    this.editable = true,
  });
  final String shopId;
  final bool editable;
  @override
  State<ShopSharingSettings> createState() => _ShopSharingSettingsState();
}

class _ShopSharingSettingsState extends State<ShopSharingSettings> {
  final _code = TextEditingController();
  Map<String, dynamic>? _settings;
  bool _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _run('get');
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _run(String action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final settings = await ShopSharingService.instance.manage(
        widget.shopId,
        action: action,
        searchCode: _code.text,
      );
      if (!mounted) return;
      setState(() {
        _settings = settings;
        _code.text = settings['searchCode'] as String? ?? '';
      });
      if (action != 'get') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('分享設定已立即儲存')));
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) setState(() => _error = e.message ?? '無法更新分享設定，請重試');
    } catch (_) {
      if (mounted) setState(() => _error = '無法連線，請重試');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm(String action) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(action == 'rotate' ? '重新產生 QR Code？' : '關閉分享入口？'),
        content: Text(
          action == 'rotate'
              ? '舊 QR Code 將失效，請將新的 QR Code 提供給客人。'
              : 'QR Code 與搜尋碼將無法使用；已建立的訂單不受影響。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('確定'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) await _run(action);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _settings?['enabled'] == true;
    final token = _settings?['qrToken'] as String? ?? '';
    final link = ShopSharingService.shareLink(token);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('搜尋碼與 QR Code', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text('未公開店家不會出現在平台找店。請將專屬 QR Code 或搜尋碼提供給客人。此區設定會立即儲存。'),
            if (_busy)
              const Padding(
                padding: EdgeInsets.all(16),
                child: LinearProgressIndicator(),
              ),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: _busy ? null : () => _run('get'),
                child: const Text('重新讀取'),
              ),
            ],
            if (_settings != null) ...[
              const SizedBox(height: 16),
              Text(enabled ? '分享入口已啟用' : '分享入口尚未啟用或已關閉'),
              if (widget.editable) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _code,
                  enabled: !_busy,
                  maxLength: 32,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: '自訂搜尋碼（可留空，僅使用 QR Code）',
                    helperText: '8–32 位英文、數字、_ 或 -；請避免容易猜中的組合',
                    helperMaxLines: 3,
                    border: OutlineInputBorder(),
                  ),
                ),
                TextButton.icon(
                  onPressed: _busy
                      ? null
                      : () {
                          const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
                          final random = Random.secure();
                          _code.text = List.generate(
                            12,
                            (_) => chars[random.nextInt(chars.length)],
                          ).join();
                        },
                  icon: const Icon(Icons.shuffle),
                  label: const Text('隨機產生搜尋碼'),
                ),
                FilledButton(
                  onPressed: _busy ? null : () => _run('save'),
                  child: Text(enabled ? '儲存搜尋碼' : '產生專屬 QR Code 並啟用分享'),
                ),
              ],
              if (enabled && token.isNotEmpty) ...[
                const SizedBox(height: 16),
                Center(
                  child: Container(
                    color: Colors.white,
                    padding: const EdgeInsets.all(12),
                    child: QrImageView(
                      data: link,
                      size: 220,
                      backgroundColor: Colors.white,
                    ),
                  ),
                ),
                if ((_settings?['searchCode'] as String? ?? '').isNotEmpty)
                  SelectableText(
                    '搜尋碼：${_settings!['searchCode']}',
                    textAlign: TextAlign.center,
                  ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          try {
                            final qr = await QrPainter(
                              data: link,
                              version: QrVersions.auto,
                            ).toImage(800);
                            final recorder = ui.PictureRecorder();
                            final canvas = ui.Canvas(recorder);
                            canvas.drawColor(
                              const Color(0xFFFFFFFF),
                              ui.BlendMode.src,
                            );
                            canvas.drawImage(qr, const Offset(40, 40), Paint());
                            final picture = recorder.endRecording();
                            final image = await picture.toImage(880, 880);
                            final bytes = await image.toByteData(
                              format: ui.ImageByteFormat.png,
                            );
                            qr.dispose();
                            image.dispose();
                            picture.dispose();
                            if (bytes == null) {
                              throw StateError('QR image unavailable');
                            }
                            await Share.shareXFiles([
                              XFile.fromData(
                                bytes.buffer.asUint8List(),
                                mimeType: 'image/png',
                                name: 'petnest_qr.png',
                              ),
                            ], text: link);
                          } catch (_) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('無法分享圖片，請使用複製分享連結'),
                                ),
                              );
                            }
                          }
                        },
                  icon: const Icon(Icons.share),
                  label: const Text('分享 QR Code 圖片'),
                ),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          await Clipboard.setData(ClipboardData(text: link));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('已複製專屬分享連結')),
                            );
                          }
                        },
                  icon: const Icon(Icons.copy),
                  label: const Text('複製 QR Code 分享連結'),
                ),
                if (widget.editable) ...[
                  TextButton(
                    onPressed: _busy ? null : () => _confirm('rotate'),
                    child: const Text('重新產生 QR Code（舊碼失效）'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _confirm('disable'),
                    child: const Text('關閉 QR Code 與搜尋碼'),
                  ),
                ],
              ],
            ],
          ],
        ),
      ),
    );
  }
}
