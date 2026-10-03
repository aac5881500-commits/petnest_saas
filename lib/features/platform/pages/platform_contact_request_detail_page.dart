// 檔案名稱：lib/features/platform/pages/platform_contact_request_detail_page.dart
// 功能說明：窄螢幕從案件列表進入平台客服聊天室。

import 'package:flutter/material.dart';

import 'package:petnest_saas/features/support/widgets/contact_case_chat.dart';

class PlatformContactRequestDetailPage extends StatelessWidget {
  const PlatformContactRequestDetailPage({super.key, required this.requestId});

  final String requestId;

  @override
  Widget build(BuildContext context) {
    return ContactCaseChat(
      requestId: requestId,
      viewer: ContactCaseViewer.platform,
    );
  }
}
