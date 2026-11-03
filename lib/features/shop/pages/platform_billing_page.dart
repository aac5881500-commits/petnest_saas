import 'dart:math';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:petnest_saas/core/services/platform_billing_service.dart';
import 'package:petnest_saas/core/services/inspection_owner_context.dart';

class PlatformBillingPage extends StatefulWidget {
  const PlatformBillingPage({super.key, required this.shopId, this.store});
  final String shopId;
  final PlatformBillingStore? store;
  @override
  State<PlatformBillingPage> createState() => _PlatformBillingPageState();
}

class _PlatformBillingPageState extends State<PlatformBillingPage> {
  PlatformBillingStore get _store =>
      widget.store ?? PlatformBillingService.instance;
  Map<String, dynamic>? _data;
  bool _loading = true, _busy = false, _recurring = false, _consent = false;
  String _plan = 'basic', _cycle = 'month';
  String? _error, _checkoutUrl, _requestId;
  bool get _readOnly => InspectionOwnerContext.active;
  Map<String, dynamic>? get _subscription => _data?['subscription'] is Map
      ? Map<String, dynamic>.from(_data!['subscription'] as Map)
      : null;
  bool get _locked => const [
    'pending',
    'active',
    'past_due',
    'paused',
    'cancel_pending',
  ].contains(_subscription?['state']);
  bool get _pending => _subscription?['state'] == 'pending';
  String _money(dynamic value) =>
      'NT＄${((value as num? ?? 0) / 100).toStringAsFixed(0)}';
  String _planName(dynamic plan) => plan == 'pro' ? '旗艦版' : '專業版';
  String _cycleName(dynamic cycle) => cycle == 'year' ? '年' : '月';
  String _state(dynamic state) => switch (state) {
    'pending' => '等待付款',
    'active' => '自動續訂中',
    'past_due' => '扣款未完成',
    'cancel_pending' => '正在確認取消，尚未確認停止扣款',
    'cancelled' => '已停止自動續訂',
    'paused' => '綠界已暫停扣款',
    'completed' => '本次付款／約定期數已完成',
    'failed' => '付款未完成',
    _ => '尚未啟用線上付款',
  };
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool reconcile = false}) async {
    setState(() {
      _loading = _data == null;
      _busy = true;
      _error = null;
    });
    try {
      final data = reconcile && !_readOnly
          ? await _store.refresh(widget.shopId)
          : await _store.load(widget.shopId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _consent = false;
        _checkoutUrl = null;
        _requestId = null;
        final sub = _subscription;
        if (_locked && sub != null) {
          _plan = sub['plan'] as String;
          _cycle = sub['cycle'] as String;
          _recurring = sub['recurring'] == true;
        }
        if (!_pending) _checkoutUrl = null;
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PlatformBillingException
              ? error.message
              : '無法讀取平台付款狀態，請重試。',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _busy = false;
        });
      }
    }
  }

  Future<void> _prepare() async {
    if (_busy || !_consent || _readOnly) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final random = Random.secure();
    _requestId ??= List.generate(
      16,
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
    ).join();
    try {
      final result = await _store.checkout({
        'shopId': widget.shopId,
        'plan': _plan,
        'cycle': _cycle,
        'recurring': _recurring,
        'consent': true,
        'termsVersion': _data!['termsVersion'],
        'priceVersion': _pending
            ? _subscription!['priceVersion']
            : _data!['priceVersion'],
        'requestId': _requestId,
      });
      if (!mounted) return;
      setState(() {
        _checkoutUrl = result['checkoutUrl'] as String;
        _data = {..._data!, 'subscription': result['order']};
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PlatformBillingException
              ? error.message
              : '尚未開啟付款，請重試。',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openCheckout() async {
    final uri = Uri.tryParse(_checkoutUrl ?? '');
    final project = Firebase.app().options.projectId;
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host != 'asia-east1-$project.cloudfunctions.net' ||
        uri.path != '/platformSubscriptionCheckout' ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        (uri.hasPort && uri.port != 443) ||
        !RegExp(r'^PB[A-F0-9]{18}\.[a-f0-9]{48}$').hasMatch(uri.fragment)) {
      setState(() => _error = '付款網址驗證失敗，請重新建立付款連結。');
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) setState(() => _error = '無法開啟瀏覽器，請允許開啟付款頁後再試。');
  }

  Future<void> _cancel() async {
    final unsent = _pending && _subscription?['launchIssuedAtMs'] == null;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(unsent ? '取消未送出的付款？' : '停止自動續訂？'),
        content: Text(
          unsent
              ? '付款尚未送到綠界。取消後舊連結會失效，不會觸發扣款。'
              : '會向綠界終止之後的扣款，已付費期間仍可使用。這個操作不會自動退款；只有綠界確認終止後，才會顯示已停止。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('保留續訂'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(unsent ? '確認取消付款' : '確認停止續訂'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted || _readOnly) return;
    setState(() {
      _busy = true;
      _error = null;
      _checkoutUrl = null;
    });
    try {
      final data = await _store.cancel(widget.shopId);
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PlatformBillingException
              ? error.message
              : '尚未確認取消成功，請重新查詢。',
        );
      }
      try {
        final data = await _store.load(widget.shopId);
        if (mounted) setState(() => _data = data);
      } catch (_) {}
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _changed(VoidCallback change) => setState(() {
    change();
    _consent = false;
    _checkoutUrl = null;
    _requestId = null;
  });
  @override
  Widget build(BuildContext context) {
    final data = _data;
    final sub = _subscription;
    final quotes = (data?['quotes'] as List? ?? const []).whereType<Map>();
    final matching = quotes.where(
      (quote) => quote['plan'] == _plan && quote['cycle'] == _cycle,
    );
    final quote = matching.isEmpty ? <dynamic, dynamic>{} : matching.first;
    final amount = _pending ? sub!['amountMinor'] : quote['amountMinor'];
    final count = _pending
        ? sub!['executionLimit']
        : quote['recurringExecutionLimit'];
    final canPay =
        data?['enabled'] == true &&
        data?['canCheckout'] == true &&
        !_readOnly &&
        (!_locked || _pending);
    final allowedRecurring =
        !_recurring || _pending || quote['canStartRecurring'] == true;
    return Scaffold(
      appBar: AppBar(
        title: const Text('平台方案與續費'),
        actions: [
          IconButton(
            tooltip: '重新查詢付款狀態',
            onPressed: _busy
                ? null
                : () => _load(reconcile: data?['enabled'] == true),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 680),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            _error!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                      if (data == null)
                        FilledButton(
                          onPressed: _busy ? null : _load,
                          child: const Text('重新讀取'),
                        ),
                      if (data != null) ...[
                        const Text('這裡只支付店家使用 PetNest 的平台費用。'),
                        const SizedBox(height: 8),
                        const Text('信用卡在綠界頁面輸入，PetNest 不保存卡號、有效期限或安全碼。'),
                        if (_readOnly)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text('目前為唯讀查核，無法付款或取消續訂。'),
                          ),
                        if (data['environment'] != 'production')
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text('綠界測試模式：不收實款、不延長正式服務期限。'),
                          ),
                        if (data['enabled'] != true)
                          const Padding(
                            padding: EdgeInsets.only(top: 12),
                            child: Text('平台線上付款準備中，尚未開通收費。'),
                          ),
                        const SizedBox(height: 16),
                        Text(
                          '目前服務期限：${data['paidUntilDate'] == '' ? '尚未設定' : data['paidUntilDate']}',
                        ),
                        if (sub != null)
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _state(sub['state']),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium,
                                  ),
                                  Text(
                                    '${_planName(sub['plan'])}・每${_cycleName(sub['cycle'])}${_money(sub['amountMinor'])}',
                                  ),
                                  if (sub['nextBillingDate'] != null)
                                    Text('下次預計扣款：${sub['nextBillingDate']}'),
                                  if (sub['recurring'] == true)
                                    Text(
                                      '已成功 ${sub['settledCount'] ?? 0} 期／約定 ${sub['executionLimit']} 期',
                                    ),
                                  if ((sub['recurring'] == true ||
                                          (_pending &&
                                              sub['launchIssuedAtMs'] ==
                                                  null)) &&
                                      _locked &&
                                      !_readOnly &&
                                      data['canCancel'] == true)
                                    TextButton(
                                      onPressed: _busy ? null : _cancel,
                                      child: Text(
                                        _pending &&
                                                sub['launchIssuedAtMs'] == null
                                            ? '取消未送出的付款'
                                            : '停止自動續訂',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        if (!_locked || _pending) ...[
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _plan,
                            decoration: const InputDecoration(
                              labelText: '平台方案',
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'basic',
                                child: Text('專業版'),
                              ),
                              DropdownMenuItem(
                                value: 'pro',
                                child: Text('旗艦版'),
                              ),
                            ],
                            onChanged: canPay && !_pending && !_busy
                                ? (value) => _changed(() => _plan = value!)
                                : null,
                          ),
                          const SizedBox(height: 16),
                          const Text('付款方式：綠界信用卡・每月繳費'),
                          const SizedBox(height: 12),
                          Text(
                            '每次平台使用費：${_money(amount)}',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            '預計服務期間：${quote['serviceStart'] ?? ''}～${quote['serviceEnd'] ?? ''}',
                          ),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('開啟自動續訂'),
                            value: _recurring,
                            subtitle: Text(
                              _recurring
                                  ? '每${_cycleName(_cycle)}固定${_money(amount)}，共$count期，首筆立即刷卡。'
                                  : '只支付這一期，不會自動扣下一期。',
                            ),
                            onChanged: canPay && !_pending && !_busy
                                ? (value) => _changed(() => _recurring = value)
                                : null,
                          ),
                          if (!allowedRecurring)
                            Text(
                              '目前試用或已付期間尚未結束。請於${quote['recurringAvailableFrom'] ?? quote['serviceStart']}開始自動續訂，避免提前扣款。',
                            ),
                          CheckboxListTile(
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            value: _consent,
                            onChanged: canPay && !_busy && allowedRecurring
                                ? (value) =>
                                      setState(() => _consent = value == true)
                                : null,
                            title: Text(
                              _recurring
                                  ? '我確認每${_cycleName(_cycle)}${_money(amount)}、共$count期，並授權綠界自動扣款；可停止後續續訂。'
                                  : '我確認支付本期平台使用費${_money(amount)}，首筆會立即刷卡。',
                            ),
                          ),
                          FilledButton.icon(
                            onPressed:
                                canPay && _consent && !_busy && allowedRecurring
                                ? _prepare
                                : null,
                            icon: const Icon(Icons.lock_outline),
                            label: Text(
                              _busy
                                  ? '處理中…'
                                  : _pending
                                  ? '繼續原付款'
                                  : '確認方案，準備付款',
                            ),
                          ),
                          if (_checkoutUrl != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: FilledButton(
                                onPressed: _busy || _readOnly
                                    ? null
                                    : _openCheckout,
                                child: const Text('前往綠界安全付款'),
                              ),
                            ),
                          const SizedBox(height: 8),
                          const Text('請在外部瀏覽器完成付款後返回此頁，按右上角重新查詢。跳回APP不代表付款成功。'),
                        ],
                        const SizedBox(height: 24),
                        Text(
                          '最近平台收款紀錄',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        for (final receipt
                            in (data['receipts'] as List? ?? const [])
                                .whereType<Map>())
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${receipt['paymentDate']}・${_planName(receipt['plan'])}・${_money(receipt['amountMinor'])}',
                                  ),
                                  Text(
                                    receipt['status'] == 'test_confirmed'
                                        ? '測試付款成功'
                                        : receipt['status'] == 'confirmed'
                                        ? '付款成功'
                                        : receipt['status'] == 'refunded'
                                        ? '已退款'
                                        : '付款資料同步中',
                                  ),
                                  Text(
                                    '服務期間：${receipt['serviceStart'] ?? ''}～${receipt['serviceEnd'] ?? ''}',
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if ((data['receipts'] as List? ?? const []).isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('尚無平台付款紀錄。'),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}
