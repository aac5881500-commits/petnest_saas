// 檔案名稱：lib/features/shop/widgets/shop_deposit_setting_panel.dart
// 功能說明：收款設定表單版面（訂金規則視覺化），不改計價與儲存欄位。

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ShopDepositSettingPanel extends StatelessWidget {
  const ShopDepositSettingPanel({
    super.key,
    required this.depositEnabled,
    required this.depositType,
    required this.depositValue,
    required this.depositBase,
    required this.depositExpireHours,
    required this.depositValueController,
    required this.dirty,
    required this.saving,
    required this.onToggleEnabled,
    required this.onExpireHours,
    required this.onDepositBase,
    required this.onDepositType,
    required this.onDepositValueChanged,
    required this.onSave,
  });

  static const double maxContentWidth = 1160;
  static const double twoColumnMin = 960;
  static const List<int> expireHourOptions = <int>[0, 12, 24, 72];

  final bool depositEnabled;
  final String depositType;
  final int depositValue;
  final String depositBase;
  final int depositExpireHours;
  final TextEditingController depositValueController;
  final bool dirty;
  final bool saving;
  final ValueChanged<bool> onToggleEnabled;
  final ValueChanged<int> onExpireHours;
  final ValueChanged<String> onDepositBase;
  final ValueChanged<String> onDepositType;
  final ValueChanged<String> onDepositValueChanged;
  final VoidCallback onSave;

  static String expireLabel(int hours) {
    return switch (hours) {
      0 => '1 分鐘內',
      12 => '12 小時內',
      24 => '1 天內',
      72 => '3 天內',
      _ => '$hours 小時內',
    };
  }

  static String ntd(int value) {
    final String raw = value.abs().toString();
    final StringBuffer out = StringBuffer();
    for (int i = 0; i < raw.length; i++) {
      final int fromEnd = raw.length - i;
      out.write(raw[i]);
      if (fromEnd > 1 && fromEnd % 3 == 1) {
        out.write(',');
      }
    }
    return 'NT\$${value < 0 ? '-' : ''}$out';
  }

  bool get _percent => depositType == 'percent';

  bool get _totalBase => depositBase == 'total';

  String get summaryLine {
    if (!depositEnabled) {
      return '未啟用訂金｜客戶將依訂單設定支付全額或免訂金';
    }
    final String amount = _percent
        ? '${_totalBase ? '總金額' : '房價'} $depositValue%'
        : '每筆 ${ntd(depositValue)}';
    return '已啟用訂金｜$amount｜${expireLabel(depositExpireHours)}';
  }

  int get previewOrderAmount => _totalBase ? 3600 : 3000;

  int get previewDeposit {
    if (!depositEnabled) {
      return 0;
    }
    if (_percent) {
      return (previewOrderAmount * depositValue / 100).round();
    }
    return depositValue;
  }

  int get previewBalance {
    final int remain = previewOrderAmount - previewDeposit;
    return remain < 0 ? 0 : remain;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double width = constraints.maxWidth;
        final bool bounded = constraints.hasBoundedHeight;
        final bool twoColumn = width >= twoColumnMin && bounded;
        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerLowest,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: maxContentWidth),
              child: twoColumn
                  ? _wideLayout(context)
                  : bounded
                  ? _narrowLayout(context)
                  : _unboundedLayout(context),
            ),
          ),
        );
      },
    );
  }

  Widget _wideLayout(BuildContext context) {
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: _SummaryCard(
            enabled: depositEnabled,
            summary: summaryLine,
            onToggle: onToggleEnabled,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  flex: 65,
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 12, right: 12),
                    children: _settingCards(enabled: depositEnabled),
                  ),
                ),
                Expanded(
                  flex: 35,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 12),
                    child: _PreviewCard(
                      enabled: depositEnabled,
                      totalBase: _totalBase,
                      depositAmount: previewDeposit,
                      balanceAmount: previewBalance,
                      expireText: expireLabel(depositExpireHours),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: Align(
            alignment: Alignment.centerRight,
            child: _SaveButton(
              enabled: dirty && !saving,
              saving: saving,
              onPressed: onSave,
            ),
          ),
        ),
      ],
    );
  }

  Widget _narrowLayout(BuildContext context) {
    final List<Widget> body = <Widget>[
      _SummaryCard(
        enabled: depositEnabled,
        summary: summaryLine,
        onToggle: onToggleEnabled,
      ),
      const SizedBox(height: 14),
      ..._settingCards(enabled: depositEnabled),
      const SizedBox(height: 8),
      _PreviewCard(
        enabled: depositEnabled,
        totalBase: _totalBase,
        depositAmount: previewDeposit,
        balanceAmount: previewBalance,
        expireText: expireLabel(depositExpireHours),
      ),
    ];
    return Column(
      children: <Widget>[
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: body,
          ),
        ),
        Material(
          elevation: 8,
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
              child: _SaveButton(
                enabled: dirty && !saving,
                saving: saving,
                onPressed: onSave,
                expanded: true,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _unboundedLayout(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
      children: <Widget>[
        _SummaryCard(
          enabled: depositEnabled,
          summary: summaryLine,
          onToggle: onToggleEnabled,
        ),
        const SizedBox(height: 14),
        ..._settingCards(enabled: depositEnabled),
        const SizedBox(height: 8),
        _PreviewCard(
          enabled: depositEnabled,
          totalBase: _totalBase,
          depositAmount: previewDeposit,
          balanceAmount: previewBalance,
          expireText: expireLabel(depositExpireHours),
        ),
        const SizedBox(height: 16),
        _SaveButton(
          enabled: dirty && !saving,
          saving: saving,
          onPressed: onSave,
          expanded: true,
        ),
      ],
    );
  }

  List<Widget> _settingCards({required bool enabled}) {
    return <Widget>[
      _SectionCard(
        title: '付款期限',
        subtitle: '客戶需在此期限內完成訂金或指定付款。',
        enabled: enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _ChoiceWrap(
              children: <Widget>[
                _ChoiceTile(
                  title: '1 分鐘（測試用）',
                  subtitle: '僅測試',
                  selected: depositExpireHours == 0,
                  enabled: enabled,
                  testOnly: true,
                  onTap: () => onExpireHours(0),
                ),
                _ChoiceTile(
                  title: '12 小時',
                  subtitle: '適合當日確認',
                  selected: depositExpireHours == 12,
                  enabled: enabled,
                  onTap: () => onExpireHours(12),
                ),
                _ChoiceTile(
                  title: '1 天',
                  subtitle: '24 小時內付款',
                  selected: depositExpireHours == 24,
                  enabled: enabled,
                  onTap: () => onExpireHours(24),
                ),
                _ChoiceTile(
                  title: '3 天',
                  subtitle: '72 小時內付款',
                  selected: depositExpireHours == 72,
                  enabled: enabled,
                  onTap: () => onExpireHours(72),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '逾期未付款時，系統會依既有規則取消或釋放訂單。',
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
            ),
          ],
        ),
      ),
      _SectionCard(
        title: '訂金計算基礎',
        subtitle: '百分比訂金會依此基礎計算；固定金額不受影響。',
        enabled: enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _ChoiceWrap(
              children: <Widget>[
                _ChoiceTile(
                  title: '只算房價',
                  subtitle: '只依住宿／安親基本費用計算',
                  selected: depositBase == 'room',
                  enabled: enabled,
                  onTap: () => onDepositBase('room'),
                ),
                _ChoiceTile(
                  title: '算總金額',
                  subtitle: '包含已選加購服務',
                  selected: depositBase == 'total',
                  enabled: enabled,
                  onTap: () => onDepositBase('total'),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _InfoHint(text: '訂金會依此計算基礎產生；請確認是否要將加購服務納入訂金。'),
          ],
        ),
      ),
      _SectionCard(
        title: '訂金金額',
        subtitle: '選擇固定金額或依訂單比例收取。',
        enabled: enabled,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _ChoiceWrap(
              children: <Widget>[
                _ChoiceTile(
                  title: '固定金額',
                  subtitle: '每筆訂單收固定金額',
                  selected: depositType == 'fixed',
                  enabled: enabled,
                  onTap: () => onDepositType('fixed'),
                ),
                _ChoiceTile(
                  title: '百分比',
                  subtitle: '依訂單金額比例收取',
                  selected: depositType == 'percent',
                  enabled: enabled,
                  onTap: () => onDepositType('percent'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _AmountField(
              percent: _percent,
              enabled: enabled,
              controller: depositValueController,
              onChanged: onDepositValueChanged,
              hint: _percent
                  ? '目前設定：訂單金額的 $depositValue%'
                  : '目前設定：每筆訂單 ${ntd(depositValue)}',
            ),
            if (_percent) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                '百分比依照上方選擇的計算基礎計算。',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              ),
            ],
          ],
        ),
      ),
    ];
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.enabled,
    required this.summary,
    required this.onToggle,
  });

  final bool enabled;
  final String summary;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    '收款設定',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '設定訂金規則與客戶付款期限',
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    summary,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: enabled ? colors.primary : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              children: <Widget>[
                const Text('啟用訂金', style: TextStyle(fontSize: 12)),
                Switch(value: enabled, onChanged: onToggle),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.child,
  });

  final String title;
  final String subtitle;
  final bool enabled;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 14),
            IgnorePointer(ignoring: !enabled, child: child),
          ],
        ),
      ),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  const _ChoiceWrap({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int count = children.length;
        const double gap = 10;
        final int columns = constraints.maxWidth < 560 || count <= 2 ? 2 : 4;
        final double tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: <Widget>[
            for (final Widget child in children)
              SizedBox(width: tileWidth, child: child),
          ],
        );
      },
    );
  }
}

