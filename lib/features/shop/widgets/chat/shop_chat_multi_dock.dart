// 檔案名稱：lib/features/shop/widgets/chat/shop_chat_multi_dock.dart
// 功能說明：右側最多六個可同時回覆的聊天小視窗（2 欄 × 3 列）。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/features/shop/controllers/shop_chat_multi_dock_controller.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_mini_window.dart';

class ShopChatMultiDock extends StatelessWidget {
  const ShopChatMultiDock({
    super.key,
    required this.shopId,
    required this.controller,
    this.overlay = false,
  });

  final String shopId;
  final ShopChatMultiDockController controller;
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? child) {
        return Material(
          color: const Color(0xFFF8FAFC),
          elevation: overlay ? 12 : 2,
          shadowColor: Colors.black26,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(left: BorderSide(color: Color(0xFFE6EAF0))),
            ),
            child: Column(
              children: <Widget>[
                _DockBar(controller: controller, overlay: overlay),
                Expanded(
                  child: controller.windows.isEmpty
                      ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16),
                            child: Text(
                              '從左側聊天清單選擇會員，即可在這裡同時回覆',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Color(0xFF6B7280)),
                            ),
                          ),
                        )
                      : _WindowGrid(shopId: shopId, controller: controller),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DockBar extends StatelessWidget {
  const _DockBar({required this.controller, required this.overlay});

  final ShopChatMultiDockController controller;
  final bool overlay;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '聊天視窗 ${controller.openIds.length}／${controller.maxSlots}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
            ),
            IconButton(
              tooltip: '縮小聊天區',
              onPressed: controller.minimizeDock,
              icon: const Icon(Icons.remove),
            ),
            IconButton(
              tooltip: overlay ? '關閉聊天區' : '關閉聊天區',
              onPressed: controller.closeDock,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}

class _WindowGrid extends StatelessWidget {
  const _WindowGrid({required this.shopId, required this.controller});

  final String shopId;
  final ShopChatMultiDockController controller;

  @override
  Widget build(BuildContext context) {
    final List<ShopChatThreadModel> windows = controller.windows;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
      child: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final bool twoColumns =
              constraints.maxWidth >=
              ShopChatMultiDockPlacement.twoColumnMinWidth;
          final int columns = twoColumns ? 2 : 1;
          return GridView.builder(
            itemCount: windows.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: twoColumns ? 0.72 : 1.05,
            ),
            itemBuilder: (BuildContext context, int index) {
              final ShopChatThreadModel thread = windows[index];
              return ShopChatMiniWindow(
                key: controller.windowKeyFor(thread.id),
                shopId: shopId,
                thread: thread,
                controller: controller,
                highlighted: controller.highlightId == thread.id,
              );
            },
          );
        },
      ),
    );
  }
}
