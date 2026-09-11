// 檔案名稱：test/petnest_cached_image_test.dart
// 功能說明：共用圖片元件空網址與錯誤網址不會崩潰

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:petnest_saas/core/widgets/petnest_cached_image.dart';

void main() {
  testWidgets('空網址顯示預設圖', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 80,
            height: 80,
            child: PetNestCachedImage(imageUrl: ''),
          ),
        ),
      ),
    );
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
  });

  testWidgets('錯誤網址顯示預設圖', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 80,
            height: 80,
            child: PetNestCachedImage(
              imageUrl: 'https://invalid.example/missing.jpg',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(PetNestCachedImage), findsOneWidget);
  });
}
