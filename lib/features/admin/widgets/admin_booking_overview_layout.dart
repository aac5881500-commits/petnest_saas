import 'package:flutter/material.dart';

enum BookingOverviewLayout {
  split('左右雙欄', '左邊看訂單與照護，右邊處理收款', Icons.view_sidebar_outlined),
  columns('三欄工作台', '訂單資料、照護、操作並排查看', Icons.view_column_outlined),
  bands('上下分區', '全寬摘要與橫向區塊，由上往下閱讀', Icons.view_agenda_outlined),
  pets('寵物分組', '寵物與照護放在主區，訂單資料放旁邊', Icons.pets_outlined),
  workflow('流程導向', '依訂單處理、照護、文件交接分段操作', Icons.format_list_numbered);

  const BookingOverviewLayout(this.label, this.description, this.icon);
  final String label, description;
  final IconData icon;
}

/// Each data block is mounted once. Global keys preserve its state when moved.
class AdminBookingOverviewLayout extends StatefulWidget {
  const AdminBookingOverviewLayout({
    super.key,
    required this.layout,
    required this.blocks,
    this.operations = false,
  });
  final BookingOverviewLayout layout;
  final bool operations;
  final Map<String, Widget> blocks;
  @override
  State<AdminBookingOverviewLayout> createState() =>
      _AdminBookingOverviewLayoutState();
}

class _AdminBookingOverviewLayoutState
    extends State<AdminBookingOverviewLayout> {
  final Map<String, GlobalKey> _keys = {};
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final medium = constraints.maxWidth >= 600;
        Widget block(String id) => KeyedSubtree(
          key: _keys.putIfAbsent(id, GlobalKey.new),
          child: KeyedSubtree(
            key: ValueKey('overview-block-$id'),
            child: widget.blocks[id]!,
          ),
        );
        Widget stack(List<String> ids) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final id in ids.where(widget.blocks.containsKey))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: block(id),
              ),
          ],
        );
        Widget columns(
          List<List<String>> groups,
          List<int> flex, {
          bool? enabled,
        }) {
          if (!(enabled ?? wide)) {
            return stack(groups.expand((group) => group).toList());
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < groups.length; i++) ...[
                if (i > 0) const SizedBox(width: 16),
                Expanded(flex: flex[i], child: stack(groups[i])),
              ],
            ],
          );
        }

        Widget step(String number, String title, List<String> ids) => Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE4E7EE)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 15,
                    child: Text(number, style: const TextStyle(fontSize: 13)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (wide && ids.length == 2)
                columns(
                  [
                    [ids[0]],
                    [ids[1]],
                  ],
                  [1, 1],
                )
              else if (wide && ids.length == 3)
                columns(
                  [
                    [ids[0], ids[2]],
                    [ids[1]],
                  ],
                  [1, 1],
                )
              else
                stack(ids),
            ],
          ),
        );
        if (widget.operations) {
          const primary = ['actions', 'progress', 'next', 'pets', 'care', 'summary'];
          const aside = ['balance', 'contacts', 'resources'];
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              stack(['overview']),
              columns([primary, aside], [2, 1], enabled: constraints.maxWidth >= 780),
            ],
          );
        }
        final layout = switch (widget.layout) {
          BookingOverviewLayout.split =>
            !wide
                ? stack([
                    'overview',
                    'actions',
                    'progress',
                    'pets',
                    'care',
                    'summary',
                    'contacts',
                    'balance',
                    'resources',
                  ])
                : columns(
                    [
                      ['overview', 'pets', 'care', 'summary', 'resources'],
                      ['progress', 'actions', 'contacts', 'balance'],
                    ],
                    [7, 3],
                  ),
          BookingOverviewLayout.columns => columns(
            [
              ['overview', 'contacts'],
              ['pets', 'progress', 'care', 'summary', 'resources'],
              ['actions', 'balance'],
            ],
            [3, 4, 3],
          ),
          BookingOverviewLayout.bands => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              stack(['overview']),
              columns(
                [
                  ['balance'],
                  ['actions'],
                ],
                [1, 1],
                enabled: medium,
              ),
              columns(
                [
                  ['pets'],
                  ['care'],
                ],
                [1, 1],
                enabled: medium,
              ),
              stack(['progress', 'summary']),
              columns(
                [
                  ['contacts'],
                  ['resources'],
                ],
                [1, 1],
                enabled: medium,
              ),
            ],
          ),
          BookingOverviewLayout.pets => columns(
            [
              ['pets', 'progress', 'care', 'summary', 'contacts', 'resources'],
              ['overview', 'actions', 'balance'],
            ],
            [6, 4],
          ),
          BookingOverviewLayout.workflow => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              stack(['overview']),
              step('1', '處理訂單與收款', ['actions', 'balance']),
              stack(['progress']),
              step('2', '確認寵物與照護', ['pets', 'care', 'summary']),
              step('3', '聯絡、文件與交接', ['contacts', 'resources']),
            ],
          ),
        };
        return KeyedSubtree(
          key: ValueKey('overview-layout-${widget.layout.name}'),
          child: layout,
        );
      },
    );
  }
}

class BookingLayoutThumbnail extends StatelessWidget {
  const BookingLayoutThumbnail({
    super.key,
    required this.layout,
    required this.color,
  });
  final BookingOverviewLayout layout;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 70,
    height: 48,
    child: CustomPaint(painter: _LayoutPainter(layout, color)),
  );
}

class _LayoutPainter extends CustomPainter {
  _LayoutPainter(this.layout, this.color);
  final BookingOverviewLayout layout;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color.withValues(alpha: 0.35);
    void box(double x, double y, double w, double h) => canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x * size.width,
          y * size.height,
          w * size.width,
          h * size.height,
        ),
        const Radius.circular(3),
      ),
      paint,
    );
    switch (layout) {
      case BookingOverviewLayout.split:
        box(0, 0, .65, 1);
        box(.7, 0, .3, 1);
      case BookingOverviewLayout.columns:
        box(0, 0, .28, 1);
        box(.33, 0, .34, 1);
        box(.72, 0, .28, 1);
      case BookingOverviewLayout.bands:
        box(0, 0, 1, .25);
        box(0, .32, 1, .3);
        box(0, .69, 1, .31);
      case BookingOverviewLayout.pets:
        box(0, 0, .56, .46);
        box(0, .54, .56, .46);
        box(.62, 0, .38, 1);
      case BookingOverviewLayout.workflow:
        box(0, 0, .12, 1);
        box(.2, 0, .8, .28);
        box(.2, .36, .8, .28);
        box(.2, .72, .8, .28);
    }
  }

  @override
  bool shouldRepaint(_LayoutPainter old) =>
      old.layout != layout || old.color != color;
}
