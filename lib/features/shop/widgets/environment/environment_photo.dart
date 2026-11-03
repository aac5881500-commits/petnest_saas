import '../about/about_builtin_photo.dart';
import 'package:petnest_saas/core/models/about_builtin_photos.dart';
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/environment_layout_settings.dart';

/// A reusable photo source shared by library, editor, preview and public page.
/// Crops contain photography only; every caption/text remains an editable widget.
class EnvironmentPhoto extends StatelessWidget {
  const EnvironmentPhoto({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });
  final String imageUrl;
  final double? width, height;
  final BoxFit fit;
  final Alignment alignment;
  @override
  Widget build(BuildContext context) {
    if (imageUrl.startsWith('builtin-about:')) {
      final aboutId = imageUrl.substring(14);
      if (AboutBuiltinPhotos.names.containsKey(aboutId)) {
        return SizedBox(
          width: width,
          height: height,
          child: AboutBuiltinPhoto(id: aboutId, fit: fit, alignment: alignment),
        );
      }
    }
    final id = EnvironmentBuiltinPhotos.id(imageUrl);
    final placeholder = const ColoredBox(
      color: Color(0xfff5efE5),
      child: Center(child: Icon(Icons.image_outlined)),
    );
    if (id == null) {
      return Image.network(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        alignment: alignment,
        errorBuilder: (_, error, stack) =>
            SizedBox(width: width, height: height, child: placeholder),
      );
    }
    final crop = EnvironmentBuiltinPhotos.crops[id]!;
    return SizedBox(
      width: width,
      height: height,
      child: Semantics(
        image: true,
        label: 'AI 示意照片：${EnvironmentBuiltinPhotos.names[id]}',
        child: ClipRect(
          child: FittedBox(
            fit: fit,
            alignment: alignment,
            child: SizedBox(
              width: crop.width,
              height: crop.height,
              child: ClipRect(
                child: Stack(
                  children: [
                    Positioned(
                      left: -crop.left,
                      top: -crop.top,
                      width: 1536,
                      height: 1024,
                      child: Image.asset(
                        EnvironmentBuiltinPhotos.assetFor(id),
                        fit: BoxFit.fill,
                        errorBuilder: (_, error, stack) => placeholder,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Future<String?> pickEnvironmentBuiltinPhoto(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .7,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('內建示意照片（AI，非店家實景）'),
              ),
              Expanded(
                child: GridView.count(
                  crossAxisCount: 2,
                  padding: const EdgeInsets.all(16),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  children: [
                    for (final entry in EnvironmentBuiltinPhotos.names.entries)
                      InkWell(
                        onTap: () => Navigator.pop(
                          context,
                          EnvironmentBuiltinPhotos.url(entry.key),
                        ),
                        child: Column(
                          children: [
                            Expanded(
                              child: EnvironmentPhoto(
                                imageUrl: EnvironmentBuiltinPhotos.url(
                                  entry.key,
                                ),
                              ),
                            ),
                            Text(entry.value),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
