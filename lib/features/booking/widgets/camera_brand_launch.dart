// 檔案名稱：lib/features/booking/widgets/camera_brand_launch.dart
// 功能說明：顧客與店主共用的外部攝影機教學、下載與開啟入口。

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:petnest_saas/core/models/camera_brand.dart';

class CameraRequestFailureBanner extends StatelessWidget {
  const CameraRequestFailureBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        message,
        key: const Key('camera-request-failure'),
        style: const TextStyle(color: Color(0xFFB91C1C), height: 1.35),
      ),
    );
  }
}

class CameraBrandActions extends StatelessWidget {
  const CameraBrandActions({super.key, required this.providerId});

  final String providerId;

  @override
  Widget build(BuildContext context) {
    final CameraBrand? brand = cameraBrandById(providerId);
    if (brand == null) {
      return const Text(
        '此品牌尚未開放，不能使用小米／米家流程代替。',
        style: TextStyle(fontSize: 13, height: 1.4, color: Color(0xFF9F1239)),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: <Widget>[
        OutlinedButton(
          onPressed: () => showCameraBrandGuide(context, brand),
          child: const Text('查看設定／分享教學'),
        ),
        OutlinedButton(
          onPressed: () => openCameraBrandDownload(context, brand),
          child: const Text('下載 App'),
        ),
        if (brand.launchSupported)
          FilledButton(
            onPressed: () => openCameraBrandApp(context, brand),
            child: const Text('開啟 App'),
          ),
      ],
    );
  }
}

Future<void> showCameraBrandGuide(
  BuildContext context,
  CameraBrand brand,
) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text('${brand.appName} 設定與分享'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final String step in brand.guide)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(step, style: const TextStyle(height: 1.4)),
                ),
            ],
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('關閉'),
          ),
        ],
      );
    },
  );
}

Future<void> openCameraBrandDownload(
  BuildContext context,
  CameraBrand brand,
) async {
  final bool android =
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  final bool ios = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  final String storeUrl = android
      ? brand.androidStoreUrl
      : (ios ? brand.iosStoreUrl : '');
  if (storeUrl.isEmpty) {
    await _showStoreFallback(
      context,
      brand,
      '此平台沒有已確認的官方下載連結。請到應用程式商店搜尋「${brand.searchName}」。這不會開啟攝影機。',
    );
    return;
  }
  final bool? go = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text('前往下載${brand.appName}'),
        content: Text('將前往應用程式商店下載 ${brand.appName}。這不會開啟攝影機。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('前往商店'),
          ),
        ],
      );
    },
  );
  if (go != true || !context.mounted) {
    return;
  }
  await _launchExternal(
    context,
    storeUrl,
    '無法開啟應用程式商店，請搜尋「${brand.searchName}」。這不會開啟攝影機。',
    brand,
  );
}

Future<void> openCameraBrandApp(BuildContext context, CameraBrand brand) async {
  if (!brand.launchSupported) {
    await _showStoreFallback(
      context,
      brand,
      '目前沒有已確認的 ${brand.appName} 開啟方式。請先下載或自行開啟 App。',
    );
    return;
  }
  final bool? leave = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text('離開 PetNest'),
        content: Text('即將離開 PetNest 並嘗試開啟 ${brand.appName}。'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('繼續'),
          ),
        ],
      );
    },
  );
  if (leave != true || !context.mounted) {
    return;
  }
  await _showStoreFallback(
    context,
    brand,
    '無法確認 ${brand.appName} 已開啟。請改為下載或搜尋「${brand.searchName}」。',
  );
}

Future<void> _launchExternal(
  BuildContext context,
  String url,
  String failure,
  CameraBrand brand,
) async {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null) {
    await _showStoreFallback(context, brand, failure);
    return;
  }
  try {
    final bool opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!opened && context.mounted) {
      await _showStoreFallback(context, brand, failure);
    }
  } catch (_) {
    if (context.mounted) {
      await _showStoreFallback(context, brand, failure);
    }
  }
}

Future<void> _showStoreFallback(
  BuildContext context,
  CameraBrand brand,
  String message,
) async {
  await showDialog<void>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(brand.appName),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: brand.searchName));
              if (dialogContext.mounted) {
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('複製搜尋名稱'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('知道了'),
          ),
        ],
      );
    },
  );
}

bool cameraGateResultIsCurrent({
  required int requestTicket,
  required int currentTicket,
  required String requestBookingId,
  required String currentBookingId,
}) {
  return requestTicket == currentTicket && requestBookingId == currentBookingId;
}
