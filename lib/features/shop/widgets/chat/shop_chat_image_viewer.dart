// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_image_viewer.dart
// 功能說明：聊天圖片全螢幕檢視

import 'package:flutter/material.dart';

class ShopChatImageViewer extends StatelessWidget {
  const ShopChatImageViewer({super.key, required this.imageUrl});

  final String imageUrl;

  static Future<void> open(BuildContext context, String imageUrl) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ShopChatImageViewer(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 1,
          maxScale: 4,
          child: Image.network(
            imageUrl,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white70,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}
