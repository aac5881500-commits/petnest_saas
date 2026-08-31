// lib/features/shop/pages/store/shop_store_settings_sections.dart
// 🛒 賣場設定分區頁：各區獨立儲存，避免一頁過長與付款 Stream 重複 listen。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/constants/store_constants.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/payment_gateway_status.dart';
import 'package:petnest_saas/core/models/store_appearance_model.dart';
import 'package:petnest_saas/core/services/inventory_image_service.dart';
import 'package:petnest_saas/core/services/payment_service.dart';
import 'package:petnest_saas/core/services/store_settings_service.dart';
import 'package:petnest_saas/features/shop/pages/shop_payout_setting_page.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_appearance_editor.dart';
import 'package:petnest_saas/features/shop/widgets/store/store_home_settings_section.dart';

class StoreSettingsBasicPage extends StatefulWidget {
  const StoreSettingsBasicPage({
    super.key,
    required this.shopId,
    required this.canManage,
  });

  final String shopId;
  final bool canManage;

  @override
  State<StoreSettingsBasicPage> createState() => _StoreSettingsBasicPageState();
}

class _StoreSettingsBasicPageState extends State<StoreSettingsBasicPage> {
  final TextEditingController _storeName = TextEditingController();
  final TextEditingController _storeSubtitle = TextEditingController();
  bool _storefrontEnabled = true;
  bool _loaded = false;

  @override
  void dispose() {
    _storeName.dispose();
    _storeSubtitle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final String name = _storeName.text.trim();
    final String subtitle = _storeSubtitle.text.trim();
    final StoreHomeDisplaySettings home = StoreHomeDisplaySettings.fromMap(
      (await StoreSettingsService.instance.settingsRef(widget.shopId).get())
              .data() ??
          const <String, dynamic>{},
    );
    await StoreSettingsService.instance.mergeSettings(
      shopId: widget.shopId,
      data: <String, dynamic>{
        'storefrontEnabled': _storefrontEnabled,
        'storeName': name,
        'storeDescription': subtitle,
      },
    );
    await StoreSettingsService.instance.saveStoreAppearance(
      shopId: widget.shopId,
      storeAppearance: home.storeAppearance.copyWith(
        storeTitle: name,
        storeSubtitle: subtitle,
      ).toMap(),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已儲存商城基本設定')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: StoreSettingsService.instance.streamSettings(widget.shopId),
      builder: (
        BuildContext context,
        AsyncSnapshot<Map<String, dynamic>> snapshot,
      ) {
        if (!_loaded && snapshot.hasData) {
          final StoreHomeDisplaySettings home =
              StoreHomeDisplaySettings.fromMap(snapshot.data!);
          _storefrontEnabled = snapshot.data!['storefrontEnabled'] != false;
          _storeName.text = home.storeName.isNotEmpty
              ? home.storeName
              : home.storeAppearance.storeTitle;
          _storeSubtitle.text = home.hasStorefrontSubtitle
              ? home.resolvedStorefrontSubtitle
              : '';
          _loaded = true;
        }
        return Scaffold(
          appBar: AppBar(title: const Text('商城基本設定')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('商城啟用'),
                subtitle: const Text('關閉後前台不顯示賣場入口'),
                value: _storefrontEnabled,
                onChanged: widget.canManage
                    ? (bool value) =>
                        setState(() => _storefrontEnabled = value)
                    : null,
              ),
              TextField(
                controller: _storeName,
                enabled: widget.canManage,
                decoration: const InputDecoration(
                  labelText: '商城名稱',
                  hintText: 'PetNest 寵物商城',
                  helperText: '留空則顯示「寵物賣場」',
                ),
              ),
              TextField(
                controller: _storeSubtitle,
                enabled: widget.canManage,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '商城副標',
                  hintText: '安心選購毛孩用品',
                  helperText: '同時作為商城簡介，留空則不顯示',
                ),
              ),
              const SizedBox(height: 20),
              if (widget.canManage)
                FilledButton(onPressed: _save, child: const Text('儲存')),
            ],
          ),
        );
      },
    );
  }
}

class StoreSettingsHomePage extends StatefulWidget {
  const StoreSettingsHomePage({
    super.key,
    required this.shopId,
    required this.canManage,
  });

  final String shopId;
  final bool canManage;

