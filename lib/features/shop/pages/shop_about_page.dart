import 'package:petnest_saas/core/services/shop_intro_content_status.dart';
// 檔案名稱：lib/features/shop/pages/shop_about_page.dart
// 功能說明：顯示店家品牌介紹、理念、店家訊息與聯絡資訊
// 🐾 前台關於我們頁
// 並依照 Classic / Modern 首頁套用共用主題

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/about_cover_frame_setting.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/about_page_setting.dart';
import 'package:petnest_saas/core/services/shop_service.dart';
import '../widgets/about/about_intro_view.dart';

class ShopAboutPage extends StatefulWidget {
  const ShopAboutPage({
    super.key,
    required this.shopId,
    required this.theme,
    this.previewTitle,
    this.previewDescription,
    this.previewMessage,
    this.previewImageUrl,
    this.previewFrame,
    this.scrollToContact = false,
    this.shopStream,
    this.previewSetting,
  });

  final String shopId;
  final HomeThemeModel theme;
  final String? previewTitle;
  final String? previewDescription;
  final String? previewMessage;
  final String? previewImageUrl;
  final AboutCoverFrameSetting? previewFrame;
  final bool scrollToContact;
  final Stream<Map<String, dynamic>?>? shopStream;
  final AboutPageSetting? previewSetting;

  @override
  State<ShopAboutPage> createState() => _ShopAboutPageState();
}

class _ShopAboutPageState extends State<ShopAboutPage> {
  final GlobalKey _contactKey = GlobalKey();
  late Stream<Map<String, dynamic>?> _stream;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _bind();
  }

  void _bind() => _stream =
      widget.shopStream ?? ShopService.instance.streamShop(widget.shopId);
  @override
  void didUpdateWidget(covariant ShopAboutPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId != widget.shopId ||
        oldWidget.shopStream != widget.shopStream) {
      _bind();
      _revealed = false;
    }
  }

  Widget _content(Map<String, dynamic> shop) {
    final data = <String, dynamic>{
      ...shop,
      if (widget.previewTitle != null) 'aboutTitle': widget.previewTitle,
      if (widget.previewDescription != null)
        'aboutDescription': widget.previewDescription,
      if (widget.previewMessage != null) 'aboutMessage': widget.previewMessage,
      if (widget.previewImageUrl != null)
        'aboutImageUrl': widget.previewImageUrl,
      if (widget.previewFrame != null) ...widget.previewFrame!.toMap(),
    };
    if (widget.scrollToContact && !_revealed) {
      _revealed = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _contactKey.currentContext;
        if (mounted && target != null) {
          Scrollable.ensureVisible(
            target,
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          );
        }
      });
    }
    return AboutIntroView(
      key: ValueKey(widget.shopId),
      shop: data,
      setting: widget.previewSetting ?? AboutPageSetting.fromShop(shop),
      theme: AboutPageSetting.shopTheme(shop, widget.theme),
      contactKey: _contactKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.theme.backgroundColor,
      appBar: AppBar(
        backgroundColor: widget.theme.cardColor,
        foregroundColor: widget.theme.textColor,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        title: Text(
          '關於我們',
          style: TextStyle(
            fontWeight: FontWeight.w900,
            color: widget.theme.textColor,
          ),
        ),
      ),
      body: StreamBuilder<Map<String, dynamic>?>(
        key: ValueKey(widget.shopId),
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('關於我們暫時無法載入'));
          if (!snapshot.hasData) {
            return Center(
              child: snapshot.connectionState == ConnectionState.waiting
                  ? const CircularProgressIndicator()
                  : const Text('找不到店家'),
            );
          }
          final preview =
              widget.previewTitle != null ||
              widget.previewDescription != null ||
              widget.previewSetting != null;
          if (!preview && !ShopIntroContent.about(snapshot.data!)) {
            return const SizedBox.shrink();
          }
          return _content(snapshot.data!);
        },
      ),
    );
  }
}
