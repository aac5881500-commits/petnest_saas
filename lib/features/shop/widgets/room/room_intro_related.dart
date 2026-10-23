// 功能：旅宿詳情的真實相關資訊；公開資料只讀一次，缺資料不建立假內容。
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_policy_service.dart';
import '../../pages/shop_environment_page.dart';
import '../../pages/shop_policy_view_page.dart';
import '../../pages/shop_review_list_page.dart';
import 'room_intro_appearance_scope.dart';

class RoomIntroRelated extends StatelessWidget {
  const RoomIntroRelated({
    super.key,
    required this.shopId,
    required this.theme,
    required this.compare,
    this.layout,
    this.previewOnly = false,
    this.showComparison,
  });
  final String shopId;
  final HomeThemeModel theme;
  final Widget compare;
  final String? layout;
  final bool previewOnly;
  final bool? showComparison;
  @override
  Widget build(BuildContext context) {
    final scope = RoomIntroAppearanceScope.maybeOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if ((showComparison ?? scope?.appearance.showComparison ?? true) &&
            (scope == null || (scope.ready && scope.error == null)))
          compare,
        if ((layout ?? scope?.appearance.detail.layout) == 'lodging' &&
            scope?.shopData != null)
          _PublishedInfo(
            key: ValueKey(shopId),
            shopId: shopId,
            theme: theme,
            shop: scope?.shopData ?? const {},
            previewOnly: previewOnly,
          ),
      ],
    );
  }
}

class _PublishedInfo extends StatefulWidget {
  const _PublishedInfo({
    super.key,
    required this.shopId,
    required this.theme,
    required this.shop,
    required this.previewOnly,
  });
  final String shopId;
  final HomeThemeModel theme;
  final Map<String, dynamic> shop;
  final bool previewOnly;
  @override
  State<_PublishedInfo> createState() => _PublishedInfoState();
}

class _PublishedInfoState extends State<_PublishedInfo> {
  late final Future<bool> _policy = ShopPolicyService.instance
      .hasEffectiveStayPolicy(widget.shopId)
      .catchError((Object _) => false);
  late final Future<bool> _reviews = FirebaseFirestore.instance
      .collection('reviews')
      .where('shopId', isEqualTo: widget.shopId)
      .where('status', isEqualTo: 'visible')
      .limit(1)
      .get()
      .then((s) => s.docs.isNotEmpty)
      .catchError((Object _) => false);
  void _preview() => ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('目前為後台預覽模式')));
  void _open(Widget page) {
    if (widget.previewOnly) {
      _preview();
      return;
    }
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final address = widget.shop['address'] is String
        ? (widget.shop['address'] as String).trim()
        : '';
    final environment = widget.shop['environmentIntro'];
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FutureBuilder<bool>(
            future: _policy,
            builder: (_, s) => s.data == true
                ? OutlinedButton.icon(
                    icon: const Icon(Icons.description_outlined),
                    label: const Text('入住須知與取消規定'),
                    onPressed: () => _open(
                      ShopPolicyViewPage(
                        shopId: widget.shopId,
                        theme: widget.theme,
                        readOnly: true,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          FutureBuilder<bool>(
            future: _reviews,
            builder: (_, s) => s.data == true
                ? OutlinedButton.icon(
                    icon: const Icon(Icons.star_outline),
                    label: const Text('全店評價'),
                    onPressed: () => _open(
                      ShopReviewListPage(
                        shopId: widget.shopId,
                        theme: widget.theme,
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (address.isNotEmpty) ...[
            Text('住宿地點：$address'),
            TextButton.icon(
              icon: const Icon(Icons.map_outlined),
              label: const Text('用地圖開啟'),
              onPressed: () {
                if (widget.previewOnly) {
                  _preview();
                  return;
                }
                launchUrl(
                  Uri.https('www.google.com', '/maps/search/', {
                    'api': '1',
                    'query': address,
                  }),
                  mode: LaunchMode.externalApplication,
                );
              },
            ),
          ],
          if (environment is Map && environment.isNotEmpty)
            OutlinedButton.icon(
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('環境介紹'),
              onPressed: () => _open(
                ShopEnvironmentPage(shopId: widget.shopId, theme: widget.theme),
              ),
            ),
        ],
      ),
    );
  }
}