  @override
  State<StoreSettingsHomePage> createState() => _StoreSettingsHomePageState();
}

class _StoreSettingsHomePageState extends State<StoreSettingsHomePage> {
  final TextEditingController _announcement = TextEditingController();
  final TextEditingController _featuredTitle = TextEditingController();
  final TextEditingController _promoTitle = TextEditingController();
  final TextEditingController _allTitle = TextEditingController();
  final TextEditingController _latestTitle = TextEditingController();
  bool _showAnnouncement = true;
  bool _showCategories = true;
  bool _showFeatured = true;
  bool _showPromo = true;
  bool _showLatest = false;
  bool _loaded = false;

  @override
  void dispose() {
    _announcement.dispose();
    _featuredTitle.dispose();
    _promoTitle.dispose();
    _allTitle.dispose();
    _latestTitle.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final StoreHomeDisplaySettings home = StoreHomeDisplaySettings.fromMap(
      (await StoreSettingsService.instance.settingsRef(widget.shopId).get())
              .data() ??
          const <String, dynamic>{},
    );
    await StoreSettingsService.instance.mergeSettings(
      shopId: widget.shopId,
      data: <String, dynamic>{
        'announcement': _announcement.text.trim(),
        'showAnnouncement': _showAnnouncement,
        'showCategories': _showCategories,
        'showFeaturedProducts': _showFeatured,
        'showPromoProducts': _showPromo,
        'showLatestProducts': _showLatest,
      },
    );
    await StoreSettingsService.instance.saveStoreAppearance(
      shopId: widget.shopId,
      storeAppearance: home.storeAppearance.copyWith(
        featuredTitle: _featuredTitle.text.trim(),
        promoTitle: _promoTitle.text.trim(),
        allProductsTitle: _allTitle.text.trim(),
        latestTitle: _latestTitle.text.trim(),
      ).toMap(),
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已儲存商城首頁設定')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: StoreSettingsService.instance.streamSettings(widget.shopId),
      builder: (
        BuildContext context,
        AsyncSnapshot<Map<String, dynamic>> snapshot,
      ) {
        if (!_loaded && snapshot.hasData) {
          final StoreHomeDisplaySettings home =
              StoreHomeDisplaySettings.fromMap(snapshot.data!);
          _announcement.text = home.announcement;
          _showAnnouncement = home.showAnnouncement;
          _showCategories = home.showCategories;
          _showFeatured = home.showFeaturedProducts;
          _showPromo = home.showPromoProducts;
          _showLatest = snapshot.data!['showLatestProducts'] == true;
          _featuredTitle.text = home.storeAppearance.featuredTitle;
          _promoTitle.text = home.storeAppearance.promoTitle;
          _allTitle.text = home.storeAppearance.allProductsTitle;
          _latestTitle.text = home.storeAppearance.latestTitle;
          _loaded = true;
        }
        return Scaffold(
          appBar: AppBar(title: const Text('商城首頁')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: <Widget>[
              TextField(
                controller: _announcement,
                enabled: widget.canManage,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '商城公告',
                  hintText: '例如：滿 NT\$1,800 送寵物浴巾',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('顯示商城公告'),
                value: _showAnnouncement,
                onChanged: widget.canManage
                    ? (bool value) =>
                        setState(() => _showAnnouncement = value)
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('顯示商品分類'),
                value: _showCategories,
                onChanged: widget.canManage
                    ? (bool value) => setState(() => _showCategories = value)
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('顯示精選商品'),
                value: _showFeatured,
                onChanged: widget.canManage
                    ? (bool value) => setState(() => _showFeatured = value)
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('顯示優惠商品'),
                value: _showPromo,
                onChanged: widget.canManage
                    ? (bool value) => setState(() => _showPromo = value)
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('顯示最新商品'),
                subtitle: const Text('前台區塊預留，可先設定'),
                value: _showLatest,
                onChanged: widget.canManage
                    ? (bool value) => setState(() => _showLatest = value)
                    : null,
              ),
              const SizedBox(height: 12),
              const Text(
                '區塊名稱',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              const Text('留空使用系統預設。活動海報開關在「活動海報」。'),
              TextField(
                controller: _featuredTitle,
                enabled: widget.canManage,
                decoration: const InputDecoration(
                  labelText: '精選商品標題',
                  hintText: '精選商品',
                ),
              ),
              TextField(
                controller: _promoTitle,
                enabled: widget.canManage,
                decoration: const InputDecoration(
                  labelText: '優惠商品標題',
                  hintText: '優惠商品',
                ),
              ),
              TextField(
                controller: _allTitle,
                enabled: widget.canManage,
                decoration: const InputDecoration(
                  labelText: '全部商品標題',
                  hintText: '全部商品',
                ),
              ),
              TextField(
                controller: _latestTitle,
                enabled: widget.canManage,
                decoration: const InputDecoration(
                  labelText: '最新商品標題',
                  hintText: '最新商品',
                ),
              ),
              const SizedBox(height: 20),
              if (widget.canManage)
                FilledButton(onPressed: _save, child: const Text('儲存')),
            ],
          ),
        );
      },
    );
  }
}

class StoreSettingsBannersPage extends StatefulWidget {
  const StoreSettingsBannersPage({
    super.key,
    required this.shopId,
    required this.canManage,
  });

