import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/modern_home/editable_home_section.dart';

void main() {
  testWidgets('編排畫布切換寬度、選取、開關與重新進入不會拆掉 render object', (
    WidgetTester tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(const _CanvasHost());
    expect(tester.takeException(), isNull);
    expect(find.text('桌面設定'), findsOneWidget);
    expect(find.text('活動海報'), findsOneWidget);

    await tester.tap(find.text('活動海報'));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('已選 banners'), findsOneWidget);

    await tester.tap(find.text('顯示熱門房型'));
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('熱門房型'), findsNothing);

    tester.view.physicalSize = const Size(800, 900);
    await tester.pumpWidget(const _CanvasHost());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('活動海報'), findsOneWidget);
    expect(find.text('桌面設定'), findsNothing);

    await tester.tap(find.text('活動海報'));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    tester.view.physicalSize = const Size(1400, 900);
    await tester.pumpWidget(const _CanvasHost());
    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.text('活動海報'), findsOneWidget);
    expect(find.text('桌面設定'), findsOneWidget);
  });
}

class _CanvasHost extends StatefulWidget {
  const _CanvasHost();

  @override
  State<_CanvasHost> createState() => _CanvasHostState();
}

class _CanvasHostState extends State<_CanvasHost> {
  String? _selected;
  bool _roomsEnabled = true;

  @override
  Widget build(BuildContext context) {
    final bool desktop = MediaQuery.sizeOf(context).width >= 1100;
    final String canvasMode = desktop ? 'desktop' : 'mobile';
    return MaterialApp(
      home: Scaffold(
        body: desktop
            ? Row(
                children: <Widget>[
                  SizedBox(
                    width: 452,
                    child: _Canvas(
                      canvasMode: canvasMode,
                      selected: _selected,
                      roomsEnabled: _roomsEnabled,
                      onSelect: (String id) => setState(() => _selected = id),
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      children: <Widget>[
                        const Text('桌面設定'),
                        Text('已選 ${_selected ?? '無'}'),
                        SwitchListTile(
                          value: _roomsEnabled,
                          title: const Text('顯示熱門房型'),
                          onChanged: (bool value) {
                            setState(() => _roomsEnabled = value);
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : _Canvas(
                canvasMode: canvasMode,
                selected: _selected,
                roomsEnabled: _roomsEnabled,
                onSelect: (String id) => setState(() => _selected = id),
              ),
      ),
    );
  }
}

class _Canvas extends StatefulWidget {
  const _Canvas({
    required this.canvasMode,
    required this.selected,
    required this.roomsEnabled,
    required this.onSelect,
  });

  final String canvasMode;
  final String? selected;
  final bool roomsEnabled;
  final ValueChanged<String> onSelect;

  @override
  State<_Canvas> createState() => _CanvasState();
}

class _CanvasState extends State<_Canvas> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const List<String> sectionIds = <String>['banners', 'rooms'];
    return Column(
      children: <Widget>[
        const Text('首頁編排畫布'),
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            primary: false,
            itemCount: sectionIds.length,
            itemBuilder: (BuildContext context, int index) {
              final String id = sectionIds[index];
              return EditableHomeSection(
                key: ValueKey<String>('${widget.canvasMode}_$id'),
                sectionId: id,
                enabled: id == 'rooms' ? widget.roomsEnabled : true,
                selected: widget.selected == id,
                onSelect: () => widget.onSelect(id),
                child: SizedBox(
                  height: 48,
                  child: Text(id == 'banners' ? '活動海報' : '熱門房型'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
