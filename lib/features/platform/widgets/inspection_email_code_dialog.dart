import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InspectionEmailCodeDialog extends StatefulWidget {
  const InspectionEmailCodeDialog({
    super.key,
    required this.initialDelivery,
    required this.onResend,
    required this.onVerify,
  });
  final Map<String, dynamic> initialDelivery;
  final Future<Map<String, dynamic>> Function() onResend;
  final Future<String> Function(String challengeId, String code) onVerify;
  @override
  State<InspectionEmailCodeDialog> createState() => _EmailCodeState();
}

class _EmailCodeState extends State<InspectionEmailCodeDialog> {
  final _code = TextEditingController();
  late Map<String, dynamic> _delivery;
  late DateTime _retryAt;
  Timer? _timer;
  bool _busy = false;
  String? _error;
  int get _remaining =>
      (_retryAt.difference(DateTime.now()).inMilliseconds / 1000).ceil().clamp(
        0,
        3600,
      );
  @override
  void initState() {
    super.initState();
    _delivery = widget.initialDelivery;
    _resetCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  void _resetCountdown() {
    _retryAt = DateTime.now().add(
      Duration(
        seconds: (_delivery['retryAfterSeconds'] as num?)?.toInt() ?? 60,
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_busy || _code.text.length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final token = await widget.onVerify(
        _delivery['challengeId'] as String,
        _code.text,
      );
      if (mounted) Navigator.pop(context, token);
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _message(Object e) =>
      e.toString().replaceFirst(RegExp(r'^Exception: '), '');
  Future<void> _resend() async {
    if (_busy || _remaining > 0) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final delivery = await widget.onResend();
      if (mounted) {
        setState(() {
          _delivery = delivery;
          _code.clear();
          _resetCountdown();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      title: const Text('輸入查核驗證碼'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('驗證碼已寄至 ${_delivery['maskedEmail']}。'),
            const SizedBox(height: 8),
            const Text(
              '請輸入最新信件中的六位數驗證碼，5 分鐘內有效。無須再次登入。',
              style: TextStyle(fontSize: 13, height: 1.6),
            ),
            const SizedBox(height: 20),
            AutofillGroup(
              child: TextField(
                controller: _code,
                autofocus: true,
                enabled: !_busy,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.oneTimeCode],
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(6),
                ],
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _verify(),
                decoration: const InputDecoration(
                  labelText: '六位數驗證碼',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy || _remaining > 0 ? null : _resend,
              child: Text(_remaining > 0 ? '$_remaining 秒後可重新寄送' : '重新寄送驗證碼'),
            ),
            if (_busy) const LinearProgressIndicator(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _busy || _code.text.length != 6 ? null : _verify,
          child: const Text('驗證並解鎖'),
        ),
      ],
    ),
  );
}
