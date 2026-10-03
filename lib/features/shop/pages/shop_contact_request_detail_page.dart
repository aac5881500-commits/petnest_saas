// 檔案名稱：lib/features/shop/pages/shop_contact_request_detail_page.dart
// 功能說明：店主進入單一聯絡案件的聊天室，結案後可另開新案件。

import 'package:flutter/material.dart';

import 'package:petnest_saas/features/shop/pages/shop_contact_platform_page.dart';
import 'package:petnest_saas/features/support/widgets/contact_case_chat.dart';

class ShopContactRequestDetailPage extends StatelessWidget {
  const ShopContactRequestDetailPage({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return ContactCaseChat(
      requestId: requestId,
      viewer: ContactCaseViewer.shopOwner,
      onCreateNewCase: (String shopId) {
        Navigator.push(
          context,
          MaterialPageRoute<void>(
            builder: (_) => ShopContactRequestCreatePage(shopId: shopId),
          ),
        );
      },
    );
  }
}
