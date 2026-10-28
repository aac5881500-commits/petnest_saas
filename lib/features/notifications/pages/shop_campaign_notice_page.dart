import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/models/app_notification_model.dart';
import 'package:petnest_saas/features/shop/pages/shop_announcement_detail_page.dart';

class ShopCampaignNoticePage extends StatefulWidget {
  const ShopCampaignNoticePage({super.key, this.notification, this.campaignId});
  final AppNotificationModel? notification;
  final String? campaignId;
  @override
  State<ShopCampaignNoticePage> createState() => _ShopCampaignNoticePageState();
}

class _ShopCampaignNoticePageState extends State<ShopCampaignNoticePage> {
  late Future<AppNotificationModel?> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<AppNotificationModel?> _load() async {
    if (widget.notification != null) return widget.notification;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final campaignId = widget.campaignId;
    if (uid == null || campaignId == null || campaignId.contains('/')) {
      return null;
    }
    final ref = FirebaseFirestore.instance
        .collection('notifications')
        .doc('campaign_${campaignId}_$uid');
    final doc = await ref.get();
    if (!doc.exists) return null;
    final note = AppNotificationModel.fromDocument(doc);
    if (!note.isRead) {
      try {
        await ref.update({
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      } catch (_) {
        /* Reading remains available if acknowledgement fails. */
      }
    }
    return note;
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<AppNotificationModel?>(
    future: _future,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('店家通知')),
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('通知讀取失敗。'),
                TextButton(
                  onPressed: () => setState(() => _future = _load()),
                  child: const Text('重試'),
                ),
              ],
            ),
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }
      if (snapshot.data == null) {
        return Scaffold(
          appBar: AppBar(title: const Text('店家通知')),
          body: const Center(child: Text('請先登入，或此通知已不存在。')),
        );
      }
      return _page(context, snapshot.data!);
    },
  );
  Widget _page(BuildContext context, AppNotificationModel note) => Scaffold(
    appBar: AppBar(title: Text(note.shopName.isEmpty ? '店家通知' : note.shopName)),
    body: Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 800),
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              note.category == 'shop_notice' ? '店家服務通知' : '店家推廣',
              style: TextStyle(color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Text(
              note.title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 20),
            SelectableText(
              note.body,
              style: const TextStyle(fontSize: 16, height: 1.8),
            ),
            if ('${note.data['announcementId'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 24),
              OutlinedButton.icon(
                icon: const Icon(Icons.article_outlined),
                label: const Text('查看目前公告'),
                onPressed: () async {
                  try {
                    final doc = await FirebaseFirestore.instance
                        .collection('shops')
                        .doc(note.shopId)
                        .collection('announcements')
                        .doc('${note.data['announcementId']}')
                        .get();
                    if (!context.mounted) return;
                    if (!doc.exists || doc.data()?['isPublished'] != true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('公告已下架，仍可閱讀上方的發送內容。')),
                      );
                      return;
                    }
                    await Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            ShopAnnouncementDetailPage(data: doc.data()!),
                      ),
                    );
                  } catch (_) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('公告暫時無法載入，仍可閱讀上方通知。')),
                      );
                    }
                  }
                },
              ),
            ],
          ],
        ),
      ),
    ),
  );
}
