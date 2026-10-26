import 'package:petnest_saas/core/services/shop_intro_content_status.dart';
// 前台只讀取已上架的常見問題，並依店家設定控制入口。
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/services/shop_content_order.dart';

class ShopFaqPage extends StatefulWidget {
  const ShopFaqPage({
    super.key,
    required this.shopId,
    this.theme = HomeThemeModel.classicDefault,
    this.shopStream,
    this.faqStream,
  });

  final String shopId;
  final HomeThemeModel theme;
  final Stream<Map<String, dynamic>?>? shopStream;
  final Stream<List<Map<String, dynamic>>>? faqStream;

  @override
  State<ShopFaqPage> createState() => _ShopFaqPageState();
}

class _ShopFaqPageState extends State<ShopFaqPage> {
  late Stream<Map<String, dynamic>?> _shopStream;
  late Stream<List<Map<String, dynamic>>> _faqStream;
  HomeThemeModel get theme => widget.theme;

  @override
  void initState() {
    super.initState();
    _connect();
  }

  @override
  void didUpdateWidget(covariant ShopFaqPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId ||
        oldWidget.shopStream != widget.shopStream ||
        oldWidget.faqStream != widget.faqStream) {
      _connect();
    }
  }

  void _connect() {
    _shopStream =
        widget.shopStream ??
        FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .snapshots()
            .map((doc) => doc.data());
    _faqStream =
        widget.faqStream ??
        FirebaseFirestore.instance
            .collection('shops')
            .doc(widget.shopId)
            .collection('faqs')
            .where('isPublished', isEqualTo: true)
            .snapshots()
            .map(
              (snapshot) => snapshot.docs
                  .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
                  .toList(),
            );
  }

  Widget _message(String text, {bool retry = false}) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(color: theme.textColor.withValues(alpha: .75)),
          ),
          if (retry) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => setState(_connect),
              icon: const Icon(Icons.refresh),
              label: const Text('重試'),
            ),
          ],
        ],
      ),
    ),
  );

  Widget _loading() =>
      Center(child: CircularProgressIndicator(color: theme.primaryColor));

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: theme.backgroundColor,
    appBar: AppBar(
      title: Text(
        '常見問題',
        style: TextStyle(color: theme.textColor, fontWeight: FontWeight.w700),
      ),
      backgroundColor: theme.cardColor,
      foregroundColor: theme.textColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
    ),
    body: StreamBuilder<Map<String, dynamic>?>(
      stream: _shopStream,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _message('店家資料暫時無法載入。', retry: true);
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _loading();
        }
        final data = snapshot.data;
        if (data == null) return _message('找不到店家資料。');
        if (data['showFaqSection'] == false) return _message('此功能尚未開放');
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: _faqStream,
          builder: (context, faqSnapshot) {
            if (faqSnapshot.hasError) {
              return _message('常見問題暫時無法載入。', retry: true);
            }
            if (!faqSnapshot.hasData) return _loading();
            final items = faqSnapshot.data!
                .where(
                  (item) =>
                      ShopIntroContent.entries([item], faq: true) ==
                      ShopIntroContentStatus.configured,
                )
                .toList();
            items.sort(
              (a, b) => compareShopFaqOrder(
                firstId: a['id']?.toString() ?? '',
                firstOrder: a['sortOrder'],
                secondId: b['id']?.toString() ?? '',
                secondOrder: b['sortOrder'],
              ),
            );
            if (items.isEmpty) return _message('目前尚無常見問題');
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final question = item['question']?.toString() ?? '未命名問題';
                    final answer = item['answer']?.toString() ?? '';
                    return Padding(
                      key: ValueKey(item['id'] ?? index),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: theme.cardColor,
                        borderRadius: BorderRadius.circular(16),
                        child: ExpansionTile(
                          key: PageStorageKey(
                            'faq:${widget.shopId}:${item['id'] ?? index}',
                          ),
                          tilePadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          childrenPadding: const EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            16,
                          ),
                          iconColor: theme.primaryColor,
                          collapsedIconColor: theme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: theme.cardBorderColor),
                          ),
                          collapsedShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: theme.cardBorderColor),
                          ),
                          title: Text(
                            question,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: theme.textColor,
                            ),
                          ),
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                answer.isEmpty ? '尚未填寫回答' : answer,
                                style: TextStyle(
                                  fontSize: 14,
                                  height: 1.7,
                                  color: theme.textColor.withValues(alpha: .75),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      },
    ),
  );
}
