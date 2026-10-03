// 檔案名稱：lib/features/support/contact_case_labels.dart
// 功能說明：聯絡平台案件的狀態文字、摘要與訊息左右判斷。

const List<String> contactCaseCategories = <String>[
  '功能問題',
  '帳號 / 權限',
  '店家資料',
  '訂單 / 預約',
  '付款 / 訂金',
  '建議回饋',
  '其他',
];

const List<String> contactPlatformQuickReplies = <String>[
  '您好，已收到您的問題，我們會協助確認。',
  '請補充操作步驟及畫面截圖，方便我們確認。',
  '目前已完成處理，請您再試一次。',
];

const int contactMessagePageSize = 30;

String contactCaseStatusLabel(String status) {
  switch (status) {
    case 'open':
      return '待處理';
    case 'processing':
      return '處理中';
    case 'closed':
      return '已結案';
    default:
      return status.trim().isEmpty ? '待處理' : status;
  }
}

String contactCaseSummary(Map<String, dynamic> data) {
  final String last = (data['lastMessage'] ?? '').toString().trim();
  if (last.isNotEmpty) {
    return last;
  }
  final String content = (data['content'] ?? '').toString().trim();
  if (content.isNotEmpty) {
    return content;
  }
  return '尚無內容';
}

String contactOpeningSenderType(String source) {
  if (source == 'member') {
    return 'member';
  }
  if (source == 'platform') {
    return 'platform';
  }
  return 'shop_owner';
}

bool contactBubbleIsMine({
  required bool platformViewer,
  required String senderType,
}) {
  if (platformViewer) {
    return senderType == 'platform';
  }
  return senderType == 'shop_owner';
}

String contactSenderLabel(String senderType) {
  switch (senderType) {
    case 'platform':
      return '平台客服';
    case 'member':
      return '會員';
    default:
      return '店主';
  }
}

String contactDayLabel(DateTime time) {
  final String month = time.month.toString().padLeft(2, '0');
  final String day = time.day.toString().padLeft(2, '0');
  return '${time.year}/$month/$day';
}

String contactClockLabel(DateTime time) {
  final String hour = time.hour.toString().padLeft(2, '0');
  final String minute = time.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
