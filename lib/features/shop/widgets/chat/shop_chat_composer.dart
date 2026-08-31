// lib/features/shop/widgets/chat/shop_chat_composer.dart
// 💬 聊天輸入列：文字與選圖

import 'package:flutter/material.dart';

class ShopChatComposer extends StatelessWidget {
  const ShopChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.onSendText,
    required this.onPickImage,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final VoidCallback onSendText;
  final VoidCallback onPickImage;

  @override
  Widget build(BuildContext context) {
    final bool canUse = enabled && !sending;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
        child: Row(
          children: <Widget>[
            IconButton(
              onPressed: canUse ? onPickImage : null,
              icon: const Icon(Icons.add),
              tooltip: '選擇圖片',
            ),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: canUse,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                decoration: const InputDecoration(
                  hintText: '輸入訊息……',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) {
                  if (canUse) {
                    onSendText();
                  }
                },
              ),
            ),
            const SizedBox(width: 6),
            IconButton.filled(
              onPressed: canUse ? onSendText : null,
              icon: sending
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
