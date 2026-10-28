import 'package:universal_html/html.dart' as html;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:petnest_saas/core/models/pet_service_module.dart';
import 'package:petnest_saas/features/shop/pages/services/shop_service_module_hub.dart';
import 'package:petnest_saas/features/shop/pages/services/shop_pet_service_booking_page.dart';
import 'service_modules_fixture.dart';

void main() {
  html.document.getElementById('petnest-startup')?.remove();
  html.document.title = 'PetNest 其他模組預覽';
  runApp(const ServiceModulesPreview());
}

class ServiceModulesPreview extends StatefulWidget {
  const ServiceModulesPreview({super.key});
  @override
  State<ServiceModulesPreview> createState() => _PreviewState();
}

class _PreviewState extends State<ServiceModulesPreview> {
  final repository = ServiceModulesFixture();
  int selected = 0;
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'TW'),
    supportedLocales: const [Locale('zh', 'TW')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      useMaterial3: true,
      fontFamily: 'NotoSansTC',
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff50609a)),
      scaffoldBackgroundColor: const Color(0xfff6f7fc),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xffe1e5f1)),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    ),
    home: Builder(
      builder: (context) => Scaffold(
        appBar: AppBar(
          title: const Text('PetNest · 其他模組預覽'),
          actions: [
            TextButton.icon(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('我要預約')),
                    body: ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(bottom: 20),
                          child: Text(
                            '所有預約集中在這裡，再依服務分類。',
                            style: TextStyle(fontSize: 20),
                          ),
                        ),
                        for (final module in PetServiceModule.all)
                          Card(
                            child: ListTile(
                              leading: Icon(module.icon),
                              title: Text(module.title),
                              subtitle: Text(module.subtitle),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ShopPetServiceBookingPage(
                                    shopId: 'preview',
                                    module: module,
                                    repository: repository,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              icon: const Icon(Icons.event),
              label: const Text('我要預約'),
            ),
          ],
        ),
        body: Column(
          children: [
            Container(
              width: double.infinity,
              color: const Color(0xfffff2d6),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: const Text('互動示範 · 使用本機範例資料，可試編輯、排班與處理預約；不寫入真實店家。'),
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final hub = ShopServiceModuleHub(
                    key: ValueKey(selected),
                    shopId: 'preview',
                    module: PetServiceModule.all[selected],
                    canConfigure: true,
                    canManage: true,
                    repository: repository,
                  );
                  if (box.maxWidth < 700) {
                    return Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              for (var i = 0; i < 3; i++)
                                ChoiceChip(
                                  label: Text(PetServiceModule.all[i].title),
                                  selected: selected == i,
                                  onSelected: (_) =>
                                      setState(() => selected = i),
                                ),
                            ],
                          ),
                        ),
                        Expanded(child: hub),
                      ],
                    );
                  }
                  return Row(
                    children: [
                      Container(
                        width: 225,
                        color: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Padding(
                              padding: EdgeInsets.all(12),
                              child: Text(
                                '店家後台',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const ListTile(
                              leading: Icon(Icons.storefront),
                              title: Text('基本資訊（共用）'),
                            ),
                            for (var i = 0; i < 3; i++)
                              ListTile(
                                selected: selected == i,
                                selectedTileColor: const Color(0xffeef0f8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                leading: Icon(PetServiceModule.all[i].icon),
                                title: Text(PetServiceModule.all[i].title),
                                onTap: () => setState(() => selected = i),
                              ),
                            const ListTile(
                              leading: Icon(Icons.bar_chart),
                              title: Text('表格統計'),
                            ),
                          ],
                        ),
                      ),
                      Expanded(child: hub),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
