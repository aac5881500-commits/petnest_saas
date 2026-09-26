// 檔案名稱：lib/features/shop/pages/shop_point_setting_page.dart
// 功能說明：點數制度、安親發點與折抵設定；發點固定訂單完成後才入點。

import 'package:flutter/material.dart';
import '../../admin/pages/admin_point_center_stats.dart';
import '../../admin/pages/admin_point_reward_list_page.dart';
import '../../../core/models/daycare_settings_model.dart';
import '../../../core/models/point_setting_model.dart';
import '../../../core/services/daycare_settings_service.dart';
import '../../../core/services/point_setting_service.dart';
import '../../../core/services/shop_service.dart';

class ShopPointSettingPage extends StatefulWidget {
  const ShopPointSettingPage({
    super.key,
    required this.shopId,
    this.embedded = false,
  });

  final String shopId;
  final bool embedded;

  @override
  State<ShopPointSettingPage> createState() => _ShopPointSettingPageState();
}

class _ShopPointSettingPageState extends State<ShopPointSettingPage> {
  static const double _maxWidth = 1200;
  static const double _desktopWidth = 900;

  final PointSettingService _service = PointSettingService.instance;
  final TextEditingController _amountPerPointController =
      TextEditingController();
  final TextEditingController _pointsPerNightController =
      TextEditingController();
  final TextEditingController _minimumOrderAmountController =
      TextEditingController();
  final TextEditingController _maximumPointsController =
      TextEditingController();
  final TextEditingController _expireDaysController = TextEditingController();
  final TextEditingController _pointNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _daycareAmountPerPointController =
      TextEditingController();
  final TextEditingController _daycareMinimumController =
      TextEditingController();
  final TextEditingController _daycareMaximumController =
      TextEditingController();
  final TextEditingController _pointsPerNtdController = TextEditingController();

  bool _initialized = false;
  bool _saving = false;
  bool _enabled = false;
  bool _allowPointsExchange = true;
  String _calculationType = PointSettingModel.calculationTypeAmount;
  bool _daycareEarnEnabled = false;
  bool _spendEnabled = false;
  bool _staySpendEnabled = false;
  bool _daycareSpendEnabled = false;
  bool _storeSpendEnabled = false;

  bool get _isAmountCalculation =>
      _calculationType == PointSettingModel.calculationTypeAmount;

  Color get _brand => Theme.of(context).colorScheme.primary;

  @override
  void dispose() {
    _amountPerPointController.dispose();
    _pointsPerNightController.dispose();
    _minimumOrderAmountController.dispose();
    _maximumPointsController.dispose();
    _expireDaysController.dispose();
    _pointNameController.dispose();
    _descriptionController.dispose();
    _daycareAmountPerPointController.dispose();
    _daycareMinimumController.dispose();
    _daycareMaximumController.dispose();
    _pointsPerNtdController.dispose();
    super.dispose();
  }

  void _applySetting(PointSettingModel setting) {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _enabled = setting.enabled;
    _calculationType = setting.calculationType;
    _allowPointsExchange = setting.allowPointsExchange;
    _amountPerPointController.text = setting.amountPerPoint.toString();
    _pointsPerNightController.text = setting.pointsPerNight.toString();
    _minimumOrderAmountController.text = setting.minimumOrderAmount.toString();
    _maximumPointsController.text = setting.maximumPointsPerBooking.toString();
    _expireDaysController.text = setting.pointExpireDays.toString();
    _pointNameController.text = setting.pointName;
    _descriptionController.text = setting.description;
    _daycareEarnEnabled = setting.daycareEarnEnabled;
    _daycareSpendEnabled = setting.daycareSpendEnabled;
    _staySpendEnabled = setting.staySpendEnabled;
    _storeSpendEnabled = setting.storeSpendEnabled;
    _spendEnabled = setting.spendEnabled;
    _pointsPerNtdController.text =
        (setting.pointsPerNtd > 0 ? setting.pointsPerNtd : 1).toString();
    _daycareAmountPerPointController.text = setting.daycareAmountPerPoint
        .toString();
    _daycareMinimumController.text = setting.daycareMinimumOrderAmount
        .toString();
    _daycareMaximumController.text = setting.daycareMaximumPointsPerBooking
        .toString();
  }

