// Flutter Web transaction 會把 callback 裡的 Dart 例外放進 JS Error.error。

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

Object? unboxDailyCareJsError(Object error) {
  try {
    // ignore: invalid_runtime_check_with_js_interop_types
    if (error is! JSObject) {
      return null;
    }
    final JSAny? boxed = error['error'];
    if (boxed != null && boxed.isA<JSBoxedDartObject>()) {
      final Object dartError = (boxed as JSBoxedDartObject).toDart;
      if (identical(dartError, error)) {
        return null;
      }
      return dartError;
    }
  } catch (_) {}
  return null;
}

String readDailyCareJsProperty(Object error, String name) {
  try {
    // ignore: invalid_runtime_check_with_js_interop_types
    if (error is! JSObject) {
      return '';
    }
    final JSAny? value = error[name];
    if (value == null) {
      return '';
    }
    if (value.isA<JSString>()) {
      return (value as JSString).toDart.trim();
    }
  } catch (_) {}
  return '';
}
