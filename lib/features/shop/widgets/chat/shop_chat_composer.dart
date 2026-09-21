// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_composer.dart
// 功能說明：聊天輸入列：文字與選圖

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:petnest_saas/core/models/shop_frontend_theme.dart';

class ShopChatComposer extends StatelessWidget {
  const ShopChatComposer({
    super.key,
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.onSendText,
    required this.onPickImage,
    this.appearance,
    this.focusNode,
    this.showAttach = true,
    this.compact = false,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final VoidCallback onSendText;
  final VoidCallback onPickImage;
  final ShopFrontendTheme? appearance;
  final FocusNode? focusNode;
  final bool showAttach;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final ShopFrontendTheme? theme = appearance;
    final bool canUse = enabled && !sending;
    return Material(
      color: theme?.cardColor ?? Colors.white,
      child: SafeArea(
        top: false,
        left: false,
        right: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: compact ? 48 : 64),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: theme?.cardColor ?? Colors.white,
              border: const Border(top: BorderSide(color: Color(0xFFE6EAF0))),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
              child: ListenableBuilder(
                listenable: controller,
                builder: (BuildContext context, Widget? child) {
                  final bool canSend =
                      canUse && controller.text.trim().isNotEmpty;
                  final Color addColor =
                      theme?.primaryColor ??
                      Theme.of(context).iconTheme.color ??
                      Colors.black54;
                  return Row(
                    children: <Widget>[
                      if (showAttach)
                        IconButton(
                          onPressed: canUse ? onPickImage : null,
                          icon: Icon(Icons.add, color: addColor),
                          tooltip: '選擇圖片',
                        ),
                      Expanded(
                        child: Focus(
                          onKeyEvent: (FocusNode node, KeyEvent event) {
                            if (event is! KeyDownEvent ||
                                event.logicalKey != LogicalKeyboardKey.enter) {
                              return KeyEventResult.ignored;
                            }
                            if (HardwareKeyboard.instance.isShiftPressed) {
                              return KeyEventResult.ignored;
                            }
                            if (canSend) {
                              onSendText();
                            }
                            return KeyEventResult.handled;
                          },
                          child: TextField(
                            controller: controller,
                            focusNode: focusNode,
                            enabled: canUse,
                            minLines: 1,
                            maxLines: 4,
                            textInputAction: TextInputAction.newline,
                            keyboardType: TextInputType.multiline,
                            style: TextStyle(color: theme?.bodyTextColor),
                            decoration: InputDecoration(
                              hintText: '輸入訊息……',
                              hintStyle: TextStyle(color: theme?.subtitleColor),
                              isDense: true,
                              filled: true,
                              fillColor: theme?.pageBackgroundColor,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                  color:
                                      theme?.borderColor ??
                                      Colors.grey.shade400,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                  color:
                                      theme?.borderColor ??
                                      Colors.grey.shade400,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide(
                                  color:
                                      theme?.primaryColor ??
                                      Theme.of(context).colorScheme.primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        onPressed: canSend ? onSendText : null,
                        style: theme == null
                            ? null
                            : IconButton.styleFrom(
                                backgroundColor: canSend
                                    ? theme.buttonColor
                                    : theme.disabledColor,
                                foregroundColor: theme.onPrimaryColor,
                                disabledBackgroundColor: theme.disabledColor,
                                disabledForegroundColor: theme.onPrimaryColor
                                    .withValues(alpha: 0.7),
                              ),
                        icon: sending
                            ? SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: theme?.onPrimaryColor ?? Colors.white,
                                ),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
