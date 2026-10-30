import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'package:petnest_saas/core/services/shop_share_card_output.dart';

class ShopShareCardPage extends StatefulWidget {
  const ShopShareCardPage({
    super.key,
    required this.shopId,
    required this.link,
    required this.searchCode,
    this.loadShopName,
  });
  final String shopId;
  final String link;
  final String searchCode;
  final Future<String> Function()? loadShopName;
  @override
  State<ShopShareCardPage> createState() => _ShopShareCardPageState();
}

class _ShopShareCardPageState extends State<ShopShareCardPage> {
  final _captureKey = GlobalKey();
  late Future<String> _name = _loadName();
  bool _busy = false;
  Future<String> _loadName() async {
    if (widget.loadShopName != null) return widget.loadShopName!();
    final shop = await ShopService.instance.getShop(widget.shopId);
    if (shop == null) throw StateError('Shop unavailable');
    return (shop['name'] as String?)?.trim().isNotEmpty == true
        ? shop['name'] as String
        : '店家專屬入口';
  }

  Future<Uint8List> _capture() async {
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) throw StateError('Share card closed');
    final boundary =
        _captureKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(
      pixelRatio: 1080 / boundary.size.width,
    );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    if (data == null) throw StateError('Share card unavailable');
    return data.buffer.asUint8List();
  }

  Future<void> _output(String action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (action == 'print') {
        await printShopShareCard(_capture);
      } else {
        final bytes = await _capture();
        if (action == 'download') {
          await downloadShopShareCard(bytes);
        } else {
          await Share.shareXFiles([
            XFile.fromData(
              bytes,
              mimeType: 'image/png',
              name: 'petnest_shop_card.png',
            ),
          ], text: '掃碼進店，或在 PetNest APP 輸入搜尋碼。\n${widget.link}');
        }
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              action == 'print'
                  ? '無法開啟列印視窗，請允許彈出視窗，或下載圖片後列印。'
                  : '無法分享圖片，請改用下載圖片後傳送。',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('店家分享卡')),
    body: FutureBuilder<String>(
      future: _name,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('無法讀取店家名稱，請重試。'),
                TextButton(
                  onPressed: () => setState(() => _name = _loadName()),
                  child: const Text('重新讀取'),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '一張卡，方便傳 LINE 或印出放在櫃台。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FittedBox(
                    fit: BoxFit.fitWidth,
                    child: SizedBox(
                      width: 480,
                      child: RepaintBoundary(
                        key: _captureKey,
                        child: MediaQuery.withNoTextScaling(
                          child: ShopGuestShareCard(
                            shopName: snapshot.data!,
                            link: widget.link,
                            searchCode: widget.searchCode,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : () => _output('share'),
                    icon: const Icon(Icons.ios_share),
                    label: Text(_busy ? '處理中…' : '分享完整圖片（可選 LINE）'),
                  ),
                  if (kIsWeb) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _output('download'),
                      icon: const Icon(Icons.download_outlined),
                      label: const Text('下載圖片'),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => _output('print'),
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('列印／另存 PDF'),
                    ),
                  ],
                  const SizedBox(height: 12),
                  const Text(
                    '這張卡使用目前的 QR 與搜尋碼。日後換碼，請重新製作並更換已張貼或傳送的圖片。',
                    style: TextStyle(fontSize: 12, height: 1.6),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}

/// Guest-facing artwork shared and printed without the surrounding app controls.
class ShopGuestShareCard extends StatelessWidget {
  const ShopGuestShareCard({
    super.key,
    required this.shopName,
    required this.link,
    required this.searchCode,
  });
  final String shopName;
  final String link;
  final String searchCode;
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.all(24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'WELCOME  ·  歡迎光臨',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 2,
            color: Color(0xFF586A8C),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          shopName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 25,
            height: 1.35,
            fontWeight: FontWeight.w800,
            color: Color(0xFF243047),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '掃一下，輕鬆進店',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Color(0xFF586A8C)),
        ),
        const SizedBox(height: 20),
        Center(
          child: LayoutBuilder(
            builder: (context, constraints) => Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(color: const Color(0xFFE1E7F0)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: link,
                size: (constraints.maxWidth - 28).clamp(100, 224).toDouble(),
                backgroundColor: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '網頁版｜不必下載 APP',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Color(0xFF243047),
          ),
        ),
        const SizedBox(height: 5),
        const Text(
          '使用手機相機掃描 QR Code 即可開啟',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 11, color: Color(0xFF586A8C)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 20),
          child: Divider(height: 1),
        ),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F3FA),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              const Text(
                '手機 APP 搜尋碼',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF586A8C),
                ),
              ),
              const SizedBox(height: 10),
              if (searchCode.isNotEmpty) ...[
                Text(
                  searchCode,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    height: 1.5,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF243047),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'PetNest APP → 掃描店家 → 手動輸入搜尋碼',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.5,
                    color: Color(0xFF586A8C),
                  ),
                ),
              ] else
                const Text(
                  '尚未設定，請使用上方 QR Code 進店',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.6,
                    color: Color(0xFF586A8C),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'PetNest  ·  ${Uri.tryParse(link)?.host ?? ''}',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 10, color: Color(0xFF586A8C)),
        ),
      ],
    ),
  );
}
