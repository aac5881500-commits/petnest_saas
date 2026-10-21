import 'package:flutter/material.dart';
import 'package:petnest_saas/features/shop/widgets/shop_admin_workspace.dart';

/// Keep both panes under the same parents while the viewport changes.
/// Offstage panes stay bounded and mounted, including text focus and photos.
class ShopRoomTypeWorkspace extends StatelessWidget {
  const ShopRoomTypeWorkspace({
    super.key,
    required this.editor,
    required this.preview,
    required this.showPreview,
    required this.onPreviewChanged,
    this.editLabel = '管理',
    this.previewLabel = '前台預覽',
    this.previewAvailable = true,
  });
  final Widget editor;
  final Widget preview;
  final bool showPreview;
  final ValueChanged<bool> onPreviewChanged;
  final String editLabel;
  final String previewLabel;
  final bool previewAvailable;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final split = constraints.maxWidth >= 1100 && previewAvailable;
      final workspace = ShopAdminWorkspaceScope.maybeOf(context);
      final collapsedForChat =
          MediaQuery.sizeOf(context).width >= 1100 &&
          workspace?.inboxOpen == true &&
          !split &&
          previewAvailable;
      final gap = split ? 20.0 : 0.0;
      return Padding(
        padding: EdgeInsets.fromLTRB(split ? 16 : 8, 8, split ? 16 : 8, 8),
        child: LayoutBuilder(
          builder: (context, inner) {
            final left = split ? (inner.maxWidth - gap) * .4 : inner.maxWidth;
            final right = split ? (inner.maxWidth - gap) * .6 : inner.maxWidth;
            return Column(
              children: [
                SizedBox(
                  height: split || !previewAvailable ? 0 : 52,
                  child: Offstage(
                    offstage: split || !previewAvailable,
                    child: Align(
                      child: collapsedForChat
                          ? TextButton.icon(
                              icon: const Icon(Icons.smartphone_outlined),
                              label: const Text('查看預覽'),
                              onPressed: () => showDialog<void>(
                                context: context,
                                builder: (context) => Dialog(
                                  child: SizedBox(
                                    width: 440,
                                    height:
                                        MediaQuery.sizeOf(context).height * .85,
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            const SizedBox(width: 16),
                                            const Expanded(
                                              child: Text('房型前台預覽'),
                                            ),
                                            IconButton(
                                              tooltip: '關閉預覽',
                                              onPressed: () =>
                                                  Navigator.pop(context),
                                              icon: const Icon(Icons.close),
                                            ),
                                          ],
                                        ),
                                        Expanded(child: preview),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : SegmentedButton<bool>(
                              showSelectedIcon: false,
                              segments: [
                                ButtonSegment(
                                  value: false,
                                  label: Text(editLabel),
                                ),
                                ButtonSegment(
                                  value: true,
                                  label: Text(previewLabel),
                                ),
                              ],
                              selected: {showPreview},
                              onSelectionChanged: (value) =>
                                  onPreviewChanged(value.first),
                            ),
                    ),
                  ),
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned(
                        left: 0,
                        top: 0,
                        bottom: 0,
                        width: left,
                        child: Offstage(
                          offstage:
                              collapsedForChat ||
                              !previewAvailable ||
                              (!split && !showPreview),
                          child: collapsedForChat
                              ? const SizedBox.shrink()
                              : preview,
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        bottom: 0,
                        width: right,
                        child: Offstage(
                          offstage:
                              !collapsedForChat &&
                              previewAvailable &&
                              !split &&
                              showPreview,
                          child: editor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      );
    },
  );
}