  Future<void> _save() async {
    final int? amountPerPoint = int.tryParse(
      _amountPerPointController.text.trim(),
    );
    final int? pointsPerNight = int.tryParse(
      _pointsPerNightController.text.trim(),
    );
    final int? minimumOrderAmount = int.tryParse(
      _minimumOrderAmountController.text.trim(),
    );
    final int? maximumPoints = int.tryParse(
      _maximumPointsController.text.trim(),
    );
    final int? expireDays = int.tryParse(_expireDaysController.text.trim());
    final int? pointsPerNtd = int.tryParse(_pointsPerNtdController.text.trim());
    if (_isAmountCalculation &&
        (amountPerPoint == null || amountPerPoint <= 0)) {
      _showMessage('每點消費金額必須大於 0');
      return;
    }
    if (!_isAmountCalculation &&
        (pointsPerNight == null || pointsPerNight <= 0)) {
      _showMessage('每晚發放點數必須大於 0');
      return;
    }
    if (minimumOrderAmount == null || minimumOrderAmount < 0) {
      _showMessage('最低消費金額不能小於 0');
      return;
    }
    if (maximumPoints == null || maximumPoints < 0) {
      _showMessage('單筆最多點數不能小於 0');
      return;
    }
    if (expireDays == null || expireDays < 0) {
      _showMessage('點數有效天數不能小於 0');
      return;
    }
    if (pointsPerNtd == null || pointsPerNtd <= 0) {
      _showMessage('折抵比例必須大於 0');
      return;
    }
    if (_pointNameController.text.trim().isEmpty) {
      _showMessage('請輸入點數名稱');
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.savePointSetting(
        shopId: widget.shopId,
        enabled: _enabled,
        calculationType: _calculationType,
        amountPerPoint: amountPerPoint ?? 100,
        pointsPerNight: pointsPerNight ?? 1,
        minimumOrderAmount: minimumOrderAmount,
        maximumPointsPerBooking: maximumPoints,
        pointExpireDays: expireDays,
        issueAfterCompleted: true,
        allowManualAdjustment: true,
        allowPointsExchange: _allowPointsExchange,
        pointName: _pointNameController.text.trim(),
        description: _descriptionController.text.trim(),
        daycareEarnEnabled: _daycareEarnEnabled,
        daycareSpendEnabled: _daycareSpendEnabled,
        staySpendEnabled: _staySpendEnabled,
        storeSpendEnabled: _storeSpendEnabled,
        spendEnabled: _spendEnabled,
        pointsPerNtd: pointsPerNtd,
        daycareCalculationType: PointSettingModel.daycareCalculationTypeAmount,
        daycareAmountPerPoint:
            int.tryParse(_daycareAmountPerPointController.text.trim()) ?? 100,
        daycarePointsPerOrder: 0,
        daycareMinimumOrderAmount:
            int.tryParse(_daycareMinimumController.text.trim()) ?? 0,
        daycareMaximumPointsPerBooking:
            int.tryParse(_daycareMaximumController.text.trim()) ?? 0,
      );
      if (mounted) {
        _showMessage('點數設定已儲存');
      }
    } catch (error) {
      if (mounted) {
        _showMessage(_readableSaveError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  String _readableSaveError(Object error) {
    final String raw = error.toString().toLowerCase();
    if (raw.contains('permission-denied') ||
        raw.contains('permission_denied')) {
      return '儲存失敗：目前沒有權限修改點數設定。表單內容已保留。';
    }
    if (raw.contains('network') ||
        raw.contains('unavailable') ||
        raw.contains('offline')) {
      return '儲存失敗：網路連線不穩定。表單內容已保留，請稍後再試。';
    }
    return '儲存失敗，表單內容已保留，請稍後再試。';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  void _openLedger() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) {
          return AdminPointRewardListPage(
            shopId: widget.shopId,
            initialSection: PointCenterSection.ledger,
          );
        },
      ),
    );
  }

  String _positiveText(TextEditingController controller) {
    final int? value = int.tryParse(controller.text.trim());
    if (value == null || value <= 0) {
      return '—';
    }
    return value.toString();
  }

  String _capText(TextEditingController controller) {
    final int value = int.tryParse(controller.text.trim()) ?? 0;
    if (value > 0) {
      return '單筆最多 $value 點';
    }
    return '單筆不限點數';
  }

  String get _systemRule {
    if (!_enabled) {
      return '尚未啟用';
    }
    final String name = _pointNameController.text.trim();
    if (name.isEmpty) {
      return '已啟用';
    }
    return '名稱：$name';
  }

  String get _stayRule {
    if (!_enabled) {
      return '尚未啟用';
    }
    if (_isAmountCalculation) {
      return '每滿 NT\$${_positiveText(_amountPerPointController)} 得 1 點';
    }
    return '每住 1 晚得 ${_positiveText(_pointsPerNightController)} 點';
  }

  String get _daycareRule {
    if (!_enabled || !_daycareEarnEnabled) {
      return '尚未啟用';
    }
    return '每滿 NT\$${_positiveText(_daycareAmountPerPointController)} 得 1 點';
  }

  String get _spendRule {
    if (!_enabled || !_spendEnabled) {
      return '尚未啟用';
    }
    final int points = int.tryParse(_pointsPerNtdController.text.trim()) ?? 1;
    final int safe = points <= 0 ? 1 : points;
    return '$safe 點折 NT\$1';
  }

  String get _staySummary {
    if (!_enabled) {
      return '住宿發點尚未啟用。';
    }
    final String cap = _capText(_maximumPointsController);
    if (_isAmountCalculation) {
      return '目前：住宿消費每滿 NT\$${_positiveText(_amountPerPointController)} 贈 1 點，$cap。';
    }
    return '目前：每住宿 1 晚贈 ${_positiveText(_pointsPerNightController)} 點，$cap。';
  }

  String get _daycareSummary {
    if (!_enabled || !_daycareEarnEnabled) {
      return '安親發點尚未啟用。';
    }
    return '目前：安親消費每滿 NT\$${_positiveText(_daycareAmountPerPointController)} 贈 1 點，${_capText(_daycareMaximumController)}。';
  }

  String get _spendPreview {
    final int points = int.tryParse(_pointsPerNtdController.text.trim()) ?? 1;
    final int safe = points <= 0 ? 1 : points;
    return '$safe 點 = NT\$1';
  }

  @override
  Widget build(BuildContext context) {
    final Widget content = StreamBuilder<PointSettingModel>(
      stream: _service.streamPointSetting(widget.shopId),
      builder:
          (BuildContext context, AsyncSnapshot<PointSettingModel> snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('讀取點數設定失敗：${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            _applySetting(snapshot.data!);
            final bool desktop =
                MediaQuery.sizeOf(context).width >= _desktopWidth;
            return ColoredBox(
              color: const Color(0xFFF5F7FB),
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: ListView(
                      padding: EdgeInsets.fromLTRB(
                        16,
                        16,
                        16,
                        desktop ? 24 : 8,
                      ),
                      children: <Widget>[
                        Align(
                          alignment: Alignment.topCenter,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxWidth: _maxWidth,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _header(desktop),
                                const SizedBox(height: 16),
                                _summaryGrid(desktop),
                                const SizedBox(height: 16),
                                if (desktop)
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Expanded(
                                        child: Column(
                                          children: <Widget>[
                                            _basicCard(),
                                            _stayCard(),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          children: <Widget>[
                                            _daycareCard(),
                                            _spendCard(),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                else ...<Widget>[
                                  _basicCard(),
                                  _stayCard(),
                                  _daycareCard(),
                                  _spendCard(),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!desktop) _mobileSaveBar(),
                ],
              ),
            );
          },
    );
    if (widget.embedded) {
      return content;
    }
    return Scaffold(
      appBar: AppBar(title: const Text('點數設定')),
      body: content,
    );
  }

  Widget _header(bool desktop) {
    final Widget title = const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '點數設定',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Color(0xFF1F2937),
          ),
        ),
        SizedBox(height: 4),
        Text(
          '設定會員點數的取得、折抵與兌換規則。',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF6B7280),
            height: 1.35,
          ),
        ),
      ],
    );
    final Widget ledger = _outlineButton(
      icon: Icons.receipt_long_outlined,
      label: '查看點數流水',
      onPressed: _openLedger,
    );
    final Widget save = _saveButton(height: 38);
    if (!desktop) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[title, const SizedBox(height: 10), ledger],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        Expanded(child: title),
        const SizedBox(width: 12),
        ledger,
        const SizedBox(width: 8),
        save,
      ],
    );
  }

  Widget _summaryGrid(bool desktop) {
    final List<Widget> cards = <Widget>[
      _summaryCard(
        icon: Icons.stars_outlined,
        title: '點數制度',
        rule: _systemRule,
        enabled: _enabled,
      ),
      _summaryCard(
        icon: Icons.hotel_outlined,
        title: '住宿發點',
        rule: _stayRule,
        enabled: _enabled,
      ),
      _summaryCard(
        icon: Icons.pets_outlined,
        title: '安親發點',
        rule: _daycareRule,
        enabled: _enabled && _daycareEarnEnabled,
      ),
      _summaryCard(
        icon: Icons.payments_outlined,
        title: '點數折抵',
        rule: _spendRule,
        enabled: _enabled && _spendEnabled,
      ),
    ];
    if (desktop) {
      return Row(
        children: <Widget>[
          for (int i = 0; i < cards.length; i++) ...<Widget>[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    return Column(
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(child: cards[0]),
            const SizedBox(width: 8),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(child: cards[2]),
            const SizedBox(width: 8),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String rule,
    required bool enabled,
  }) {
    return SizedBox(
      height: 84,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, size: 14, color: _brand),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _statusChip(enabled),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                rule,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                  color: Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _basicCard() {
    return _settingCard(
      icon: Icons.tune_outlined,
      title: '基本制度',
      subtitle: '設定點數名稱、有效期限與會員兌換功能。',
      enabled: _enabled,
      onToggle: (bool value) => setState(() => _enabled = value),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _dimmed(
            active: _enabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                _fieldPair(
                  _textField(
                    controller: _pointNameController,
                    label: '點數名稱',
                    maxLength: 10,
                  ),
                  _numberField(
                    controller: _expireDaysController,
                    label: '點數有效天數',
                    suffix: '天',
                    helper: '填 0 代表永久有效',
                  ),
                ),
                const SizedBox(height: 10),
                _textField(
                  controller: _descriptionController,
                  label: '點數制度說明',
                  maxLines: 2,
                ),
                const SizedBox(height: 10),
                _optionRow(
                  icon: Icons.card_giftcard_outlined,
                  title: '允許會員兌換商品',
                  subtitle: '開啟後，會員可使用點數兌換本店已上架商品。',
                  value: _allowPointsExchange,
                  fadeDisabled: false,
                  onChanged: _enabled
                      ? (bool value) =>
                            setState(() => _allowPointsExchange = value)
                      : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _hintBanner('點數屬於各店獨立制度，會員只能在取得點數的店家使用。'),
        ],
      ),
    );
  }

  Widget _stayCard() {
    return _settingCard(
      icon: Icons.hotel_outlined,
      title: '住宿發點',
      subtitle: '設定完成住宿後的會員點數回饋。',
      enabled: _enabled,
      onToggle: (bool value) => setState(() => _enabled = value),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _dimmed(
            active: _enabled,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _modeCard(
                        label: '依消費金額',
                        selected: _isAmountCalculation,
                        onTap: _enabled
                            ? () => setState(
                                () => _calculationType =
                                    PointSettingModel.calculationTypeAmount,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _modeCard(
                        label: '依住宿晚數',
                        selected: !_isAmountCalculation,
                        onTap: _enabled
                            ? () => setState(
                                () => _calculationType =
                                    PointSettingModel.calculationTypeNight,
                              )
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (_isAmountCalculation)
                  _fieldPair(
                    _numberField(
                      controller: _amountPerPointController,
                      label: '每滿',
                      prefix: 'NT\$',
                    ),
                    _lockedField(label: '發', value: '1', suffix: '點'),
                  )
                else
                  _fieldPair(
                    _lockedField(label: '每滿', value: '1', suffix: '晚'),
                    _numberField(
                      controller: _pointsPerNightController,
                      label: '發',
                      suffix: '點',
                    ),
                  ),
                const SizedBox(height: 10),
                _fieldPair(
                  _numberField(
                    controller: _minimumOrderAmountController,
                    label: '最低符合門檻',
                    prefix: 'NT\$',
                  ),
                  _numberField(
                    controller: _maximumPointsController,
                    label: '每筆訂單發點上限',
                    suffix: '點',
                    helper: '填 0 代表不限',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _summaryBanner(_staySummary),
        ],
      ),
    );
  }

  Widget _daycareCard() {
    return StreamBuilder<Map<String, dynamic>?>(
      stream: ShopService.instance.streamShop(widget.shopId),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<Map<String, dynamic>?> shopSnap,
          ) {
            return StreamBuilder<DaycareSettingsModel>(
              stream: DaycareSettingsService.instance.stream(widget.shopId),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<DaycareSettingsModel> daycareSnap,
                  ) {
                    final bool show = DaycareSettingsService.instance
                        .isEnabledForShop(
                          shop: shopSnap.data,
                          settings:
                              daycareSnap.data ?? const DaycareSettingsModel(),
                        );
                    if (!show) {
                      return const SizedBox.shrink();
                    }
                    return _settingCard(
                      icon: Icons.pets_outlined,
                      title: '安親發點',
                      subtitle: '設定完成安親服務後的會員點數回饋。',
                      enabled: _daycareEarnEnabled,
                      onToggle: (bool value) =>
                          setState(() => _daycareEarnEnabled = value),
                      body: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          _dimmed(
                            active: _daycareEarnEnabled,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: <Widget>[
                                _fieldPair(
                                  _numberField(
                                    controller:
                                        _daycareAmountPerPointController,
                                    label: '每滿',
                                    prefix: 'NT\$',
                                  ),
                                  _lockedField(
                                    label: '發',
                                    value: '1',
                                    suffix: '點',
                                  ),
                                ),
                                const SizedBox(height: 10),
                                _fieldPair(
                                  _numberField(
                                    controller: _daycareMinimumController,
                                    label: '最低消費門檻',
                                    prefix: 'NT\$',
                                  ),
                                  _numberField(
                                    controller: _daycareMaximumController,
                                    label: '每筆安親發點上限',
                                    suffix: '點',
                                    helper: '填 0 代表不限',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          _summaryBanner(_daycareSummary),
                        ],
                      ),
                    );
                  },
            );
          },
    );
  }

  Widget _spendCard() {
    return _settingCard(
      icon: Icons.payments_outlined,
      title: '點數折抵',
      subtitle: '設定會員結帳時可使用點數折抵的服務範圍。',
      enabled: _spendEnabled,
      onToggle: (bool value) => setState(() => _spendEnabled = value),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          _dimmed(active: _spendEnabled, child: _spendRateEditor()),
          _optionRow(
            icon: Icons.hotel_outlined,
            title: '住宿可使用點數折抵',
            subtitle: '結帳住宿訂單時可使用點數折抵。',
            value: _staySpendEnabled,
            onChanged: _spendEnabled
                ? (bool value) => setState(() => _staySpendEnabled = value)
                : null,
          ),
          _optionRow(
            icon: Icons.pets_outlined,
            title: '安親可使用點數折抵',
            subtitle: '結帳安親訂單時可使用點數折抵。',
            value: _daycareSpendEnabled,
            onChanged: _spendEnabled
                ? (bool value) => setState(() => _daycareSpendEnabled = value)
                : null,
          ),
          _optionRow(
            icon: Icons.storefront_outlined,
            title: '商城可使用點數折抵',
            subtitle: '僅限折抵商城一般商品；點數兌換商品不適用。',
            value: _storeSpendEnabled,
            onChanged: _spendEnabled
                ? (bool value) => setState(() => _storeSpendEnabled = value)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _spendRateEditor() {
    final Widget fields = Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: <Widget>[
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            '每',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _numberField(
            controller: _pointsPerNtdController,
            label: '點數',
            suffix: '點',
          ),
        ),
        const SizedBox(width: 8),
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text(
            '折抵',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _lockedField(label: '金額', value: '1', prefix: 'NT\$'),
        ),
      ],
    );
    final Widget preview = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _brand.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        _spendEnabled ? _spendPreview : '尚未啟用',
        style: TextStyle(
          color: _brand,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        if (constraints.maxWidth < 420) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[fields, const SizedBox(height: 8), preview],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: <Widget>[
            Expanded(child: fields),
            const SizedBox(width: 8),
            Padding(padding: const EdgeInsets.only(bottom: 2), child: preview),
          ],
        );
      },
    );
  }

  Widget _settingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool enabled,
    required ValueChanged<bool> onToggle,
    required Widget body,
  }) {
    final bool compact = MediaQuery.sizeOf(context).width < _desktopWidth;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(compact ? 16 : 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _brand.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 18, color: _brand),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.3,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _statusChip(enabled),
              const SizedBox(width: 6),
              _miniSwitch(value: enabled, onChanged: onToggle),
            ],
          ),
          const SizedBox(height: 14),
          body,
        ],
      ),
    );
  }

  Widget _dimmed({required bool active, required Widget child}) {
    return Opacity(
      opacity: active ? 1 : 0.45,
      child: IgnorePointer(ignoring: !active, child: child),
    );
  }

  Widget _statusChip(bool enabled) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: enabled
            ? _brand.withValues(alpha: 0.12)
            : const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        enabled ? '啟用中' : '未啟用',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: enabled ? _brand : const Color(0xFF6B7280),
        ),
      ),
    );
  }

  Widget _miniSwitch({
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return SizedBox(
      width: 48,
      height: 32,
      child: Center(
        child: SizedBox(
          width: 42,
          height: 24,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Switch(
              value: value,
              onChanged: onChanged,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              thumbColor: const WidgetStatePropertyAll<Color>(Colors.white),
              trackOutlineColor: const WidgetStatePropertyAll<Color>(
                Colors.transparent,
              ),
              trackColor: WidgetStateProperty.resolveWith((
                Set<WidgetState> states,
              ) {
                if (states.contains(WidgetState.disabled)) {
                  return const Color(0xFFD1D5DB);
                }
                if (states.contains(WidgetState.selected)) {
                  return _brand;
                }
                return const Color(0xFFD1D5DB);
              }),
            ),
          ),
        ),
      ),
    );
  }

  Widget _modeCard({
    required String label,
    required bool selected,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: selected ? _brand.withValues(alpha: 0.08) : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: 52,
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? _brand : const Color(0xFFD1D5DB),
              width: selected ? 1.4 : 1,
            ),
          ),
          child: Stack(
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: selected ? _brand : const Color(0xFF374151),
                  ),
                ),
              ),
              if (selected)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(Icons.check_circle, size: 16, color: _brand),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _optionRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    bool fadeDisabled = true,
  }) {
    final bool disabled = onChanged == null;
    return Opacity(
      opacity: disabled && fadeDisabled ? 0.45 : 1,
      child: Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: <Widget>[
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _brand.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: 16,
                color: disabled ? const Color(0xFF9CA3AF) : _brand,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _miniSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  Widget _fieldPair(Widget left, Widget right) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: left),
        const SizedBox(width: 8),
        Expanded(child: right),
      ],
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    int? maxLength,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: _labelStyle),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 14),
          decoration: _inputDecoration(),
        ),
      ],
    );
  }

  Widget _numberField({
    required TextEditingController controller,
    required String label,
    String? prefix,
    String? suffix,
    String? helper,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: _labelStyle),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 14),
          decoration: _inputDecoration(
            prefix: prefix,
            suffix: suffix,
            helper: helper,
          ),
        ),
      ],
    );
  }

  Widget _lockedField({
    required String label,
    required String value,
    String? prefix,
    String? suffix,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(label, style: _labelStyle),
        const SizedBox(height: 6),
        Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFF9FAFB),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFD1D5DB)),
          ),
          child: Row(
            children: <Widget>[
              if (prefix != null)
                Text(
                  prefix,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
              Expanded(
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF374151),
                  ),
                ),
              ),
              if (suffix != null)
                Text(
                  suffix,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  TextStyle get _labelStyle => const TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w700,
    color: Color(0xFF374151),
  );

  InputDecoration _inputDecoration({
    String? prefix,
    String? suffix,
    String? helper,
  }) {
    final OutlineInputBorder border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: Color(0xFFD1D5DB)),
    );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      prefixText: prefix,
      suffixText: suffix,
      helperText: helper,
      helperMaxLines: 2,
      counterText: '',
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: _brand),
      ),
    );
  }

  Widget _hintBanner(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _brand.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 16, color: _brand),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                height: 1.35,
                color: Color(0xFF1E3A5F),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBanner(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          height: 1.35,
          color: Color(0xFF374151),
        ),
      ),
    );
  }

  Widget _outlineButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: _brand,
        backgroundColor: Colors.white,
        side: BorderSide(color: _brand),
        minimumSize: const Size(0, 38),
        padding: const EdgeInsets.symmetric(horizontal: 12),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _saveButton({required double height}) {
    return FilledButton.icon(
      onPressed: _saving ? null : _save,
      icon: _saving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_outlined, size: 18),
      label: Text(_saving ? '儲存中...' : '儲存設定'),
      style: FilledButton.styleFrom(
        backgroundColor: _brand,
        foregroundColor: Colors.white,
        minimumSize: Size(0, height),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _mobileSaveBar() {
    return Material(
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          8,
          16,
          12 + MediaQuery.viewPaddingOf(context).bottom,
        ),
        child: Align(
          alignment: Alignment.center,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxWidth),
            child: SizedBox(
              width: double.infinity,
              child: _saveButton(height: 48),
            ),
          ),
        ),
      ),
    );
  }
}
