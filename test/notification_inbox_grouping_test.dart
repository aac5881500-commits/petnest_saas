import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/app_notification_model.dart';
import 'package:petnest_saas/core/models/customer_notification_kind.dart';
import 'package:petnest_saas/features/notifications/pages/notification_center_page.dart';

AppNotificationModel _item({
  required String id,
  required String type,
  required bool isRead,
  DateTime? createdAt,
  String bookingId = '',
  String shopId = '',
  String shopName = '',
  String source = '',
  String category = '',
  bool? isMandatory,
  Map<String, dynamic> data = const <String, dynamic>{},
}) {
  return AppNotificationModel(
    id: id,
    userId: 'uid',
    title: id,
    body: '內容',
    type: type,
    bookingId: bookingId,
    shopId: shopId,
    shopName: shopName,
    messageId: '',
    status: 'active',
    data: data,
    isRead: isRead,
    createdAt: createdAt,
    readAt: null,
    source: source,
    category: category,
    isMandatory: isMandatory,
  );
}

void main() {
  final DateTime now = DateTime(2026, 10, 1, 22, 0);

  test('舊通知沒有分類欄位時歸在主要，訂單狀態不可關閉推播', () {
    final AppNotificationModel legacy = _item(
      id: 'old',
      type: 'booking_status',
      isRead: false,
      createdAt: now,
    );
    final CustomerNoticePlacement placement = classifyCustomerNotification(
      legacy,
    );
    expect(placement.lane, CustomerNoticeLane.primary);
    expect(placement.mandatory, isTrue);
    expect(
      customerPushAllowed(
        mandatory: placement.mandatory,
        category: placement.category,
        settings: <String, bool?>{
          'enabled': false,
          'bookingStatus': false,
          'shopMarketing': false,
        },
      ),
      isTrue,
    );
  });

  test('店家活動進店家分頁並受活動開關控制', () {
    final AppNotificationModel notice = _item(
      id: 'promo',
      type: 'shop_campaign',
      isRead: false,
      shopId: 'SHOP0001',
      shopName: '愛喵窩',
      source: 'shop',
      category: 'shop_marketing',
      data: const <String, dynamic>{'noticeKind': 'campaign'},
    );
    final CustomerNoticePlacement placement = classifyCustomerNotification(
      notice,
    );
    expect(placement.lane, CustomerNoticeLane.shop);
    expect(placement.shopTag, '活動');
    expect(customerShopDisplayName(notice), '愛喵窩');
    expect(
      customerPushAllowed(
        mandatory: placement.mandatory,
        category: placement.category,
        settings: const <String, bool?>{'shopMarketing': false},
      ),
      isFalse,
    );
    expect(
      customerPushAllowed(
        mandatory: placement.mandatory,
        category: placement.category,
        settings: const <String, bool?>{},
      ),
      isTrue,
    );
  });

  test('平台重要不可關閉，平台推廣可關閉', () {
    final CustomerNoticePlacement important = classifyCustomerNotification(
      _item(
        id: 'policy',
        type: 'platform_policy',
        isRead: false,
        source: 'platform',
        category: 'platform_important',
      ),
    );
    final CustomerNoticePlacement marketing = classifyCustomerNotification(
      _item(
        id: 'ads',
        type: 'platform_promo',
        isRead: true,
        source: 'platform',
        category: 'platform_marketing',
      ),
    );
    expect(important.lane, CustomerNoticeLane.platform);
    expect(important.platformTone, CustomerPlatformTone.important);
    expect(important.mandatory, isTrue);
    expect(marketing.platformTone, CustomerPlatformTone.marketing);
    expect(
      customerPushAllowed(
        mandatory: important.mandatory,
        category: important.category,
        settings: const <String, bool?>{'platformMarketing': false},
      ),
      isTrue,
    );
    expect(
      customerPushAllowed(
        mandatory: marketing.mandatory,
        category: marketing.category,
        settings: const <String, bool?>{'platformMarketing': false},
      ),
      isFalse,
    );
  });

  test('同一天分在同一組，更早的日期合在一組', () {
    final List<AppNotificationModel> items = <AppNotificationModel>[
      _item(
        id: 'today',
        type: 'booking_status',
        isRead: false,
        createdAt: DateTime(2026, 10, 1, 21, 32),
      ),
      _item(
        id: 'today-earlier',
        type: 'review',
        isRead: true,
        createdAt: DateTime(2026, 10, 1, 8, 5),
      ),
      _item(
        id: 'yesterday',
        type: 'shop_chat',
        isRead: true,
        createdAt: DateTime(2026, 9, 30, 18, 0),
      ),
      _item(
        id: 'older',
        type: 'check_in',
        isRead: true,
        createdAt: DateTime(2026, 9, 20, 9, 15),
      ),
      _item(id: 'none', type: 'booking_status', isRead: true),
    ];

    final List<NotificationDayGroup> groups = groupNotificationsByDay(
      items,
      now,
    );
    expect(
      groups.map((NotificationDayGroup group) => group.title).toList(),
      <String>['今天', '昨天', '更早', '時間未記錄'],
    );
    expect(groups.first.items.length, 2);
    expect(notificationClockLabel(items.first.createdAt), '21:32');
    expect(notificationClockLabel(null), '時間未記錄');
    expect(customerLaneUnreadCount(items, CustomerNoticeLane.primary), 1);
  });

  test('沒有店名時不崩潰，沒有導頁資料時不可開啟', () {
    final AppNotificationModel unnamed = _item(
      id: 'shop',
      type: 'shop_campaign',
      isRead: false,
      source: 'shop',
      category: 'shop_notice',
      shopId: 'SHOP0002',
    );
    expect(customerShopDisplayName(unnamed), '店家通知');
    expect(
      notificationCanOpen(
        _item(id: 'status-empty', type: 'booking_status', isRead: false),
      ),
      isFalse,
    );
    expect(
      notificationCanOpen(
        _item(id: 'policy', type: 'platform_policy', isRead: false),
      ),
      isFalse,
    );
  });
}
