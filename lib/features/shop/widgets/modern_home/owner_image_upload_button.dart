import 'package:flutter/material.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

/// Shared owner upload control. Images are owned by the shop, never by a preset.
class OwnerImageUploadButton extends StatefulWidget {
  const OwnerImageUploadButton({
    super.key,
    required this.shopId,
    required this.label,
    required this.onUploaded,
    this.onBusyChanged,
  });
  final String shopId, label;
  final ValueChanged<String> onUploaded;
  final ValueChanged<bool>? onBusyChanged;
  @override
  State<OwnerImageUploadButton> createState() => _OwnerImageUploadButtonState();
}

class _OwnerImageUploadButtonState extends State<OwnerImageUploadButton> {
  bool busy = false;
  Future<void> upload() async {
    if (busy) return;
    setState(() => busy = true);
    widget.onBusyChanged?.call(true);
    try {
      final image = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      final ext = image.name.split('.').last.toLowerCase();
      if (bytes.length > 5 * 1024 * 1024 ||
          !['png', 'jpg', 'jpeg', 'webp'].contains(ext)) {
        throw const FormatException();
      }
      final ref = FirebaseStorage.instance.ref(
        'shops/${widget.shopId}/home/banners/section_photos/p_${DateTime.now().microsecondsSinceEpoch}/photo.$ext',
      );
      await ref.putData(
        bytes,
        SettableMetadata(
          contentType: ext == 'jpg' || ext == 'jpeg'
              ? 'image/jpeg'
              : 'image/$ext',
        ),
      );
      final url = await ref.getDownloadURL();
      if (mounted) widget.onUploaded(url);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('圖片讀取或上傳失敗，請選擇5 MB內的JPG、PNG或WEBP重試')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => busy = false);
        widget.onBusyChanged?.call(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: busy ? null : upload,
    icon: const Icon(Icons.upload_outlined),
    label: Text(busy ? '上傳中…' : widget.label),
  );
}
