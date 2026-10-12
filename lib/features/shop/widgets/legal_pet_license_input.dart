// 檔案名稱：lib/features/shop/widgets/legal_pet_license_input.dart
// 功能說明：特寵字號輸入。前綴與「號」只顯示，不寫進欄位值。

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/legal_pet/license_lookup.dart';

class LegalPetLicenseInput extends StatefulWidget {
  const LegalPetLicenseInput({
    super.key,
    required this.controller,
    required this.locked,
    required this.firstSetup,
    this.onChanged,
  });

  final TextEditingController controller;
  final bool locked;
  final bool firstSetup;
  final VoidCallback? onChanged;

  @override
  State<LegalPetLicenseInput> createState() => _LegalPetLicenseInputState();
}

class _LegalPetLicenseInputState extends State<LegalPetLicenseInput> {
  bool _applying = false;
  String _lastText = '';

  @override
  void initState() {
    super.initState();
    _lastText = widget.controller.text;
    widget.controller.addListener(_onEdited);
  }

  @override
  void didUpdateWidget(LegalPetLicenseInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onEdited);
      _lastText = widget.controller.text;
      widget.controller.addListener(_onEdited);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onEdited);
    super.dispose();
  }

  void _onEdited() {
    if (_applying) return;
    var raw = widget.controller.text;
    final parsed = parseLicenseLookup(raw);
    if (parsed.kind == 'standard' && parsed.core != raw) {
      _applying = true;
      widget.controller.value = TextEditingValue(
        text: parsed.core,
        selection: TextSelection.collapsed(offset: parsed.core.length),
      );
      _applying = false;
      raw = parsed.core;
    }
    if (raw == _lastText) return;
    _lastText = raw;
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      controller: widget.controller,
      readOnly: widget.locked,
      textCapitalization: TextCapitalization.characters,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: '字號',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        filled: true,
        fillColor: widget.locked ? const Color(0xFFF4F1EC) : Colors.white,
        suffixIcon: widget.locked
            ? const Icon(Icons.lock_outline, size: 18)
            : (widget.firstSetup
                  ? const Icon(Icons.edit_outlined, size: 18)
                  : null),
        helperText: widget.locked
            ? '需申請修改'
            : (widget.firstSetup ? '首次設定後將鎖定' : null),
        helperMaxLines: 2,
      ),
    );
    const hint = Text(
      '請輸入完整英文字母、數字與尾碼，不需輸入前方中文或末尾『號』。',
      style: TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF8D6E63)),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth < 360;
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('特寵業字第'),
              const SizedBox(height: 6),
              field,
              const SizedBox(height: 6),
              const Text('號'),
              const SizedBox(height: 6),
              hint,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Text('特寵業字第'),
                const SizedBox(width: 8),
                Expanded(child: field),
                const SizedBox(width: 8),
                const Text('號'),
              ],
            ),
            const SizedBox(height: 6),
            hint,
          ],
        );
      },
    );
  }
}
