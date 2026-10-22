// 檔案：lib/features/shop/widgets/modern_home/environment_home_image_resolver.dart
// 功能：環境展示縮圖與前台共用圖片來源；圖庫僅依有效 ID 改變時讀取。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_environment_section_setting.dart';
import 'package:petnest_saas/core/models/platform_media_asset.dart';
import 'package:petnest_saas/core/services/platform_media_library_service.dart';

class EnvironmentHomeImage {
  const EnvironmentHomeImage({required this.url, this.assetName = ''});
  final String url, assetName;
}

class EnvironmentHomeImageResolver extends StatefulWidget {
  const EnvironmentHomeImageResolver({
    super.key,
    required this.setting,
    required this.environmentIntro,
    required this.builder,
  });
  final HomeEnvironmentSectionSetting setting;
  final Map<String, dynamic> environmentIntro;
  final Widget Function(BuildContext, EnvironmentHomeImage) builder;
  @override
  State<EnvironmentHomeImageResolver> createState() =>
      _EnvironmentHomeImageResolverState();
}

class _EnvironmentHomeImageResolverState
    extends State<EnvironmentHomeImageResolver> {
  String _id = '';
  int _token = 0;
  PlatformMediaAsset? _asset;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant EnvironmentHomeImageResolver oldWidget) {
    super.didUpdateWidget(oldWidget);
    _load();
  }

  void _load() {
    final id = widget.setting.usesPlatformImage
        ? widget.setting.imageAssetId.trim()
        : '';
    if (id == _id) return;
    _id = id;
    _asset = null;
    final token = ++_token;
    if (id.isEmpty) return;
    _resolve(id, token);
  }

  Future<void> _resolve(String id, int token) async {
    PlatformMediaAsset? asset;
    try {
      asset = await PlatformMediaLibraryService.instance.getEnabledAssetById(
        id,
      );
    } catch (_) {
      asset = null;
    }
    if (!mounted || token != _token) return;
    if (asset != null &&
        (!asset.enabled ||
            asset.category != PlatformMediaCategories.dailyCareCard)) {
      asset = null;
    }
    setState(() => _asset = asset);
  }

  @override
  Widget build(BuildContext context) {
    final setting = widget.setting;
    final url = setting.usesPlatformImage
        ? _asset?.imageUrl.trim() ?? ''
        : setting.layout == HomeEnvironmentLayouts.simpleEntry
        ? ''
        : setting.imageForIntro(widget.environmentIntro);
    return widget.builder(
      context,
      EnvironmentHomeImage(url: url, assetName: _asset?.name ?? ''),
    );
  }
}
