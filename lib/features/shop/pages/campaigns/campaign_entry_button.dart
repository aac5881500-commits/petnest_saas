import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:petnest_saas/core/constants/shop_permission_keys.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import 'shop_campaign_center_page.dart';

class CampaignEntryButton extends StatefulWidget {
  const CampaignEntryButton({
    super.key,
    required this.shopId,
    this.historyOnly = false,
    this.onReturn,
    this.memberId,
    this.announcementId,
    this.title,
    this.body,
    this.label = '發送推廣／通知',
  });
  final String shopId, label;
  final bool historyOnly;
  final VoidCallback? onReturn;
  final String? memberId, announcementId, title, body;
  @override
  State<CampaignEntryButton> createState() => _CampaignEntryButtonState();
}

class _CampaignEntryButtonState extends State<CampaignEntryButton> {
  late Future<bool> _allowed;
  @override
  void initState() {
    super.initState();
    _allowed = _load();
  }

  @override
  void didUpdateWidget(covariant CampaignEntryButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId) _allowed = _load();
  }

  Future<bool> _load() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return false;
    final member = await ShopService.instance.getUserMemberInShop(
      shopId: widget.shopId,
      uid: uid,
    );
    return [
      ShopPermissionKeys.manageCampaignDrafts,
      ShopPermissionKeys.sendMemberCampaigns,
    ].any((key) => ShopService.instance.hasPermission(member, key));
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
    future: _allowed,
    builder: (context, snapshot) => snapshot.data != true
        ? const SizedBox.shrink()
        : TextButton.icon(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => ShopCampaignCenterPage(
                    shopId: widget.shopId,
                    initialMemberId: widget.memberId,
                    announcementId: widget.historyOnly
                        ? null
                        : widget.announcementId,
                    filterAnnouncementId: widget.historyOnly
                        ? widget.announcementId
                        : null,
                    initialTitle: widget.title,
                    initialBody: widget.body,
                  ),
                ),
              );
              widget.onReturn?.call();
            },
            icon: const Icon(Icons.campaign_outlined, size: 18),
            label: Text(widget.label),
          ),
  );
}
