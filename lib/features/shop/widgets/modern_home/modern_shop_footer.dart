import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:petnest_saas/core/models/home_shop_info_setting.dart';
import 'package:petnest_saas/core/models/home_about_section_setting.dart';
import 'package:petnest_saas/core/models/home_card_image_setting.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/home_card_image.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/shop_modern_logo.dart';

class ModernShopFooter extends StatelessWidget {
  const ModernShopFooter({
    super.key,
    required this.shopId,
    required this.shop,
    required this.shopName,
    required this.primaryColor,
    required this.darkTextColor,
    required this.secondaryTextColor,
    required this.cardColor,
    required this.borderColor,
    this.isPreview = false,
    this.setting = const HomeShopInfoSetting(),
  });
  final String shopId, shopName;
  final Map<String, dynamic> shop;
  final Color primaryColor,
      darkTextColor,
      secondaryTextColor,
      cardColor,
      borderColor;
  final bool isPreview;
  final HomeShopInfoSetting setting;
  ShopInfoPreset get preset => shopInfoPresets.firstWhere(
    (p) => p.id == setting.preset,
    orElse: () => shopInfoPresets.first,
  );
  Color get accent => setting.followTheme ? primaryColor : Color(preset.accent);
  Color get surface => setting.followTheme ? cardColor : Color(preset.surface);
  Color get ink => setting.followTheme ? darkTextColor : Color(preset.text);
  Color get muted =>
      setting.followTheme ? secondaryTextColor : ink.withValues(alpha: 0.72);
  Color get border =>
      setting.followTheme ? borderColor : accent.withValues(alpha: 0.25);
  String value(String key) => (shop[key] ?? '').toString().trim();
  String get address => [
    'city',
    'district',
    'address',
  ].map(value).where((s) => s.isNotEmpty).join();
  String get hours => value('businessHours').isNotEmpty
      ? value('businessHours')
      : value('openTime').isNotEmpty && value('closeTime').isNotEmpty
      ? '${value('openTime')} - ${value('closeTime')}'
      : '';
  Future<void> _openUrl(String rawUrl) async {
    if (isPreview) {
      return;
    }
    final url = rawUrl.trim();

    if (url.isEmpty) return;

    final uri = Uri.tryParse(url);

    if (uri == null) return;

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _callPhone(String rawPhone) async {
    if (isPreview) {
      return;
    }
    final phone = rawPhone.trim();

    if (phone.isEmpty) return;

    await launchUrl(Uri.parse('tel:$phone'));
  }

  Future<void> _openMap(String rawAddress) async {
    if (isPreview) {
      return;
    }
    final address = rawAddress.trim();

    if (address.isEmpty) return;

    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query='
      '${Uri.encodeComponent(address)}',
    );

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) => buildDock(context, pull: false);

