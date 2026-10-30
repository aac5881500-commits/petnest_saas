import 'package:flutter/foundation.dart';

bool get shopMapsConfigured =>
    const bool.fromEnvironment('GOOGLE_MAPS_NATIVE_READY') &&
    const String.fromEnvironment('GOOGLE_MAPS_MAP_ID').isNotEmpty &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);
Future<void> ensureShopMapsLoaded() async {}
