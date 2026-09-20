// 檔案名稱：lib/features/shop/pages/chat/shop_chat_inbox_page.dart
// 功能說明：保留完整收件匣頁給無 Dashboard 範圍時使用；後台入口改走左側浮層。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/shop_chat_thread_model.dart';
import 'package:petnest_saas/features/shop/pages/chat/shop_chat_thread_page.dart';
import 'package:petnest_saas/features/shop/widgets/chat/shop_chat_inbox_list.dart';
import 'package:petnest_saas/features/shop/widgets/shop_admin_workspace.dart';

class ShopChatInboxPage extends StatefulWidget {
  const ShopChatInboxPage({
    super.key,
    required this.shopId,
    this.onConversationSelected,
  });

  final String shopId;
  final void Function(ShopChatThreadModel thread)? onConversationSelected;

  @override
  State<ShopChatInboxPage> createState() => _ShopChatInboxPageState();
}

class _ShopChatInboxPageState extends State<ShopChatInboxPage> {
  String _filter = 'inbox';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final ShopAdminWorkspaceController? workspace =
        ShopAdminWorkspaceScope.maybeOf(context);
    if (workspace == null) {
      return _buildScaffold(
        filter: _filter,
        query: _query,
        onFilterChanged: (String value) {
          setState(() {
            _filter = value;
          });
        },
        onQueryChanged: (String value) {
          setState(() {
            _query = value;
          });
        },
      );
    }
    return ListenableBuilder(
      listenable: workspace,
      builder: (BuildContext context, Widget? child) {
        return _buildScaffold(
          filter: workspace.inboxFilter,
          query: workspace.inboxQuery,
          onFilterChanged: workspace.setInboxFilter,
          onQueryChanged: workspace.setInboxQuery,
        );
      },
    );
  }

  void _onConversationSelected(ShopChatThreadModel thread) {
    if (widget.onConversationSelected != null) {
      widget.onConversationSelected!(thread);
      return;
    }
    final ShopAdminWorkspaceController? workspace =
        ShopAdminWorkspaceScope.maybeOf(context);
    if (workspace != null) {
      workspace.openThreadFromInbox(thread);
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ShopChatThreadPage(shopId: widget.shopId, threadId: thread.id),
      ),
    );
  }

  Widget _buildScaffold({
    required String filter,
    required String query,
    required ValueChanged<String> onFilterChanged,
    required ValueChanged<String> onQueryChanged,
  }) {
    return Scaffold(
      appBar: AppBar(title: const Text('店家聊天')),
      body: ShopChatInboxList(
        shopId: widget.shopId,
        compact: true,
        filter: filter,
        query: query,
        onFilterChanged: onFilterChanged,
        onQueryChanged: onQueryChanged,
        onOpenThread: _onConversationSelected,
      ),
    );
  }
}