  final String shopId;
  final bool canManage;

  @override
  State<StoreSettingsBannersPage> createState() =>
      _StoreSettingsBannersPageState();
}

class _StoreSettingsBannersPageState extends State<StoreSettingsBannersPage> {
  bool _loaded = false;
  StoreHomeSettingsDraft _draft = StoreHomeSettingsDraft(
    showBanners: true,
    banners: <StoreBannerModel>[],
  );

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: StoreSettingsService.instance.streamSettings(widget.shopId),
      builder: (
        BuildContext context,
        AsyncSnapshot<Map<String, dynamic>> snapshot,
      ) {
        if (!_loaded && snapshot.hasData) {
          final StoreHomeDisplaySettings home =
              StoreHomeDisplaySettings.fromMap(snapshot.data!);
          _draft = StoreHomeSettingsDraft(
            showBanners: home.showBanners,
            banners: List<StoreBannerModel>.from(home.banners),
            bannerAutoPlay: home.bannerAutoPlay,
            bannerAutoPlaySeconds: home.bannerAutoPlaySeconds,
          );
          _loaded = true;
        }
        return Scaffold(
          appBar: AppBar(title: const Text('活動海報')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: <Widget>[
              if (_loaded)
                StoreHomeSettingsSection(
                  shopId: widget.shopId,
                  canManage: widget.canManage,
                  draft: _draft,
                  onChanged: () => setState(() {}),
                ),
            ],
          ),
        );
      },
    );
  }
}

class StoreSettingsProductsPage extends StatefulWidget {
  const StoreSettingsProductsPage({
    super.key,
    required this.shopId,
    required this.canManage,
  });

  final String shopId;
  final bool canManage;

  @override
  State<StoreSettingsProductsPage> createState() =>
      _StoreSettingsProductsPageState();
}

class _StoreSettingsProductsPageState extends State<StoreSettingsProductsPage> {
  bool _hideOutOfStock = false;
  bool _showStockToCustomer = true;
  int _featuredCount = 6;
  bool _loaded = false;

