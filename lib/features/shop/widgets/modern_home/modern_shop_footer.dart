import 'home_desktop_layout.dart';
import 'editorial_section_widgets.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
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
  String get introduction =>
      setting.introText ??
      (value('aboutDescription').isNotEmpty
          ? value('aboutDescription')
          : value('description').isNotEmpty
          ? value('description')
          : value('aboutSubtitle'));
  List<String> get contactIds => [
    'phone',
    'map',
    'line',
    if (value('igUrl').isNotEmpty) 'instagram',
    if (value('fbUrl').isNotEmpty) 'facebook',
  ];
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
    if (setting.layout == 'photoContact') {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onClose != null)
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: '關閉店家資訊',
                onPressed: onClose,
                icon: Icon(Icons.close, color: ink),
              ),
            ),
          _photoContact(image),
        ],
      );
    }
    if (const [
      'infoActions',
      'brandColumns',
      'photoDetails',
      'brandSplit',
      'photoThree',
      'photoRight',
      'editorialPhoto',
    ].contains(setting.layout)) {
      return _composedInfo(context, image, onClose);
    }
    final hasImage = setting.imageSource != 'none' && setting.layout != 'plain';
    final centered = setting.layout == 'centered';
    final intro = introduction;
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
      if (contactIds.contains('phone') && value('phone').isNotEmpty)
        _action(
          setting.phoneLabel,
          Icons.phone_outlined,
          () => _callPhone(value('phone')),
        ),
      if (contactIds.contains('map') && address.isNotEmpty)
        _action(
          setting.mapLabel,
          Icons.near_me_outlined,
          () => _openMap(address),
        ),
      if (contactIds.contains('line') && value('lineUrl').isNotEmpty)
        _action(
          setting.lineLabel,
          FontAwesomeIcons.line,
          () => _openUrl(value('lineUrl')),
        ),
      if (contactIds.contains('instagram') && value('igUrl').isNotEmpty)
        _action(
          'Instagram',
          FontAwesomeIcons.instagram,
          () => _openUrl(value('igUrl')),
        ),
      if (contactIds.contains('facebook') && value('fbUrl').isNotEmpty)
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
        for (final key in setting.orderedFields)
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

  Widget _composedInfo(
    BuildContext context,
    String image,
    VoidCallback? onClose,
  ) => LayoutBuilder(
    builder: (context, c) {
      final u = (c.maxWidth / 500).clamp(.78, 1.15).toDouble();
      final gap = 12 * u;
      final intro = introduction;
      Widget identity() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (setting.showName)
            Row(
              children: [
                if (setting.imageSource == 'logo') ...[
                  SizedBox(
                    width: 34 * u,
                    height: 34 * u,
                    child: sectionPhoto(image, fit: BoxFit.contain),
                  ),
                  SizedBox(width: 6 * u),
                ],
                Expanded(
                  child: Text(
                    shopName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 19 * u,
                      height: 1.3,
                      fontWeight: FontWeight.w800,
                      color: ink,
                    ),
                  ),
                ),
              ],
            ),
          if (setting.showIntro && intro.isNotEmpty)
            Padding(
              padding: EdgeInsets.only(top: 5 * u),
              child: Text(
                intro,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12 * u, height: 1.45, color: muted),
              ),
            ),
        ],
      );
      final fieldValues = <String, String>{
        'hours': hours,
        'address': address,
        'phone': value('phone'),
        'license': value('licenseNumber'),
        'tax': shop['showTaxId'] == true ? value('taxId') : '',
      };
      final fieldIcons = <String, IconData>{
        'hours': Icons.schedule_outlined,
        'address': Icons.location_on_outlined,
        'phone': Icons.phone_outlined,
        'license': Icons.verified_outlined,
        'tax': Icons.receipt_long_outlined,
      };
      Widget details() => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final key in setting.orderedFields)
            if ((fieldValues[key] ?? '').isNotEmpty)
              Padding(
                padding: EdgeInsets.symmetric(vertical: 4 * u),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(fieldIcons[key], size: 18 * u, color: ink),
                    SizedBox(width: 7 * u),
                    Expanded(
                      child: Text(
                        '${HomeShopInfoSetting.fieldLabels[key]}  ${fieldValues[key]}',
                        style: TextStyle(
                          fontSize: 13 * u,
                          height: 1.45,
                          color: ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
        ],
      );
      Widget photo({double? width, double? height}) {
        if (setting.imageSource == 'none' || setting.imageSource == 'logo') {
          return const SizedBox.shrink();
        }
        Widget pic = SizedBox(
          width: width,
          height: height ?? 132 * u,
          child: sectionPhoto(
            image,
            fit: setting.imageFit == 'contain' ? BoxFit.contain : BoxFit.cover,
          ),
        );
        if (setting.photoShape == 'circle') return ClipOval(child: pic);
        return ClipRRect(
          borderRadius: BorderRadius.circular(
            setting.photoShape == 'square' ? 0 : setting.radius / 2,
          ),
          child: pic,
        );
      }

      Widget action(String id) {
        final label = switch (id) {
          'phone' => setting.phoneLabel,
          'map' => setting.mapLabel,
          'line' => setting.lineLabel,
          'instagram' => 'Instagram',
          _ => 'Facebook',
        };
        final target = switch (id) {
          'phone' => value('phone'),
          'map' => address,
          'line' => value('lineUrl'),
          'instagram' => value('igUrl'),
          _ => value('fbUrl'),
        };
        final Object icon = switch (id) {
          'phone' => Icons.phone,
          'map' => Icons.location_on,
          'line' => FontAwesomeIcons.line,
          'instagram' => FontAwesomeIcons.instagram,
          _ => FontAwesomeIcons.facebookF,
        };
        final color = setting.buttonStyle == 'mixed' && id == 'line'
            ? const Color(0xFF06B854)
            : accent;
        final filled =
            setting.buttonStyle == 'filled' ||
            (setting.buttonStyle == 'mixed' && id != 'map');
        final light = setting.buttonStyle == 'light';
        final fill = light
            ? Colors.white
            : filled
            ? color
            : Colors.transparent;
        final fg = light
            ? (id == 'line' ? const Color(0xFF06B854) : accent)
            : filled
            ? (ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                  ? Colors.white
                  : const Color(0xFF16344B))
            : ink;
        Widget glyph(double size) => icon is IconData
            ? Icon(icon, size: size, color: fg)
            : FaIcon(icon as FaIconData, size: size, color: fg);
        final circle = setting.actionPresentation == 'circle';
        final tile = setting.actionPresentation == 'tile';
        Widget body;
        if (circle || tile) {
          body = Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 46 * u,
                height: 46 * u,
                decoration: BoxDecoration(
                  color: fill,
                  shape: BoxShape.circle,
                  border: setting.buttonStyle == 'text'
                      ? null
                      : Border.all(color: color.withValues(alpha: .45)),
                ),
                child: Center(child: glyph(23 * u)),
              ),
              SizedBox(height: 5 * u),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  maxLines: 1,
                  style: TextStyle(fontSize: 11 * u, color: ink),
                ),
              ),
            ],
          );
          if (tile) {
            body = Container(
              padding: EdgeInsets.symmetric(vertical: 8 * u, horizontal: 4 * u),
              decoration: BoxDecoration(
                border: Border.all(color: border),
                borderRadius: BorderRadius.circular(
                  setting.radius == 0 ? 18 : setting.radius,
                ),
              ),
              child: body,
            );
          }
        } else {
          body = Container(
            padding: EdgeInsets.symmetric(vertical: 9 * u, horizontal: 5 * u),
            decoration: BoxDecoration(
              color: fill,
              border: setting.buttonStyle == 'text'
                  ? null
                  : Border.all(color: color.withValues(alpha: .5)),
              borderRadius: BorderRadius.circular(
                setting.actionPresentation == 'pill' ? 99 : 10,
              ),
            ),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  glyph(17 * u),
                  SizedBox(width: 4 * u),
                  Text(
                    label,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11 * u,
                      color: fg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return Semantics(
          button: true,
          enabled: target.isNotEmpty && !isPreview,
          label: label,
          child: Opacity(
            opacity: target.isEmpty ? .4 : 1,
            child: InkWell(
              onTap: target.isEmpty || isPreview
                  ? null
                  : () {
                      if (id == 'phone') {
                        _callPhone(target);
                      } else if (id == 'map') {
                        _openMap(target);
                      } else {
                        _openUrl(target);
                      }
                    },
              borderRadius: BorderRadius.circular(12),
              child: body,
            ),
          ),
        );
      }

      Widget actions() {
        if (!setting.showActions || contactIds.isEmpty) {
          return const SizedBox.shrink();
        }
        final items = [for (final id in contactIds) action(id)];
        if (setting.actionLayout == 'vertical') {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) SizedBox(height: 6 * u),
                items[i],
              ],
            ],
          );
        }
        if (setting.actionLayout == 'wrap') {
          return Wrap(
            spacing: 6 * u,
            runSpacing: 6 * u,
            children: [
              for (final item in items) SizedBox(width: 88 * u, child: item),
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0) SizedBox(width: 5 * u),
              Expanded(child: items[i]),
            ],
          ],
        );
      }

      Widget content() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          identity(),
          SizedBox(height: 6 * u),
          details(),
        ],
      );
      Widget infoAndActions() => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          content(),
          SizedBox(height: 8 * u),
          actions(),
        ],
      );
      final hasPhoto =
          setting.imageSource != 'none' && setting.imageSource != 'logo';
      final width = c.maxWidth;
      Widget body;
      switch (setting.layout) {
        case 'infoActions':
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!setting.showName && setting.sectionTitle.isNotEmpty) ...[
                Text(
                  setting.sectionTitle,
                  style: TextStyle(
                    fontSize: 19 * u,
                    color: ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: gap),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(flex: 6, child: content()),
                  Container(
                    width: 1,
                    height: 70 * u,
                    color: border,
                    margin: EdgeInsets.symmetric(horizontal: gap),
                  ),
                  Expanded(flex: 5, child: actions()),
                ],
              ),
            ],
          );
        case 'brandColumns':
          body = width < 360
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    identity(),
                    SizedBox(height: gap),
                    Row(
                      children: [
                        Expanded(child: details()),
                        SizedBox(width: gap),
                        Expanded(child: actions()),
                      ],
                    ),
                  ],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(flex: 4, child: identity()),
                    Container(
                      width: 1,
                      height: 75 * u,
                      color: border,
                      margin: EdgeInsets.symmetric(horizontal: gap),
                    ),
                    Expanded(flex: 5, child: details()),
                    SizedBox(width: gap),
                    Expanded(flex: 5, child: actions()),
                  ],
                );
        case 'brandSplit':
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 5, child: identity()),
              Container(
                width: 1,
                height: 85 * u,
                color: border,
                margin: EdgeInsets.symmetric(horizontal: gap),
              ),
              Expanded(
                flex: 6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    details(),
                    SizedBox(height: gap),
                    actions(),
                  ],
                ),
              ),
            ],
          );
        case 'photoThree':
          body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (setting.sectionTitle.isNotEmpty) ...[
                Text(
                  setting.sectionTitle,
                  style: TextStyle(
                    fontSize: 19 * u,
                    color: ink,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: gap),
              ],
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (hasPhoto) ...[
                    SizedBox(
                      width: width * setting.photoFraction,
                      child: photo(height: 120 * u),
                    ),
                    SizedBox(width: gap),
                  ],
                  Expanded(flex: 5, child: content()),
                  SizedBox(width: gap),
                  Expanded(flex: 4, child: actions()),
                ],
              ),
            ],
          );
        case 'photoRight':
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 6, child: content()),
              SizedBox(width: gap),
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (hasPhoto) ...[
                      photo(height: 76 * u),
                      SizedBox(height: gap),
                    ],
                    actions(),
                  ],
                ),
              ),
            ],
          );
        default:
          body = Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (hasPhoto) ...[
                SizedBox(
                  width: width * setting.photoFraction,
                  child: photo(
                    height: setting.photoShape == 'circle'
                        ? width * setting.photoFraction
                        : 155 * u,
                  ),
                ),
                SizedBox(width: gap),
              ],
              Expanded(child: infoAndActions()),
            ],
          );
      }
      return Stack(
        children: [
          if (setting.decoration != 'none')
            Positioned(
              top: 0,
              right: 0,
              child: IgnorePointer(
                child: Opacity(
                  opacity: .12,
                  child: Icon(
                    setting.decoration == 'leaf'
                        ? Icons.eco_outlined
                        : setting.decoration == 'cat'
                        ? Icons.cruelty_free_outlined
                        : Icons.pets,
                    size: 70 * u,
                    color: accent,
                  ),
                ),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (onClose != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    tooltip: '關閉店家資訊',
                    onPressed: onClose,
                    icon: Icon(Icons.close, color: ink),
                  ),
                ),
              body,
            ],
          ),
        ],
      );
    },
  );

  Widget _photoContact(String image) => LayoutBuilder(
    builder: (context, c) {
      final desktop = HomeDesktopLayoutScope.maybeOf(context);
      final u = desktop?.cardScale ?? c.maxWidth / 790;
      final intro = introduction;
      final localTheme = HomeThemeModel(
        backgroundColorValue: surface.toARGB32(),
        cardColorValue: surface.toARGB32(),
        cardBorderColorValue: border.toARGB32(),
        primaryColorValue: accent.toARGB32(),
        textColorValue: ink.toARGB32(),
      );
      Widget contact(
        String id,
        String label,
        Object icon,
        String target,
        VoidCallback action,
      ) {
        final filled =
            setting.buttonStyle == 'filled' ||
            (setting.buttonStyle == 'mixed' && id != 'map');
        final color = setting.buttonStyle == 'mixed' && id == 'line'
            ? const Color(0xFF06B854)
            : accent;
        return Opacity(
          opacity: target.isEmpty ? .45 : 1,
          child: InkWell(
            onTap: target.isEmpty || isPreview ? null : action,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 10 * u,
                vertical: 11 * u,
              ),
              decoration: BoxDecoration(
                color: filled ? color : null,
                border: setting.buttonStyle == 'text'
                    ? null
                    : Border.all(color: color.withValues(alpha: .5)),
                borderRadius: BorderRadius.circular(12 * u),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon is IconData)
                    Icon(icon, size: 23 * u, color: filled ? Colors.white : ink)
                  else
                    FaIcon(
                      icon as FaIconData,
                      size: 23 * u,
                      color: filled ? Colors.white : ink,
                    ),
                  SizedBox(width: 7 * u),
                  Flexible(
                    child: editorialText(
                      label,
                      21 * u,
                      localTheme,
                      bold: true,
                      lines: 1,
                      color: filled ? Colors.white : ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }

      final buttons = <Widget>[
        for (final id in contactIds)
          if (id == 'phone')
            contact(
              id,
              setting.phoneLabel,
              Icons.phone,
              value('phone'),
              () => _callPhone(value('phone')),
            )
          else if (id == 'map')
            contact(
              id,
              setting.mapLabel,
              Icons.location_on,
              address,
              () => _openMap(address),
            )
          else if (id == 'line')
            contact(
              id,
              setting.lineLabel,
              FontAwesomeIcons.line,
              value('lineUrl'),
              () => _openUrl(value('lineUrl')),
            )
          else if (id == 'instagram')
            contact(
              id,
              'Instagram',
              FontAwesomeIcons.instagram,
              value('igUrl'),
              () => _openUrl(value('igUrl')),
            )
          else if (id == 'facebook')
            contact(
              id,
              'Facebook',
              FontAwesomeIcons.facebookF,
              value('fbUrl'),
              () => _openUrl(value('fbUrl')),
            ),
      ];
      Widget detail(IconData icon, String text) => Padding(
        padding: EdgeInsets.only(bottom: 8 * u),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 25 * u, color: accent),
            SizedBox(width: 12 * u),
            Expanded(child: editorialText(text, 21 * u, localTheme, lines: 2)),
          ],
        ),
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (setting.sectionTitle.isNotEmpty) ...[
            EditorialSectionHeading(
              title: setting.sectionTitle,
              theme: localTheme,
            ),
            SizedBox(height: 12 * u),
          ],
          Container(
            padding: EdgeInsets.all(10 * u),
            decoration: BoxDecoration(
              border: Border.all(color: border),
              borderRadius: BorderRadius.circular(setting.radius),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (setting.imageSource != 'none') ...[
                  SizedBox(
                    width: desktop == null
                        ? (c.maxWidth - 20 * u) * setting.photoFraction
                        : ((c.maxWidth - 20 * u) * setting.photoFraction).clamp(
                            180.0,
                            280.0,
                          ),
                    height: desktop == null ? 158 * u : 160,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(setting.radius / 2),
                      child: sectionPhoto(
                        image,
                        fit: setting.imageFit == 'contain'
                            ? BoxFit.contain
                            : BoxFit.cover,
                      ),
                    ),
                  ),
                  SizedBox(width: 18 * u),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (setting.showName)
                        editorialText(shopName, 24 * u, localTheme, bold: true),
                      if (setting.showIntro && intro.isNotEmpty)
                        Padding(
                          padding: EdgeInsets.only(bottom: 8 * u),
                          child: editorialText(intro, 21 * u, localTheme),
                        ),
                      for (final key in setting.orderedFields)
                        if (key == 'hours' && hours.isNotEmpty)
                          detail(Icons.schedule_outlined, hours)
                        else if (key == 'address' && address.isNotEmpty)
                          detail(Icons.location_on, address)
                        else if (key == 'phone' && value('phone').isNotEmpty)
                          detail(Icons.phone_outlined, value('phone'))
                        else if (key == 'license' &&
                            value('licenseNumber').isNotEmpty)
                          detail(
                            Icons.verified_outlined,
                            value('licenseNumber'),
                          )
                        else if (key == 'tax' &&
                            shop['showTaxId'] == true &&
                            value('taxId').isNotEmpty)
                          detail(Icons.receipt_long, value('taxId')),
                      if (setting.showActions && buttons.isNotEmpty)
                        setting.actionLayout == 'threeColumns'
                            ? Row(
                                children: [
                                  for (var i = 0; i < buttons.length; i++) ...[
                                    if (i > 0) SizedBox(width: 8 * u),
                                    Expanded(child: buttons[i]),
                                  ],
                                ],
                              )
                            : Wrap(
                                spacing: 8 * u,
                                runSpacing: 8 * u,
                                children: buttons,
                              ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

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
    if (widget.alwaysExpanded && f.setting.layout == 'photoContact') {
      return f.buildInfoBody(context);
    }
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
