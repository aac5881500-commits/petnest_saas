import 'package:cloud_functions/cloud_functions.dart';

typedef AnnouncementCampaignApi =
    Future<Map<String, dynamic>> Function(
      String action,
      Map<String, dynamic> data,
    );

class AnnouncementNotificationException implements Exception {
  const AnnouncementNotificationException(this.message);
  final String message;
}

/// A stable job id survives uncertain acknowledgements within an editor session.
/// Backend revision and idempotency checks remain authoritative.
class AnnouncementNotification {
  AnnouncementNotification(this.api, this.campaignId);
  final AnnouncementCampaignApi api;
  final String campaignId;
  int _version = 0;
  bool _attempted = false;
  int? lastRecipientCount;

  static String excerpt(String text, int limit) {
    if (text.length <= limit) return text;
    var end = limit - 1;
    if (end > 0 &&
        text.codeUnitAt(end - 1) >= 0xD800 &&
        text.codeUnitAt(end - 1) <= 0xDBFF) {
      end--;
    }
    return '${text.substring(0, end)}…';
  }

  Future<bool> submit({
    required String announcementId,
    required String title,
    required String body,
    required String type,
    required String channel,
    required Future<bool> Function(Map<String, dynamic> preview) confirm,
  }) async {
    if (_attempted) {
      try {
        final detail = await api('detail', {'campaignId': campaignId});
        final existing = detail['campaign'] as Map;
        if (existing['status'] != 'draft') {
          if (existing['title'] != excerpt(title, 80) ||
              existing['body'] != excerpt(body, 2000) ||
              existing['channel'] != 'push') {
            throw const AnnouncementNotificationException(
              '這筆通知已排入發送；修改內容後請另外建立通知。',
            );
          }
          return true;
        }
        _version = (existing['version'] as num).toInt();
      } on FirebaseFunctionsException catch (error) {
        if (error.code != 'not-found') rethrow;
        _version = 0;
      }
    }
    _attempted = true;
    final result = await api('preview', {
      'campaignId': campaignId,
      'version': _version,
      'draft': {
        'announcementId': announcementId,
        'title': excerpt(title, 80),
        'body': excerpt(body, 2000),
        'category': type == 'promotion' ? 'shop_marketing' : 'shop_notice',
        'channel': 'push',
        'audience': 'all',
        'memberIds': <String>[],
      },
    });
    _attempted = true;
    _version = ((result['campaign'] as Map)['version'] as num).toInt();
    final preview = Map<String, dynamic>.from(result['preview'] as Map);
    lastRecipientCount = (preview['count'] as num).toInt();
    preview['title'] = excerpt(title, 80);
    preview['body'] = excerpt(body, 2000);
    preview['channel'] = 'push';
    if ((preview['count'] as num) <= 0 || !await confirm(preview)) return false;
    await api('send', {
      'campaignId': campaignId,
      'revision': preview['revision'],
    });
    return true;
  }
}
