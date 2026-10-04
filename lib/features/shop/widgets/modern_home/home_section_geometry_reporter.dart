import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 區塊完成 layout 後，在下一幀回報全域矩形。不可在 performLayout 裡 setState。
class HomeSectionGeometryReporter extends SingleChildRenderObjectWidget {
  const HomeSectionGeometryReporter({
    super.key,
    required this.sectionId,
    required this.onChanged,
    required super.child,
  });

  final String sectionId;
  final void Function(String sectionId, Rect globalRect) onChanged;

  @override
  RenderObject createRenderObject(BuildContext context) {
    return RenderHomeSectionGeometry(
      sectionId: sectionId,
      onChanged: onChanged,
    );
  }

  @override
  void updateRenderObject(
    BuildContext context,
    covariant RenderHomeSectionGeometry renderObject,
  ) {
    renderObject
      ..sectionId = sectionId
      ..onChanged = onChanged;
  }
}

class RenderHomeSectionGeometry extends RenderProxyBox {
  RenderHomeSectionGeometry({required this.sectionId, required this.onChanged});

  String sectionId;
  void Function(String sectionId, Rect globalRect) onChanged;
  Rect? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final Size reportedSize = size;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!attached || !hasSize) {
        return;
      }
      final Offset origin = localToGlobal(Offset.zero);
      final Rect global = Rect.fromLTWH(
        origin.dx,
        origin.dy,
        reportedSize.width,
        reportedSize.height,
      );
      if (_reported == global) {
        return;
      }
      _reported = global;
      onChanged(sectionId, global);
    });
  }
}
