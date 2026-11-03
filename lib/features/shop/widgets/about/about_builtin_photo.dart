// 功能：共用 APP 內建示意照片；同一張圖集使用 Flutter ImageCache，不查詢遠端資料。
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/about_builtin_photos.dart';

class AboutBuiltinPhoto extends StatelessWidget {
  const AboutBuiltinPhoto({
    super.key,
    required this.id,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.center,
  });
  final String id;
  final BoxFit fit;
  final Alignment alignment;
  @override
  Widget build(BuildContext context) {
    final cell = AboutBuiltinPhotos.cell(id);
    if (cell < 0) {
      return const Center(child: Icon(Icons.image_not_supported_outlined));
    }
    return Semantics(
      label: '範本示意照片：${AboutBuiltinPhotos.names[id]}',
      image: true,
      child: ClipRect(
        child: FittedBox(
          fit: fit,
          alignment: alignment,
          child: SizedBox.square(
            dimension: 512,
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned(
                    left: -(cell % 3) * 512.0,
                    top: -(cell ~/ 3) * 512.0,
                    width: 1536,
                    height: 1024,
                    child: Image.asset(
                      AboutBuiltinPhotos.atlas,
                      fit: BoxFit.fill,
                      errorBuilder: (_, error, stack) =>
                          const ColoredBox(color: Color(0xFFF4F0EA)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