  Future<void> _save() async {
    await StoreSettingsService.instance.mergeSettings(
      shopId: widget.shopId,
      data: <String, dynamic>{
        'hideOutOfStock': _hideOutOfStock,
        'showStockToCustomer': _showStockToCustomer,
        'featuredCount': _featuredCount,
      },
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已儲存商品顯示設定')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: StoreSettingsService.instance.streamSettings(widget.shopId),
      builder: (
        BuildContext context,
        AsyncSnapshot<Map<String, dynamic>> snapshot,
      ) {
        if (!_loaded && snapshot.hasData) {
          final StoreHomeDisplaySettings home =
              StoreHomeDisplaySettings.fromMap(snapshot.data!);
          _hideOutOfStock = home.hideOutOfStock;
          _showStockToCustomer = home.showStockToCustomer;
          _featuredCount = home.featuredCount;
          _loaded = true;
        }
        return Scaffold(
          appBar: AppBar(title: const Text('商品顯示')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: <Widget>[
              const Text('缺貨與庫存文案會套用到商城前台商品卡。'),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('缺貨商品仍顯示給客戶'),
                value: !_hideOutOfStock,
                onChanged: widget.canManage
                    ? (bool value) =>
                        setState(() => _hideOutOfStock = !value)
                    : null,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('庫存剩餘量顯示給客戶'),
                value: _showStockToCustomer,
                onChanged: widget.canManage
                    ? (bool value) =>
                        setState(() => _showStockToCustomer = value)
                    : null,
              ),
              const SizedBox(height: 8),
              const Text('首頁精選商品數量'),
              Wrap(
                spacing: 8,
                children: <int>[4, 6, 8].map((int count) {
                  return ChoiceChip(
                    label: Text('$count'),
                    selected: _featuredCount == count,
                    onSelected: widget.canManage
                        ? (_) => setState(() => _featuredCount = count)
                        : null,
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              if (widget.canManage)
                FilledButton(onPressed: _save, child: const Text('儲存')),
            ],
          ),
        );
      },
    );
  }
}

class StoreSettingsAppearancePage extends StatefulWidget {
  const StoreSettingsAppearancePage({
    super.key,
    required this.shopId,
    required this.canManage,
  });

  final String shopId;
  final bool canManage;

  @override
  State<StoreSettingsAppearancePage> createState() =>
      _StoreSettingsAppearancePageState();
}

class _StoreSettingsAppearancePageState
    extends State<StoreSettingsAppearancePage> {
  StoreAppearanceSetting _value = const StoreAppearanceSetting();
  String _committedUrl = '';
  String _committedPath = '';
  String _pendingUrl = '';
  String _pendingPath = '';
  bool _removeImage = false;
  bool _uploading = false;
  bool _loaded = false;

  @override
  void dispose() {
    _discardPending();
    super.dispose();
  }

  Future<void> _discardPending() async {
    if (_pendingPath.isEmpty && _pendingUrl.isEmpty) {
      return;
    }
    if (_pendingPath == _committedPath || _pendingUrl == _committedUrl) {
      return;
    }
    await InventoryImageService.instance.tryDeleteImage(
      imageUrl: _pendingUrl,
      imageStoragePath: _pendingPath,
    );
  }

  Future<void> _pickImage() async {
    try {
      setState(() => _uploading = true);
      final image = await InventoryImageService.instance.pickAndValidateImage();
      if (image == null) {
        return;
      }
      final result = await InventoryImageService.instance.uploadImage(
        shopId: widget.shopId,
        itemId: 'card_bg_${DateTime.now().millisecondsSinceEpoch}',
        image: image,
        folder: StoreConstants.imageFolder,
        imageType: 'store_card_background',
        idMetadataKey: 'cardBackgroundId',
      );
      await _discardPending();
      if (!mounted) {
        return;
      }
      setState(() {
        _pendingUrl = result.imageUrl;
        _pendingPath = result.imageStoragePath;
        _removeImage = false;
        _value = _value.copyWith(
          cardBackgroundMode: StoreCardBackgroundModes.image,
          cardBackgroundImageUrl: result.imageUrl,
          cardBackgroundImageStoragePath: result.imageStoragePath,
        );
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  void _markRemove() {
    final String pendingUrl = _pendingUrl;
    final String pendingPath = _pendingPath;
    setState(() {
      _removeImage = true;
      _pendingUrl = '';
      _pendingPath = '';
      _value = _value.copyWith(
        cardBackgroundImageUrl: '',
        cardBackgroundImageStoragePath: '',
      );
    });
    if (pendingUrl.isNotEmpty || pendingPath.isNotEmpty) {
      InventoryImageService.instance.tryDeleteImage(
        imageUrl: pendingUrl,
        imageStoragePath: pendingPath,
      );
    }
  }

  Future<void> _save() async {
    final StoreHomeDisplaySettings home = StoreHomeDisplaySettings.fromMap(
      (await StoreSettingsService.instance.settingsRef(widget.shopId).get())
              .data() ??
          const <String, dynamic>{},
    );
    final StoreAppearanceSetting toSave = _value.copyWith(
      storeTitle: home.storeAppearance.storeTitle,
      storeSubtitle: home.storeAppearance.storeSubtitle,
      featuredTitle: home.storeAppearance.featuredTitle,
      promoTitle: home.storeAppearance.promoTitle,
      allProductsTitle: home.storeAppearance.allProductsTitle,
      latestTitle: home.storeAppearance.latestTitle,
      cardBackgroundImageUrl: _removeImage
          ? ''
          : (_pendingUrl.isNotEmpty ? _pendingUrl : _committedUrl),
      cardBackgroundImageStoragePath: _removeImage
          ? ''
          : (_pendingPath.isNotEmpty ? _pendingPath : _committedPath),
    );
    await StoreSettingsService.instance.saveStoreAppearance(
      shopId: widget.shopId,
      storeAppearance: toSave.toMap(),
    );
    if (_removeImage || _pendingPath.isNotEmpty) {
      final bool replacedOfficial = _committedPath.isNotEmpty &&
          _committedPath != toSave.cardBackgroundImageStoragePath;
      if (replacedOfficial || _removeImage) {
        await InventoryImageService.instance.tryDeleteImage(
          imageUrl: _committedUrl,
          imageStoragePath: _committedPath,
        );
      }
    }
    _committedUrl = toSave.cardBackgroundImageUrl;
    _committedPath = toSave.cardBackgroundImageStoragePath;
    _pendingUrl = '';
    _pendingPath = '';
    _removeImage = false;
    _value = toSave;
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已儲存商城外觀')),
    );
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: StoreSettingsService.instance.streamSettings(widget.shopId),
      builder: (
        BuildContext context,
        AsyncSnapshot<Map<String, dynamic>> snapshot,
      ) {
        if (!_loaded && snapshot.hasData) {
          final StoreHomeDisplaySettings home =
              StoreHomeDisplaySettings.fromMap(snapshot.data!);
          _value = home.storeAppearance;
          _committedUrl = _value.cardBackgroundImageUrl;
          _committedPath = _value.cardBackgroundImageStoragePath;
          _loaded = true;
        }
        return Scaffold(
          appBar: AppBar(title: const Text('商城外觀')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: <Widget>[
              if (_loaded)
                StoreAppearanceEditor(
                  shopId: widget.shopId,
                  value: _value,
                  shopTheme: HomeThemeModel.modernDefault,
                  uploading: _uploading,
                  onChanged: (StoreAppearanceSetting next) {
                    setState(() => _value = next);
                  },
                  onPickCardImage: _pickImage,
                  onRemoveCardImage: _markRemove,
                ),
              const SizedBox(height: 20),
              if (widget.canManage)
                FilledButton(onPressed: _save, child: const Text('儲存')),
            ],
          ),
        );
      },
    );
  }
}

class StoreSettingsOrdersPage extends StatefulWidget {
  const StoreSettingsOrdersPage({
    super.key,
    required this.shopId,
    required this.canManage,
  });

  final String shopId;
  final bool canManage;

  @override
  State<StoreSettingsOrdersPage> createState() =>
      _StoreSettingsOrdersPageState();
}

class _StoreSettingsOrdersPageState extends State<StoreSettingsOrdersPage> {
  final TextEditingController _orderNote = TextEditingController();
  final TextEditingController _cancelRuleNote = TextEditingController();
  bool _acceptNewOrders = true;
  bool _loaded = false;

  @override
  void dispose() {
    _orderNote.dispose();
    _cancelRuleNote.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await StoreSettingsService.instance.mergeSettings(
      shopId: widget.shopId,
      data: <String, dynamic>{
        'acceptNewOrders': _acceptNewOrders,
        'orderNote': _orderNote.text.trim(),
        'cancelRuleNote': _cancelRuleNote.text.trim(),
      },
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已儲存訂單設定')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: StoreSettingsService.instance.streamSettings(widget.shopId),
      builder: (
        BuildContext context,
        AsyncSnapshot<Map<String, dynamic>> snapshot,
      ) {
        if (!_loaded && snapshot.hasData) {
          _acceptNewOrders = snapshot.data!['acceptNewOrders'] != false;
          _orderNote.text = (snapshot.data!['orderNote'] ?? '').toString();
          _cancelRuleNote.text =
              (snapshot.data!['cancelRuleNote'] ?? '').toString();
          _loaded = true;
        }
        return Scaffold(
          appBar: AppBar(title: const Text('訂單設定')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: <Widget>[
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('接受新訂單'),
                value: _acceptNewOrders,
                onChanged: widget.canManage
                    ? (bool value) =>
                        setState(() => _acceptNewOrders = value)
                    : null,
              ),
              TextField(
                controller: _orderNote,
                enabled: widget.canManage,
                maxLines: 2,
                decoration: const InputDecoration(labelText: '訂單備註'),
              ),
              TextField(
                controller: _cancelRuleNote,
                enabled: widget.canManage,
                maxLines: 2,
                decoration: const InputDecoration(labelText: '取消規則說明'),
              ),
              const SizedBox(height: 20),
              if (widget.canManage)
                FilledButton(onPressed: _save, child: const Text('儲存')),
            ],
          ),
        );
      },
    );
  }
}

class StoreSettingsPaymentPage extends StatefulWidget {
  const StoreSettingsPaymentPage({
    super.key,
    required this.shopId,
  });

  final String shopId;

  @override
  State<StoreSettingsPaymentPage> createState() =>
      _StoreSettingsPaymentPageState();
}

class _StoreSettingsPaymentPageState extends State<StoreSettingsPaymentPage> {
  late final Stream<List<String>> _availablePaymentMethods;

  @override
  void initState() {
    super.initState();
    _availablePaymentMethods = PaymentService.instance.streamAvailableMethods(
      shopId: widget.shopId,
      amountType: PaymentAmountType.full,
    );
  }

  String _methodLabel(String method) {
    switch (method) {
      case PaymentMethodType.creditCard:
        return '信用卡';
      case PaymentMethodType.atm:
        return 'ATM 虛擬帳號';
      case PaymentMethodType.convenienceStoreCode:
        return '超商代碼';
      default:
        return method;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('付款')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          const Text('沿用店家金流設定，商城不會另外建立一組收款帳號。'),
          StreamBuilder<List<String>>(
            stream: _availablePaymentMethods,
            builder: (
              BuildContext context,
              AsyncSnapshot<List<String>> methodsSnap,
            ) {
              if (methodsSnap.hasError) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('無法讀取付款方式：${methodsSnap.error}'),
                );
              }
              final List<String> methods =
                  methodsSnap.data ?? const <String>[];
              if (methods.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text('目前顯示：到店付款（固定）／線上付款請至店家金流設定'),
                );
              }
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '目前可用：到店付款、${methods.map(_methodLabel).join('、')}',
                ),
              );
            },
          ),
          TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) =>
                      ShopPayoutSettingPage(shopId: widget.shopId),
                ),
              );
            },
            child: const Text('前往店家金流設定'),
          ),
        ],
      ),
    );
  }
}

