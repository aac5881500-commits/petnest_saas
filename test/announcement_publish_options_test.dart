import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/features/shop/widgets/content/shop_content_editor_dialog.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    testWidgets(
      'announcement notification options fit $width and unpublished never notifies',
      (tester) async {
        await tester.binding.setSurfaceSize(Size(width, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        ShopContentDraft? saved;
        await tester.pumpWidget(
          MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  child: const Text('open'),
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => ShopContentEditorDialog(
                      isFaq: false,
                      isNew: true,
                      canNotify: true,
                      initial: const ShopContentDraft(
                        title: '營業公告',
                        body: '週日正常營業',
                        isPublished: true,
                      ),
                      onSave: (draft) async => saved = draft,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(
          shopAnnouncementTypes.any((type) => type.value == 'checkin_notice'),
          false,
        );
        final notify = find.widgetWithText(SwitchListTile, '同步通知全店會員');
        await tester.ensureVisible(notify);
        await tester.tap(notify);
        await tester.pumpAndSettle();
        expect(find.text('發布並預覽通知'), findsOneWidget);
        final channel = find.byType(DropdownButtonFormField<String>).last;
        await tester.ensureVisible(channel);
        await tester.tap(channel);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.tap(find.text('只放入 App 通知中心').last);
        await tester.pumpAndSettle();
        final publish = find.widgetWithText(SwitchListTile, '上架顯示');
        await tester.ensureVisible(publish);
        await tester.tap(publish);
        await tester.pumpAndSettle();
        await tester.tap(find.text('儲存為未上架'));
        await tester.pumpAndSettle();
        expect(saved!.isPublished, false);
        expect(saved!.notifyMembers, false);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