  /// The Scaffold reserves space for this dock above either navigation style.
  Widget buildDock(BuildContext context, {required bool pull}) {
    if (!setting.enabled) return const SizedBox.shrink();
    void open() => showShopInfoSheet(context);
    return Material(
      color: surface,
      child: GestureDetector(
        onVerticalDragEnd: (d) {
          if ((d.primaryVelocity ?? 0) < -100) open();
        },
        child: InkWell(
          onTap: open,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 16,
              vertical: pull ? 8 : 12,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.storefront_outlined,
                  color: accent,
                  size: pull ? 18 : 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        !pull && setting.showName ? shopName : '店家資訊',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                      if (!pull)
                        Text(
                          '營業時間・地址・聯絡方式',
                          style: TextStyle(color: muted, fontSize: 11),
                        ),
                    ],
                  ),
                ),
                if (!pull && setting.showActions && value('phone').isNotEmpty)
                  IconButton(
                    tooltip: '撥打電話',
                    onPressed: () => _callPhone(value('phone')),
                    icon: Icon(Icons.phone_outlined, color: accent),
                  ),
                if (!pull && setting.showActions && address.isNotEmpty)
                  IconButton(
                    tooltip: '開啟地圖',
                    onPressed: () => _openMap(address),
                    icon: Icon(Icons.near_me_outlined, color: accent),
                  ),
                Icon(Icons.keyboard_arrow_up_rounded, color: muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget buildInfoBody(BuildContext context, {VoidCallback? onClose}) {
    if (setting.imageSource == 'library') {
      return HomeCardImage(
        setting: HomeCardImageSetting(
          source: 'platformCard',
          assetId: setting.libraryImage.assetId,
        ),
        builder: (context, image) => _info(context, image.url, onClose),
      );
    }
    var photo = setting.imageSource == 'logo'
        ? value('logoUrl')
        : setting.imageUrl;
    if (setting.imageSource == 'photo' && photo.isEmpty) {
      final intro = shop['environmentIntro'];
      final choices = HomeAboutSectionSetting.imageChoices(
        shop: shop,
        environmentIntro: intro is Map
            ? Map<String, dynamic>.from(intro)
            : const {},
      );
      photo =
          choices
              .where((c) => c['url'] != value('logoUrl'))
              .map((c) => c['url']!)
              .firstOrNull ??
          '';
    }
    return _info(context, photo, onClose);
  }

  Widget _picture(String url, double height, {double? width}) => ClipRRect(
    borderRadius: BorderRadius.circular(setting.radius.clamp(0, 20)),
    child: Container(
      height: height,
      width: width,
      color: accent.withValues(alpha: 0.08),
      child: url.isEmpty
          ? Center(child: Icon(Icons.pets_rounded, color: accent, size: 30))
          : Image.network(
              url,
              fit: setting.imageFit == 'contain'
                  ? BoxFit.contain
                  : BoxFit.cover,
              errorBuilder: (_, _, _) => Center(
                child: Icon(Icons.storefront_outlined, color: accent, size: 30),
              ),
            ),
    ),
  );

  Widget _info(BuildContext context, String image, VoidCallback? onClose) {
    final hasImage = setting.imageSource != 'none' && setting.layout != 'plain';
    final centered = setting.layout == 'centered';
    final intro = value('aboutDescription').isNotEmpty
        ? value('aboutDescription')
        : value('description').isNotEmpty
        ? value('description')
        : value('aboutSubtitle');
    final identity = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        if (setting.showName)
          Text(
            shopName,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.4,
              color: ink,
            ),
          ),
        if (setting.showIntro && intro.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            intro,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: TextStyle(fontSize: 13, height: 1.5, color: muted),
          ),
        ],
      ],
    );
    final values = {
      'hours': hours,
      'address': address,
      'phone': value('phone'),
      'license': value('licenseNumber').isEmpty
          ? ''
          : '特寵字號：${value('licenseNumber')}',
      'tax': shop['showTaxId'] == true && value('taxId').isNotEmpty
          ? '統一編號：${value('taxId')}'
          : '',
    };
    final icons = {
      'hours': Icons.schedule_rounded,
      'address': Icons.location_on_outlined,
      'phone': Icons.phone_outlined,
      'license': Icons.verified_outlined,
      'tax': Icons.receipt_long_outlined,
    };
    final actions = <Widget>[
      if (value('phone').isNotEmpty)
        _action('撥打電話', Icons.phone_outlined, () => _callPhone(value('phone'))),
      if (address.isNotEmpty)
        _action('開啟地圖', Icons.near_me_outlined, () => _openMap(address)),
      if (value('lineUrl').isNotEmpty)
        _action(
          'LINE',
          FontAwesomeIcons.line,
          () => _openUrl(value('lineUrl')),
        ),
      if (value('igUrl').isNotEmpty)
        _action(
          'Instagram',
          FontAwesomeIcons.instagram,
          () => _openUrl(value('igUrl')),
        ),
      if (value('fbUrl').isNotEmpty)
        _action(
          'Facebook',
          FontAwesomeIcons.facebookF,
          () => _openUrl(value('fbUrl')),
        ),
    ];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (onClose != null)
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: '關閉店家資訊',
              onPressed: onClose,
              icon: Icon(Icons.close_rounded, color: muted),
            ),
          ),
        if (hasImage && setting.layout == 'banner') ...[
          _picture(image, 150, width: double.infinity),
          const SizedBox(height: 16),
        ],
        if (hasImage && centered) ...[
          Center(child: _picture(image, 88, width: 88)),
          const SizedBox(height: 12),
        ],
        if (hasImage && !centered && setting.layout != 'banner')
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (setting.imageSource == 'logo' && image.isEmpty)
                ShopModernLogo(
                  imageUrl: '',
                  size: setting.layout == 'side' ? 76 : 48,
                  borderRadius: 12,
                  primaryColor: accent,
                )
              else
                _picture(
                  image,
                  setting.layout == 'side' ? 76 : 48,
                  width: setting.layout == 'side' ? 76 : 48,
                ),
              const SizedBox(width: 12),
              Expanded(child: identity),
            ],
          )
        else
          identity,
        const SizedBox(height: 16),
        for (final key in setting.fields)
          if ((values[key] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icons[key], size: 19, color: accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (key != 'license' && key != 'tax')
                          Text(
                            HomeShopInfoSetting.fieldLabels[key]!,
                            style: TextStyle(fontSize: 12, color: muted),
                          ),
                        SelectableText(
                          values[key]!,
                          style: TextStyle(
                            fontSize: key == 'license' || key == 'tax'
                                ? 12
                                : 14,
                            height: 1.5,
                            color: ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        if (setting.showActions && actions.isNotEmpty)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: centered ? WrapAlignment.center : WrapAlignment.start,
            children: actions,
          ),
      ],
    );
  }

  Widget _action(String label, Object icon, VoidCallback action) {
    final style = setting.buttonStyle == 'filled'
        ? FilledButton.styleFrom(
            backgroundColor: accent,
            foregroundColor:
                ThemeData.estimateBrightnessForColor(accent) == Brightness.dark
                ? Colors.white
                : Colors.black87,
          )
        : OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(color: accent.withValues(alpha: 0.45)),
          );
    final Widget glyph = icon is IconData
        ? Icon(icon, size: 17)
        : FaIcon(icon as FaIconData, size: 17);
    if (setting.buttonStyle == 'filled') {
      return FilledButton.icon(
        onPressed: action,
        style: style,
        icon: glyph,
        label: Text(label),
      );
    }
    if (setting.buttonStyle == 'text') {
      return TextButton.icon(
        onPressed: action,
        style: style,
        icon: glyph,
        label: Text(label),
      );
    }
    return OutlinedButton.icon(
      onPressed: action,
      style: style,
      icon: glyph,
      label: Text(label),
    );
  }

  Future<void> showShopInfoSheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.85,
          ),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(setting.radius),
            ),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: border,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                const SizedBox(height: 12),
                buildInfoBody(ctx, onClose: () => Navigator.pop(ctx)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Shared by the live home and its editor preview. Scaffold reserves its height.
Widget? buildShopInfoBottomArea({
  required BuildContext context,
  required ModernShopFooter footer,
  required bool useBottomBar,
  Widget? navigationBar,
}) {
  if (!footer.setting.isFixed(useBottomBar)) return navigationBar;
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      SafeArea(
        top: false,
        bottom: !useBottomBar,
        child: footer.buildDock(
          context,
          pull: footer.setting.resolvedMode(useBottomBar) == 'pull',
        ),
      ),
      ?navigationBar,
    ],
  );
}

class ModernShopInfoPanel extends StatefulWidget {
  const ModernShopInfoPanel({
    super.key,
    required this.footer,
    this.alwaysExpanded = false,
  });
  final ModernShopFooter footer;
  final bool alwaysExpanded;
  @override
  State<ModernShopInfoPanel> createState() => _ModernShopInfoPanelState();
}

class _ModernShopInfoPanelState extends State<ModernShopInfoPanel> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) {
    final f = widget.footer;
    if (!f.setting.enabled) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Material(
        color: f.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(f.setting.radius),
          side: BorderSide(color: f.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!widget.alwaysExpanded)
              Semantics(
                button: true,
                expanded: _expanded,
                child: InkWell(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.storefront_outlined,
                          color: f.accent,
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '店家資訊',
                                style: TextStyle(
                                  color: f.ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '營業時間・地址・聯絡方式',
                                style: TextStyle(color: f.muted, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: f.muted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            if (_expanded || widget.alwaysExpanded)
              Padding(
                padding: const EdgeInsets.all(18),
                child: f.buildInfoBody(context),
              ),
          ],
        ),
      ),
    );
  }
}
