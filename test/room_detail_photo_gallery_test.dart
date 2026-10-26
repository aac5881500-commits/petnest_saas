import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/room_intro_appearance.dart';
import 'package:petnest_saas/features/shop/widgets/room/room_detail_photo_gallery.dart';

const layouts = <String>['bottom', 'left', 'right', 'overlay', 'collage', 'grid'];
void main() {
  test('photo layout persists independently of page layout, old and unknown data fall back', () {
    for (final layout in layouts) {
      final source = RoomDetailAppearance(layout: 'tabs', photoLayout: layout);
      final restored = RoomDetailAppearance.fromMap(source.toMap());
      expect(restored.photoLayout, layout);
      expect(restored.copyWith(imageFit: 'contain').photoLayout, layout);
      expect(restored.layout, 'tabs');
    }
    expect(RoomDetailAppearance.fromMap(null).photoLayout, 'bottom');
    expect(RoomDetailAppearance.fromMap({'photoLayout': 'unknown'}).photoLayout, 'bottom');
  });
  for (final width in <double>[320, 390, 1000]) {
    testWidgets('all galleries fit $width with zero, one, two and many photos', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final layout in layouts) {
        for (final count in <int>[0, 1, 2, 7]) {
          int selected = 0;
          int? opened;
          await tester.pumpWidget(MaterialApp(home: Scaffold(body: SingleChildScrollView(
            child: Padding(padding: const EdgeInsets.all(16), child: StatefulBuilder(
              builder: (_, setState) => RoomDetailPhotoGallery(
                layout: layout, count: count, selected: selected, showThumbnails: true,
                aspectRatio: 4 / 3, radius: 18, accent: Colors.orange,
                main: const AspectRatio(aspectRatio: 4 / 3, child: ColoredBox(color: Colors.blue)),
                imageBuilder: (index) => ColoredBox(color: Colors.primaries[index % Colors.primaries.length]),
                onSelected: (index) => setState(() => selected = index),
                onOpen: (index) => opened = index,
              ),
            )),
          ))));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull, reason: '$layout / $count / $width');
          if (count > 1 && <String>['collage', 'grid'].contains(layout)) {
            await tester.tap(find.byKey(const ValueKey<String>('room-photo-tile-0')));
            expect(opened, 0);
          } else if (count > 1) {
            await tester.tap(find.byTooltip('下一張照片'));
            await tester.pump();
            expect(selected, 1);
            expect(find.text('2 / $count'), findsOneWidget);
            if (layout == 'left' || layout == 'right') {
              final mainRect = tester.getRect(find.byType(AspectRatio));
              final thumb = tester.getRect(find.byKey(const ValueKey<String>('room-photo-thumb-0')));
              expect(layout == 'left' ? thumb.right <= mainRect.left : thumb.left >= mainRect.right, isTrue);
            }
          }
          if (count == 7 && layout == 'collage') {
            await tester.tap(find.text('查看全部 7 張'));
            await tester.pumpAndSettle();
            expect(find.text('全部照片（7 張）'), findsOneWidget);
            await tester.scrollUntilVisible(find.byKey(const ValueKey<String>('room-photo-tile-6')), 200,
              scrollable: find.descendant(of: find.byType(GridView), matching: find.byType(Scrollable)));
            await tester.pumpAndSettle();
            await tester.ensureVisible(find.byKey(const ValueKey<String>('room-photo-tile-6')));
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const ValueKey<String>('room-photo-tile-6')));
            expect(opened, 6);
            await tester.tap(find.byTooltip('關閉相簿'));
            await tester.pumpAndSettle();
          }
        }
      }
    });
  }
}
