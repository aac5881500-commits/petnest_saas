import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/services/announcement_notification.dart';

void main() {
  test('cancel keeps prepared draft and does not send', () async {
    final actions = <String>[];
    final flow = AnnouncementNotification((action, payload) async {
      actions.add(action);
      expect((payload['draft'] as Map)['audience'], 'all');
      expect((payload['draft'] as Map)['category'], 'shop_marketing');
      return {
        'campaign': {'version': 1},
        'preview': {'count': 3, 'excluded': 1, 'revision': 'rev'},
      };
    }, 'stable');
    expect(
      await flow.submit(
        announcementId: 'a',
        title: '優惠',
        body: '內容',
        type: 'promotion',
        channel: 'push',
        confirm: (_) async => false,
      ),
      false,
    );
    expect(actions, ['preview']);
  });
  test('confirmation sends reviewed revision with stable id', () async {
    final actions = <String>[];
    final flow = AnnouncementNotification((action, payload) async {
      actions.add(action);
      expect(payload['campaignId'], 'stable');
      if (action == 'send') {
        expect(payload['revision'], 'rev');
        return {};
      }
      return {
        'campaign': {'version': 1},
        'preview': {'count': 3, 'excluded': 0, 'revision': 'rev'},
      };
    }, 'stable');
    expect(
      await flow.submit(
        announcementId: 'a',
        title: '公告',
        body: '內容',
        type: 'normal',
        channel: 'inbox',
        confirm: (_) async => true,
      ),
      true,
    );
    expect(actions, ['preview', 'send']);
  });
  test(
    'uncertain send acknowledgement retries by checking job, never resends',
    () async {
      final actions = <String>[];
      final flow = AnnouncementNotification((action, payload) async {
        actions.add(action);
        if (action == 'send') throw StateError('ack lost');
        if (action == 'detail') {
          return {
            'campaign': {
              'status': 'queued',
              'title': '公告',
              'body': '內容',
              'channel': 'push',
            },
          };
        }
        return {
          'campaign': {'version': 1},
          'preview': {'count': 3, 'excluded': 0, 'revision': 'rev'},
        };
      }, 'stable');
      Future<bool> submit() => flow.submit(
        announcementId: 'a',
        title: '公告',
        body: '內容',
        type: 'normal',
        channel: 'inbox',
        confirm: (_) async => true,
      );
      await expectLater(submit(), throwsStateError);
      expect(await submit(), true);
      expect(actions, ['preview', 'send', 'detail']);
    },
  );
  test('no eligible members cannot send or request confirmation', () async {
    final flow = AnnouncementNotification((action, payload) async {
      expect(action, 'preview');
      return {
        'campaign': {'version': 1},
        'preview': {'count': 0, 'excluded': 2, 'revision': 'rev'},
      };
    }, 'stable');
    expect(
      await flow.submit(
        announcementId: 'a',
        title: '公告',
        body: '內容',
        type: 'normal',
        channel: 'push',
        confirm: (_) async => throw StateError('unexpected'),
      ),
      false,
    );
  });
  test(
    'long notification summary respects UTF16 limits without splitting emoji',
    () {
      final title = '${'a' * 78}😀尾';
      expect(AnnouncementNotification.excerpt(title, 80), '${'a' * 78}…');
      expect(AnnouncementNotification.excerpt('短文', 80), '短文');
    },
  );
}
