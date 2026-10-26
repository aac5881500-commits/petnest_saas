import 'package:flutter/material.dart';

/// Wide screens keep the customer draft next to the editor.
class PreArrivalWorkspace extends StatelessWidget {
  const PreArrivalWorkspace({
    super.key,
    required this.editor,
    required this.preview,
    required this.onFullscreen,
  });
  final Widget editor;
  final Widget preview;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 1000) return editor;
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                Material(
                  color: Theme.of(context).colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '客戶即時預覽',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                              Text(
                                '右側修改會同步顯示，尚未儲存也能預覽。',
                                style: TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: onFullscreen,
                          icon: const Icon(Icons.open_in_full, size: 16),
                          label: const Text('全畫面'),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(child: preview),
              ],
            ),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: editor),
        ],
      );
    },
  );
}