class _ChoiceTile extends StatelessWidget {
  const _ChoiceTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.enabled,
    required this.onTap,
    this.testOnly = false,
  });

  final String title;
  final String subtitle;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;
  final bool testOnly;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    final Color border = selected ? colors.primary : Colors.grey.shade300;
    final Color fill = selected
        ? colors.primary.withValues(alpha: 0.08)
        : Colors.white;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: title,
      child: Material(
        color: fill,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: border, width: selected ? 1.8 : 1),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  selected ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: selected ? colors.primary : Colors.grey.shade400,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        title,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: testOnly
                              ? const Color(0xFFB26A00)
                              : Colors.grey.shade600,
                          fontWeight: testOnly
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AmountField extends StatelessWidget {
  const _AmountField({
    required this.percent,
    required this.enabled,
    required this.controller,
    required this.onChanged,
    required this.hint,
  });

  final bool percent;
  final bool enabled;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320, minWidth: 240),
          child: TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: TextInputType.number,
            inputFormatters: <TextInputFormatter>[
              FilteringTextInputFormatter.digitsOnly,
            ],
            decoration: InputDecoration(
              prefixText: percent ? null : 'NT\$ ',
              suffixText: percent ? '%' : null,
              labelText: percent ? '訂金百分比' : '訂金金額',
              filled: true,
              fillColor: Colors.grey.shade50,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onChanged: onChanged,
          ),
        ),
        Text(
          hint,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: Colors.grey.shade800,
          ),
        ),
      ],
    );
  }
}

