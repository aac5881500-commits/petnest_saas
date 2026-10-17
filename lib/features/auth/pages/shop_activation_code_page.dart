// 檔案名稱：lib/features/auth/pages/shop_activation_code_page.dart
// 功能說明：創店前驗證激活碼。驗證成功不建立店家，也不消耗激活碼。

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/services/shop_commercial_service.dart';
import 'package:petnest_saas/features/auth/pages/shop_opening_welcome_page.dart';
import 'package:petnest_saas/features/platform/pages/create_shop_page.dart';

typedef ShopActivationValidator =
    Future<ShopActivationCheck> Function(String code);

class ShopActivationCodePage extends StatefulWidget {
  const ShopActivationCodePage({super.key, this.validate});

  final ShopActivationValidator? validate;

  static Future<bool> open(BuildContext context) async {
    final ShopCreateExit? result = await Navigator.of(context)
        .push<ShopCreateExit>(
          MaterialPageRoute<ShopCreateExit>(
            builder: (_) => const ShopActivationCodePage(),
          ),
        );
    return result == ShopCreateExit.created;
  }

  @override
  State<ShopActivationCodePage> createState() => _ShopActivationCodePageState();
}

class _ShopActivationCodePageState extends State<ShopActivationCodePage> {
  final TextEditingController _codeController = TextEditingController();
  Timer? _continueTimer;
  bool _checking = false;
  bool _succeeded = false;
  String? _error;
  String? _validatedCode;
  String? _module;
  String _seenCode = '';

  @override
  void initState() {
    super.initState();
    _codeController.addListener(_handleCodeChanged);
  }

  @override
  void dispose() {
    _continueTimer?.cancel();
    _codeController.removeListener(_handleCodeChanged);
    _codeController.dispose();
    super.dispose();
  }

  void _handleCodeChanged() {
    if (!mounted) return;
    final String trimmed = _codeController.text.trim();
    final bool editedAfterValidation =
        _validatedCode != null && trimmed != _validatedCode;
    if (!editedAfterValidation && trimmed == _seenCode) return;
    _seenCode = trimmed;
    if (editedAfterValidation) {
      _continueTimer?.cancel();
      setState(() {
        _validatedCode = null;
        _succeeded = false;
        _module = null;
        _error = '激活碼已變更，請重新驗證';
      });
      return;
    }
    setState(() {});
  }

