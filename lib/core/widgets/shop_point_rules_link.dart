import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'package:petnest_saas/core/models/point_setting_model.dart';
import 'package:petnest_saas/core/services/point_setting_service.dart';

class ShopPointSettings extends StatefulWidget {
  const ShopPointSettings({
    super.key,
    required this.shopId,
    required this.builder,
  });

  final String shopId;
  final Widget Function(BuildContext, PointSettingModel?) builder;

  @override
  State<ShopPointSettings> createState() => _ShopPointSettingsState();
}

class _ShopPointSettingsState extends State<ShopPointSettings> {
  Stream<PointSettingModel>? _settings;

  @override
  void initState() {
    super.initState();
    _bindShop();
  }

  @override
  void didUpdateWidget(covariant ShopPointSettings oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.shopId.trim() != widget.shopId.trim()) _bindShop();
  }

  void _bindShop() {
    final shopId = widget.shopId.trim();
    _settings = shopId.isEmpty
        ? null
        : PointSettingService.instance.streamPointSetting(shopId);
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<PointSettingModel>(
    key: ValueKey(widget.shopId.trim()),
    stream: _settings,
    builder: (context, snapshot) {
      final setting = snapshot.data;
      if (setting == null ||
          snapshot.hasError ||
          !setting.enabled ||
          setting.shopId != widget.shopId.trim()) {
        return widget.builder(context, null);
      }
      return widget.builder(context, setting);
    },
  );
}

String _stayRule(PointSettingModel setting) =>
    setting.calculationType == PointSettingModel.calculationTypeNight
    ? '每住 1 晚得 ${setting.pointsPerNight} 點'
    : '住宿每滿 NT\$${setting.amountPerPoint} 得 1 點';

class ShopPointRulesDetails extends StatelessWidget {
  const ShopPointRulesDetails({
    super.key,
    required this.setting,
    required this.theme,
    this.shopName = '',
  });

  final PointSettingModel setting;
  final HomeThemeModel theme;
  final String shopName;

  @override
  Widget build(BuildContext context) {
    final channels = [
      if (setting.canSpendOn('stay')) '住宿',
      if (setting.canSpendOn('daycare')) '安親',
      if (setting.canSpendOn('store')) '商城',
    ];
    final name = shopName.trim();
    final description = setting.description.trim();
    final pointName = setting.pointName.trim();
    final detailStyle = TextStyle(
      color: theme.secondaryTextColor,
      fontSize: 13,
      height: 1.55,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: theme.primaryColor.withValues(alpha: .09),
          ),
          child: Row(
            children: [
              Icon(Icons.stars_outlined, size: 28, color: theme.primaryColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '本店點數規則',
                      style: TextStyle(
                        color: theme.textColor,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      [
                        if (name.isNotEmpty) name,
                        if (pointName.isNotEmpty) pointName,
                      ].join('・'),
                      style: detailStyle,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _section(
          icon: Icons.add_circle_outline,
          title: '點數取得',
          lines: [
            '${_stayRule(setting)}，於住宿訂單完成後發放。',
            if (setting.minimumOrderAmount > 0)
              '住宿訂單滿 NT\$${setting.minimumOrderAmount} 才發放點數。',
            if (setting.maximumPointsPerBooking > 0)
              '每筆住宿訂單最多可獲得 ${setting.maximumPointsPerBooking} 點。',
            if (setting.daycareEarnEnabled) ...[
              '安親消費每滿 NT\$${setting.daycareAmountPerPoint} 得 1 點，於安親訂單完成後發放。',
              if (setting.daycareMinimumOrderAmount > 0)
                '安親訂單滿 NT\$${setting.daycareMinimumOrderAmount} 才發放點數。',
              if (setting.daycareMaximumPointsPerBooking > 0)
                '每筆安親訂單最多可獲得 ${setting.daycareMaximumPointsPerBooking} 點。',
            ],
          ],
        ),
        _section(
          icon: Icons.calendar_today_outlined,
          title: '有效期限',
          lines: [
            setting.pointExpireDays > 0
                ? '每筆點數自發放日起有效 ${setting.pointExpireDays} 天。'
                : '本店點數無使用期限。',
          ],
        ),
        _section(
          icon: Icons.redeem_outlined,
          title: '折抵與兌換',
          lines: [
            if (channels.isNotEmpty)
              '${channels.join('、')}結帳可使用點數折抵，每 ${setting.spendRatePointsPerNtd} 點折抵 NT\$1。'
            else
              '本店目前未開放點數折抵消費。',
            if (setting.allowPointsExchange)
              '可使用點數兌換本店指定商品。'
            else
              '本店目前未開放點數兌換商品。',
            '點數限於發放店家使用。',
          ],
        ),
        if (description.isNotEmpty)
          _section(
            icon: Icons.info_outline,
            title: '店家補充說明',
            lines: [description],
          ),
      ],
    );
  }

  Widget _section({
    required IconData icon,
    required String title,
    required List<String> lines,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.cardBorderColor),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.primaryColor, size: 19),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: theme.textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                for (final line in lines)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      line,
                      style: TextStyle(
                        color: theme.secondaryTextColor,
                        fontSize: 13,
                        height: 1.55,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ShopPointRulesLink extends StatelessWidget {
  const ShopPointRulesLink({
    super.key,
    required this.shopId,
    required this.shopName,
    required this.theme,
  });

  final String shopId;
  final String shopName;
  final HomeThemeModel theme;

  void _showRules(BuildContext context, PointSettingModel setting) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: theme.cardColor,
        surfaceTintColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        constraints: const BoxConstraints(maxWidth: 520),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: SingleChildScrollView(
                  child: ShopPointRulesDetails(
                    setting: setting,
                    theme: theme,
                    shopName: shopName,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: theme.buttonBackgroundColor,
                  foregroundColor: theme.buttonForegroundColor,
                  minimumSize: const Size(0, 44),
                ),
                child: const Text('關閉'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ShopPointSettings(
    shopId: shopId,
    builder: (context, setting) {
      if (setting == null) return const SizedBox.shrink();

      final shape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: theme.cardBorderColor),
      );
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Material(
          color: theme.cardColor,
          shape: shape,
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.stars_outlined, color: theme.primaryColor),
            title: Text(
              '本店點數規則',
              style: TextStyle(
                color: theme.textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(
              _stayRule(setting),
              style: TextStyle(color: theme.secondaryTextColor),
            ),
            trailing: Icon(Icons.chevron_right, color: theme.primaryColor),
            onTap: () => _showRules(context, setting),
          ),
        ),
      );
    },
  );
}
