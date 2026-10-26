import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/models/pre_arrival_guide_model.dart';
import 'package:petnest_saas/features/booking/pages/pre_arrival_guide_page.dart';
import 'package:petnest_saas/features/shop/widgets/pre_arrival_workspace.dart';

void main() {
  testWidgets('desktop preview stays left and updates from unsaved edits', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var title = '原標題';
    var fullscreen = 0;
    await tester.pumpWidget(MaterialApp(home: StatefulBuilder(builder: (context, setState) => Scaffold(
      body: PreArrivalWorkspace(
        editor: ListView(children: [TextField(onChanged: (value) => setState(() => title = value))]),
        preview: PreArrivalGuidePage(embedded: true,
          guide: PreArrivalGuideModel(shopId: '', serviceType: 'accommodation', title: title)),
        onFullscreen: () => fullscreen++,
      ),
    ))));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(find.byType(PreArrivalGuidePage)).dx,
      lessThan(tester.getTopLeft(find.byType(TextField)).dx));
    await tester.enterText(find.byType(TextField), '剛修改的草稿');
    await tester.pumpAndSettle();
    expect(find.text('剛修改的草稿'), findsNWidgets(2));
    await tester.tap(find.text('全畫面'));
    expect(fullscreen, 1);
    expect(find.byType(BackButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('mobile keeps only the editor', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: PreArrivalWorkspace(
      editor: const Text('編輯區'), preview: const Text('預覽區'), onFullscreen: () {},
    ))));
    expect(find.text('編輯區'), findsOneWidget);
    expect(find.text('預覽區'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
