// 檔案：lib/features/shop/widgets/environment/environment_draft_preview.dart
// 功能：環境草稿的獨立預覽視窗與裝置尺寸，不讀取或寫入資料。
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

class EnvironmentDraftPreview extends StatefulWidget {
  const EnvironmentDraftPreview({
    super.key,
    required this.contentBuilder,
    this.notice = '版型、文案、設備與服務需按儲存後生效；環境特色與相簿操作會立即儲存。',
  });
  final Widget Function(ScrollController controller) contentBuilder;
  final String notice;

  @override
  State<EnvironmentDraftPreview> createState() =>
      EnvironmentDraftPreviewState();
}

class EnvironmentDraftPreviewState extends State<EnvironmentDraftPreview> {
  final ScrollController _scroll = ScrollController();
  bool _desktop = false;
  int _phoneSize = 1;
  static const _sizes = [Size(375, 667), Size(390, 844), Size(430, 932)];
  Future<void> reveal(GlobalKey target) async {
    final targetContext = target.currentContext;
    if (targetContext != null) {
      // Only the preview's scroll position is changed, never an outer dashboard scrollable.
      final viewport = RenderAbstractViewport.maybeOf(
        targetContext.findRenderObject(),
      );
      final render = targetContext.findRenderObject();
      if (viewport != null && render != null && _scroll.hasClients) {
        final offset = viewport.getOffsetToReveal(render, 0).offset;
        await _scroll.animateTo(
          offset.clamp(0.0, _scroll.position.maxScrollExtent),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '即時預覽',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(widget.notice, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      label: Text('手機'),
                      icon: Icon(Icons.phone_android),
                    ),
                    ButtonSegment(
                      value: true,
                      label: Text('桌機'),
                      icon: Icon(Icons.desktop_windows),
                    ),
                  ],
                  selected: {_desktop},
                  onSelectionChanged: (value) =>
                      setState(() => _desktop = value.single),
                ),
                if (!_desktop)
                  Wrap(
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 8,
                    children: [
                      DropdownButton<int>(
                        value: _phoneSize,
                        items: const [
                          DropdownMenuItem(value: 0, child: Text('小')),
                          DropdownMenuItem(value: 1, child: Text('標準')),
                          DropdownMenuItem(value: 2, child: Text('大')),
                        ],
                        onChanged: (value) =>
                            setState(() => _phoneSize = value!),
                      ),
                      Text(
                        '${_sizes[_phoneSize].width.toInt()} × ${_sizes[_phoneSize].height.toInt()}',
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final size = _desktop
                    ? const Size(1200, 800)
                    : _sizes[_phoneSize];
                final width = size.width;
                final height = size.height;
                return ClipRect(
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        alignment: Alignment.topCenter,
                        child: Container(
                          width: width + (_desktop ? 0 : 12),
                          height: height + (_desktop ? 0 : 12),
                          padding: EdgeInsets.all(_desktop ? 0 : 6),
                          decoration: BoxDecoration(
                            color: const Color(0xFF202124),
                            borderRadius: BorderRadius.circular(
                              _desktop ? 0 : 38,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(
                              _desktop ? 0 : 32,
                            ),
                            child: MediaQuery(
                              data: MediaQuery.of(context).copyWith(
                                size: Size(width, height),
                                padding: _desktop
                                    ? EdgeInsets.zero
                                    : const EdgeInsets.only(
                                        top: 28,
                                        bottom: 24,
                                      ),
                                viewPadding: _desktop
                                    ? EdgeInsets.zero
                                    : const EdgeInsets.only(
                                        top: 28,
                                        bottom: 24,
                                      ),
                                viewInsets: EdgeInsets.zero,
                              ),
                              child: ColoredBox(
                                color: Colors.white,
                                child: Column(
                                  children: [
                                    if (!_desktop)
                                      const SizedBox(
                                        height: 28,
                                        child: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 18,
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                '9:41',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black,
                                                ),
                                              ),
                                              Icon(
                                                Icons.battery_full,
                                                size: 16,
                                                color: Colors.black,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    Expanded(
                                      child: MediaQuery(
                                        data: MediaQuery.of(context).copyWith(
                                          size: size,
                                          padding: EdgeInsets.zero,
                                          viewPadding: EdgeInsets.zero,
                                          viewInsets: EdgeInsets.zero,
                                        ),
                                        child: widget.contentBuilder(_scroll),
                                      ),
                                    ),
                                    if (!_desktop)
                                      SizedBox(
                                        height: 24,
                                        child: Center(
                                          child: Container(
                                            width: 120,
                                            height: 4,
                                            decoration: BoxDecoration(
                                              color: Colors.black87,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
