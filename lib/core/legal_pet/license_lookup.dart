// 檔案名稱：lib/core/legal_pet/license_lookup.dart
// 功能說明：特寵字號查核鍵。只辨識明確前綴與末尾「號」，不改綁定用的完整字號。

const lookupKeyVersion = 1;
const standardLicensePrefix = '特寵業字第';
const breedingLicensePrefix = '特寵業繁字第';
final RegExp _licenseCore = RegExp(r'^[A-Z]{1,2}[0-9]{7}(?:-[0-9]{2})?$');
final RegExp _licenseSpace = RegExp(r'[\t\n\r\f \u00A0\u3000]+');
final RegExp _cjk = RegExp(r'[\u3400-\u9FFF]');

class LicenseLookupParse {
  const LicenseLookupParse({
    required this.ok,
    required this.kind,
    required this.key,
    required this.core,
    required this.reason,
  });

  final bool ok;
  final String kind;
  final String key;
  final String core;
  final String reason;
}

String _foldLicenseText(String value) {
  final buffer = StringBuffer();
  for (final rune in value.trim().runes) {
    if (rune >= 0xFF01 && rune <= 0xFF5E) {
      buffer.writeCharCode(rune - 0xFEE0);
    } else {
      buffer.writeCharCode(rune);
    }
  }
  return buffer.toString().replaceAll(_licenseSpace, '').toUpperCase();
}

LicenseLookupParse _result({
  required bool ok,
  required String kind,
  required String key,
  required String core,
  required String reason,
}) {
  return LicenseLookupParse(
    ok: ok,
    kind: kind,
    key: key,
    core: core,
    reason: reason,
  );
}

/// 與後端 parseLicenseLookup 相同規則。繁字不會併成一般字號。
LicenseLookupParse parseLicenseLookup(String value) {
  final folded = _foldLicenseText(value);
  if (folded.isEmpty) {
    return _result(ok: false, kind: 'invalid', key: '', core: '', reason: 'empty');
  }
  var body = folded;
  var prefixed = '';
  if (body.startsWith(breedingLicensePrefix)) {
    body = body.substring(breedingLicensePrefix.length);
    prefixed = 'breeding';
  } else if (body.startsWith(standardLicensePrefix)) {
    body = body.substring(standardLicensePrefix.length);
    prefixed = 'standard';
  }
  if (body.endsWith('號')) {
    body = body.substring(0, body.length - 1);
  }
  if (prefixed.isEmpty && _cjk.hasMatch(body)) {
    return _result(
      ok: false,
      kind: 'unrecognized',
      key: '',
      core: '',
      reason: 'unrecognized_prefix',
    );
  }
  final extraCjk = _cjk.hasMatch(body);
  if (body.contains('號') || extraCjk || !_licenseCore.hasMatch(body)) {
    return _result(
      ok: false,
      kind: prefixed == 'breeding' ? 'breeding' : 'invalid',
      key: '',
      core: '',
      reason: 'invalid_format',
    );
  }
  if (prefixed == 'breeding') {
    return _result(
      ok: true,
      kind: 'breeding',
      key: '繁字:$body',
      core: body,
      reason: '',
    );
  }
  return _result(ok: true, kind: 'standard', key: body, core: body, reason: '');
}

/// 輸入框顯示核心字號。無法辨識時保留原文字，不猜成一般字號。
String licenseInputText(String stored) {
  final parsed = parseLicenseLookup(stored);
  if (parsed.kind == 'standard' && parsed.core.isNotEmpty) {
    return parsed.core;
  }
  return stored.trim();
}

/// 查核鍵沒變就沿用已儲存字號，避免改寫認證綁定。
String licenseValueToStore({
  required String persisted,
  required String current,
}) {
  final shown = parseLicenseLookup(current);
  final original = parseLicenseLookup(persisted);
  if (shown.kind == 'standard' &&
      original.kind == 'standard' &&
      shown.key == original.key) {
    return persisted;
  }
  if (shown.kind == 'standard') {
    return shown.core;
  }
  return current.trim();
}
