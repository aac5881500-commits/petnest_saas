// 檔案名稱：lib/core/models/customer_notification_kind.dart
// 功能說明：客戶通知分類。shop_notifications 是平台發給店家的文件，不進客戶收件匣。

import 'package:petnest_saas/core/models/app_notification_model.dart';

enum CustomerNoticeLane { primary, shop, platform }

enum CustomerPlatformTone { important, marketing }

class CustomerNoticePlacement {
  const CustomerNoticePlacement({
    required this.lane,
    required this.category,
    required this.mandatory,
    this.shopTag = '',
    this.platformTone,
  });

  final CustomerNoticeLane lane;
  final String category;
  final bool mandatory;
  final String shopTag;
  final CustomerPlatformTone? platformTone;
}

const Set<String> customerTransactionalTypes = <String>{
  'booking_status',
  'booking_message',
  'check_in',
  'review',
  'shop_chat',
};

CustomerNoticePlacement classifyCustomerNotification(
  AppNotificationModel notification,
) {
  try {
    return _classifyCustomerNotification(notification);
  } catch (_) {
    return const CustomerNoticePlacement(
      lane: CustomerNoticeLane.primary,
      category: 'transactional',
      mandatory: true,
    );
  }
}

CustomerNoticePlacement _classifyCustomerNotification(
  AppNotificationModel notification,
) {
  final String type = notification.type.trim();
  if (customerTransactionalTypes.contains(type)) {
    return const CustomerNoticePlacement(
      lane: CustomerNoticeLane.primary,
      category: 'transactional',
      mandatory: true,
    );
  }

  final String source = notification.source.trim();
  final String category = notification.category.trim();
  if (source == 'shop' ||
      category == 'shop_marketing' ||
      category == 'shop_notice') {
    final String resolved = category == 'shop_notice'
        ? 'shop_notice'
        : 'shop_marketing';
    return CustomerNoticePlacement(
      lane: CustomerNoticeLane.shop,
      category: resolved,
      mandatory: notification.isMandatory == true,
      shopTag: customerShopNoticeTag(notification, resolved),
    );
  }

  if (source == 'platform' ||
      category == 'platform_important' ||
      category == 'platform_marketing') {
    final bool marketing = category == 'platform_marketing';
    return CustomerNoticePlacement(
      lane: CustomerNoticeLane.platform,
      category: marketing ? 'platform_marketing' : 'platform_important',
      mandatory: marketing ? notification.isMandatory == true : true,
      platformTone: marketing
          ? CustomerPlatformTone.marketing
          : CustomerPlatformTone.important,
    );
  }

  return const CustomerNoticePlacement(
    lane: CustomerNoticeLane.primary,
    category: 'transactional',
    mandatory: true,
  );
}

String customerShopNoticeTag(
  AppNotificationModel notification,
  String category,
) {
  final String kind = _noticeKind(notification);
  switch (kind) {
    case 'campaign':
    case 'event':
      return '活動';
    case 'coupon':
    case 'promotion':
      return '優惠';
    case 'announcement':
      return '公告';
    case 'service_change':
      return '服務異動';
  }
  if (category == 'shop_notice') return '服務異動';
  if (category == 'shop_marketing') return '優惠';
  return '公告';
}

String _noticeKind(AppNotificationModel notification) {
  try {
    return (notification.data['noticeKind'] ?? '').toString().trim();
  } catch (_) {
    return '';
  }
}

String customerShopDisplayName(AppNotificationModel notification) {
  final String name = notification.shopName.trim();
  if (name.isNotEmpty) return name;
  return '店家通知';
}

/// 必要通知一律可推播。選用分類才看對應開關；缺少欄位時預設開啟。
bool customerPushAllowed({
  required bool mandatory,
  required String category,
  required Map<String, bool?> settings,
}) {
  if (mandatory ||
      category == 'transactional' ||
      category == 'platform_important') {
    return true;
  }
  if (settings['enabled'] == false) return false;
  if (category == 'shop_marketing') return settings['shopMarketing'] != false;
  if (category == 'shop_notice') return settings['shopNotice'] != false;
  if (category == 'platform_marketing') {
    return settings['platformMarketing'] != false;
  }
  return true;
}
