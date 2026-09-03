// lib/features/shop/widgets/booking/booking_entry_card_editor.dart
// 🖼️ 後台設定預約入口卡片照片

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:petnest_saas/core/services/booking_entry_card_service.dart';

class BookingEntryCardEditor extends StatelessWidget {
  const BookingEntryCardEditor({super.key, required this.shopId});

  final String shopId;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('shops')
          .doc(shopId)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> shop =
                snapshot.data?.data() ?? const <String, dynamic>{};
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  '預約入口卡片',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                const Text(
                  '貓咪旅店與安親都開啟時，客戶點「我要預約」會先看到這兩張卡片。未設定時住宿卡片會使用店家封面。',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
                const SizedBox(height: 12),
                _EntryImageTile(
                  shopId: shopId,
                  kind: BookingEntryCardKind.accommodation,
                  title: '住宿預約卡片照片',
                  imageUrl:
                      (shop[BookingEntryCardService.instance.urlField(
                                BookingEntryCardKind.accommodation,
                              )] ??
                              '')
                          .toString(),
                ),
                const SizedBox(height: 12),
                _EntryImageTile(
                  shopId: shopId,
                  kind: BookingEntryCardKind.daycare,
                  title: '安親預約卡片照片',
                  imageUrl:
                      (shop[BookingEntryCardService.instance.urlField(
                                BookingEntryCardKind.daycare,
                              )] ??
                              '')
                          .toString(),
                ),
              ],
            );
          },
    );
  }
}

class _EntryImageTile extends StatefulWidget {
  const _EntryImageTile({
    required this.shopId,
    required this.kind,
    required this.title,
    required this.imageUrl,
  });

  final String shopId;
  final String kind;
  final String title;
  final String imageUrl;

  @override
  State<_EntryImageTile> createState() => _EntryImageTileState();
}

class _EntryImageTileState extends State<_EntryImageTile> {
  bool _busy = false;

  Future<void> _upload() async {
    final XFile? image = await BookingEntryCardService.instance.pickImage();
    if (image == null) {
      return;
    }
    setState(() => _busy = true);
    try {
      await BookingEntryCardService.instance.upload(
        shopId: widget.shopId,
        kind: widget.kind,
        image: image,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('上傳失敗：$error')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _remove() async {
    setState(() => _busy = true);
    try {
      await BookingEntryCardService.instance.remove(
        shopId: widget.shopId,
        kind: widget.kind,
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('移除失敗：$error')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            AspectRatio(
              aspectRatio: 16 / 9,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: widget.imageUrl.isEmpty
                    ? ColoredBox(
                        color: Colors.blueGrey.shade100,
                        child: const Center(child: Text('尚未設定')),
                      )
                    : Image.network(
                        widget.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => ColoredBox(
                          color: Colors.blueGrey.shade100,
                          child: const Center(child: Text('圖片載入失敗')),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                FilledButton(
                  onPressed: _busy ? null : _upload,
                  child: Text(widget.imageUrl.isEmpty ? '上傳' : '更換'),
                ),
                const SizedBox(width: 8),
                if (widget.imageUrl.isNotEmpty)
                  OutlinedButton(
                    onPressed: _busy ? null : _remove,
                    child: const Text('移除'),
                  ),
                if (_busy) ...<Widget>[
                  const SizedBox(width: 12),
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}