class _InfoHint extends StatelessWidget {
  const _InfoHint({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: colors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(Icons.info_outline, size: 18, color: colors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.enabled,
    required this.totalBase,
    required this.depositAmount,
    required this.balanceAmount,
    required this.expireText,
  });

  final bool enabled;
  final bool totalBase;
  final int depositAmount;
  final int balanceAmount;
  final String expireText;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.7,
      child: Card(
        elevation: 0,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const Text(
                '客戶付款預覽',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 4),
              Text(
                '此為設定示意，實際金額依訂單內容計算',
                style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 14),
              if (!enabled)
                Text(
                  '目前未啟用訂金，客戶將依訂單付款設定進行付款。',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade800,
                  ),
                )
              else ...<Widget>[
                _kv('訂單預估金額', ShopDepositSettingPanel.ntd(3000)),
                if (totalBase)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      '示例含加購後 ${ShopDepositSettingPanel.ntd(3600)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                _kv(
                  '本次需支付訂金',
                  ShopDepositSettingPanel.ntd(depositAmount),
                  emphasize: true,
                  color: colors.primary,
                ),
                _kv('入住／服務完成後支付尾款', ShopDepositSettingPanel.ntd(balanceAmount)),
                _kv('付款期限', expireText),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _kv(
    String label,
    String value, {
    bool emphasize = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: TextStyle(color: Colors.grey.shade700)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: color,
              fontSize: emphasize ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.enabled,
    required this.saving,
    required this.onPressed,
    this.expanded = false,
  });

  final bool enabled;
  final bool saving;
  final VoidCallback onPressed;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final Widget button = FilledButton.icon(
      key: const ValueKey<String>('shop-deposit-save'),
      onPressed: enabled ? onPressed : null,
      icon: saving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.save_outlined),
      label: Text(saving ? '儲存中…' : '儲存設定'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(160, 48),
        disabledBackgroundColor: Theme.of(
          context,
        ).colorScheme.primary.withValues(alpha: 0.28),
        disabledForegroundColor: Colors.white,
      ),
    );
    if (expanded) {
      return SizedBox(width: double.infinity, height: 48, child: button);
    }
    return button;
  }
}