class StoreSettingsPickupPage extends StatefulWidget {
  const StoreSettingsPickupPage({
    super.key,
    required this.shopId,
    required this.canManage,
  });

  final String shopId;
  final bool canManage;

  @override
  State<StoreSettingsPickupPage> createState() =>
      _StoreSettingsPickupPageState();
}

class _StoreSettingsPickupPageState extends State<StoreSettingsPickupPage> {
  final TextEditingController _pickupNote = TextEditingController();
  bool _loaded = false;

  @override
  void dispose() {
    _pickupNote.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await StoreSettingsService.instance.mergeSettings(
      shopId: widget.shopId,
      data: <String, dynamic>{'pickupNote': _pickupNote.text.trim()},
    );
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已儲存取貨設定')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, dynamic>>(
      stream: StoreSettingsService.instance.streamSettings(widget.shopId),
      builder: (
        BuildContext context,
        AsyncSnapshot<Map<String, dynamic>> snapshot,
      ) {
        if (!_loaded && snapshot.hasData) {
          _pickupNote.text = (snapshot.data!['pickupNote'] ?? '').toString();
          _loaded = true;
        }
        return Scaffold(
          appBar: AppBar(title: const Text('取貨 / 配送')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            children: <Widget>[
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('店內取貨'),
                subtitle: Text('第一版僅開放店內自取'),
              ),
              TextField(
                controller: _pickupNote,
                enabled: widget.canManage,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: '取貨說明',
                  hintText: '例如：請於營業時間至櫃台取貨',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '宅配、超商取貨與運費將在之後開放，這裡先預留位置。',
                style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
              ),
              const SizedBox(height: 20),
              if (widget.canManage)
                FilledButton(onPressed: _save, child: const Text('儲存')),
            ],
          ),
        );
      },
    );
  }
}