  Future<void> _submit() async {
    final String code = _codeController.text.trim();
    if (code.isEmpty || _checking) return;
    _continueTimer?.cancel();
    setState(() {
      _checking = true;
      _error = null;
      _succeeded = false;
      _validatedCode = null;
      _module = null;
    });
    try {
      final ShopActivationValidator validate =
          widget.validate ??
          ShopCommercialService.instance.validateShopActivationCode;
      final ShopActivationCheck check = await validate(code);
      if (!mounted) return;
      if (_codeController.text.trim() != code) {
        setState(() {
          _error = '激活碼已變更，請重新驗證';
        });
        return;
      }
      if (!check.valid) {
        setState(() {
          _error = check.message;
        });
        return;
      }
      setState(() {
        _succeeded = true;
        _validatedCode = code;
        _module = check.module;
      });
      _continueTimer = Timer(const Duration(milliseconds: 700), () {
        if (!mounted || _validatedCode != _codeController.text.trim()) return;
        _openWelcome(code);
      });
    } on ShopCommercialException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
      });
    } finally {
      if (mounted) {
        setState(() {
          _checking = false;
        });
      }
    }
  }

  Future<void> _openWelcome(String code) async {
    final ShopCreateExit? result = await Navigator.of(context)
        .push<ShopCreateExit>(
          MaterialPageRoute<ShopCreateExit>(
            builder: (_) => ShopOpeningWelcomePage(activationCode: code),
          ),
        );
    if (!mounted) return;
    if (result == ShopCreateExit.created) {
      Navigator.of(context).pop(ShopCreateExit.created);
      return;
    }
    if (result == ShopCreateExit.recheckActivation) {
      setState(() {
        _succeeded = false;
        _validatedCode = null;
        _module = null;
        _error = '剛才的激活碼已無法完成創店，請確認後再驗證一次。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool wide = MediaQuery.sizeOf(context).width >= 720;
    final TextTheme text = Theme.of(context).textTheme;
    final bool canSubmit = !_checking && _codeController.text.trim().isNotEmpty;
    final String moduleLabel = shopActivationModuleLabel(_module);

    return Scaffold(
      backgroundColor: _ActivationPalette.cream,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Padding(
              padding: EdgeInsets.fromLTRB(wide ? 20 : 4, 2, wide ? 28 : 12, 0),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Row(
                    children: <Widget>[
                      IconButton(
                        tooltip: '返回',
                        onPressed: _checking
                            ? null
                            : () => Navigator.of(context).maybePop(),
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Expanded(
                        child: Text(
                          'PetNest 開店小幫手',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: _ActivationPalette.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (BuildContext context, BoxConstraints constraints) {
                  return SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      wide ? 28 : 16,
                      8,
                      wide ? 28 : 16,
                      16,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 24,
                      ),
                      child: Align(
                        alignment: Alignment.center,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 560),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: <Widget>[
                              const _KeyBadge(),
                              const SizedBox(height: 16),
                              Text(
                                '開啟你的 PetNest 旅程',
                                textAlign: TextAlign.center,
                                style: text.headlineSmall?.copyWith(
                                  fontSize: wide ? 32 : 26,
                                  fontWeight: FontWeight.w800,
                                  height: 1.25,
                                  color: _ActivationPalette.ink,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '輸入專屬創店激活碼，我們會為你準備適合的店家設定與開店引導。',
                                textAlign: TextAlign.center,
                                style: text.bodyMedium?.copyWith(
                                  height: 1.5,
                                  color: _ActivationPalette.blueGray,
                                ),
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _codeController,
                                enabled: !_checking,
                                autocorrect: false,
                                enableSuggestions: false,
                                textInputAction: TextInputAction.done,
                                onSubmitted: (_) {
                                  if (canSubmit) _submit();
                                },
                                decoration: const InputDecoration(
                                  labelText: '創店激活碼',
                                  hintText: '請輸入平台提供的激活碼',
                                ),
                              ),
                              if (_error != null) ...<Widget>[
                                const SizedBox(height: 10),
                                Text(
                                  _error!,
                                  style: text.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.error,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                              if (_succeeded) ...<Widget>[
                                const SizedBox(height: 12),
                                _SuccessNote(moduleLabel: moduleLabel),
                              ],
                              const SizedBox(height: 16),
                              FilledButton(
                                onPressed: canSubmit ? _submit : null,
                                style: FilledButton.styleFrom(
                                  minimumSize: const Size.fromHeight(48),
                                ),
                                child: _checking
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.4,
                                        ),
                                      )
                                    : const Text('驗證並繼續 →'),
                              ),
                              const SizedBox(height: 22),
                              const _ContactReserve(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivationPalette {
  static const Color cream = Color(0xFFFFF8F3);
  static const Color ink = Color(0xFF172238);
  static const Color blueGray = Color(0xFF5C6B7A);
  static const Color sage = Color(0xFF7E9A78);
  static const Color sageSoft = Color(0xFFE7F0E4);
  static const Color line = Color(0xFFE6DFD6);
}

class _KeyBadge extends StatelessWidget {
  const _KeyBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: const BoxDecoration(
          color: _ActivationPalette.sageSoft,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.vpn_key_outlined,
          color: _ActivationPalette.sage,
          size: 30,
        ),
      ),
    );
  }
}

class _SuccessNote extends StatelessWidget {
  const _SuccessNote({required this.moduleLabel});

  final String moduleLabel;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _ActivationPalette.sageSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Column(
          children: <Widget>[
            Text(
              '激活碼驗證成功！',
              textAlign: TextAlign.center,
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: _ActivationPalette.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '已取得創店資格，準備開始建立你的專屬旅社。',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(
                height: 1.4,
                color: _ActivationPalette.blueGray,
              ),
            ),
            if (moduleLabel.isNotEmpty) ...<Widget>[
              const SizedBox(height: 4),
              Text(
                '開通類型：$moduleLabel',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: _ActivationPalette.ink,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ContactReserve extends StatelessWidget {
  const _ContactReserve();

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ActivationPalette.line),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
              '還沒有激活碼嗎？',
              style: text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: _ActivationPalette.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '歡迎聯絡 PetNest 團隊，了解開通方式與適合你的方案。',
              style: text.bodySmall?.copyWith(
                height: 1.45,
                color: _ActivationPalette.blueGray,
              ),
            ),
            const SizedBox(height: 8),
            const OutlinedButton(
              onPressed: null,
              child: Text('聯絡官方 LINE（即將開放）'),
            ),
          ],
        ),
      ),
    );
  }
}
