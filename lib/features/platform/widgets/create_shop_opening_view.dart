// 檔案名稱：lib/features/platform/widgets/create_shop_opening_view.dart
// 功能說明：建立旅社頁的手機單欄與桌機雙欄畫面。不呼叫 Firebase。

import 'dart:ui' as ui;

import 'package:flutter/material.dart';

const _ink = Color(0xFF74250F);
const _muted = Color(0xFF796A5D);
const _orange = Color(0xFFF45B14);
const _cream = Color(0xFFFFFAF2);
const _card = Color(0xFFFFFDF9);
const _line = Color(0xFFF3E7D8);
const _desktopPhoto = 'assets/images/shop_onboarding/welcome_desktop.webp';
const _mobilePhoto = 'assets/images/shop_onboarding/welcome_mobile.webp';
const _regularAxes = [ui.FontVariation('wght', 400)];
const _mediumAxes = [ui.FontVariation('wght', 600)];
const _boldAxes = [ui.FontVariation('wght', 800)];

class CreateShopOpeningView extends StatelessWidget {
  const CreateShopOpeningView({
    super.key,
    required this.nameController,
    required this.city,
    required this.district,
    required this.cities,
    required this.districts,
    required this.onCityChanged,
    required this.onDistrictChanged,
    required this.loading,
    required this.activationReady,
    required this.onSubmit,
    required this.onBack,
  });

  final TextEditingController nameController;
  final String city;
  final String district;
  final List<String> cities;
  final List<String> districts;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onDistrictChanged;
  final bool loading;
  final bool activationReady;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _cream,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: DefaultTextStyle.merge(
          style: const TextStyle(
            fontFamily: 'NotoSansTC',
            fontVariations: _regularAxes,
            color: _ink,
          ),
          child: LayoutBuilder(
            builder: (context, viewport) {
              final desktop = viewport.maxWidth >= 1024;
              if (desktop) {
                return _DesktopFrame(
                  viewport: viewport,
                  form: _form(sideBySide: true),
                  activationReady: activationReady,
                  loading: loading,
                  onSubmit: onSubmit,
                  onBack: onBack,
                );
              }
              return _PhoneFrame(
                wide: viewport.maxWidth >= 700,
                form: _form(sideBySide: false),
                activationReady: activationReady,
                loading: loading,
                onSubmit: onSubmit,
                onBack: onBack,
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _form({required bool sideBySide}) {
    return _ShopForm(
      nameController: nameController,
      city: city,
      district: district,
      cities: cities,
      districts: districts,
      onCityChanged: onCityChanged,
      onDistrictChanged: onDistrictChanged,
      sideBySide: sideBySide,
    );
  }
}

class _PhoneFrame extends StatelessWidget {
  const _PhoneFrame({
    required this.wide,
    required this.form,
    required this.activationReady,
    required this.loading,
    required this.onSubmit,
    required this.onBack,
  });

  final bool wide;
  final Widget form;
  final bool activationReady;
  final bool loading;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final inset = wide ? 28.0 : 16.0;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(inset, 10, inset, 4),
          child: _TopBar(onBack: onBack, compact: !wide),
        ),
        Expanded(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: ListView(
                key: const ValueKey('create-shop-scroll'),
                padding: EdgeInsets.fromLTRB(inset, 8, inset, 20),
                children: [
                  _StepRail(activationReady: activationReady),
                  const SizedBox(height: 14),
                  const _IntroCard(),
                  form,
                  if (activationReady) ...[
                    const SizedBox(height: 14),
                    const _ActivationNote(),
                  ],
                  const SizedBox(height: 18),
                  _CreateButton(loading: loading, onSubmit: onSubmit),
                  const SizedBox(height: 8),
                  const Text(
                    '建立後，還可以隨時完善你的旅社設定。',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopFrame extends StatelessWidget {
  const _DesktopFrame({
    required this.viewport,
    required this.form,
    required this.activationReady,
    required this.loading,
    required this.onSubmit,
    required this.onBack,
  });

  final BoxConstraints viewport;
  final Widget form;
  final bool activationReady;
  final bool loading;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final wide = viewport.maxWidth >= 1440;
    return SingleChildScrollView(
      key: const ValueKey('create-shop-scroll'),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: viewport.maxHeight),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1560),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: wide ? 40 : 28,
                vertical: 28,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(child: _BrandPanel()),
                  SizedBox(width: wide ? 36 : 24),
                  Expanded(
                    child: _FormPanel(
                      form: form,
                      activationReady: activationReady,
                      loading: loading,
                      onSubmit: onSubmit,
                      onBack: onBack,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.onBack, required this.compact});

  final VoidCallback onBack;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.pets_rounded, size: 28, color: Color(0xFFB23A0B)),
        const SizedBox(width: 8),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'PetNest',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 18,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  fontVariations: _boldAxes,
                ),
              ),
              Text(
                '開店小幫手',
                maxLines: 1,
                style: TextStyle(color: _muted, fontSize: 12, height: 1.3),
              ),
            ],
          ),
        ),
        TextButton.icon(
          key: const ValueKey('create-shop-back'),
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back_rounded, size: 16),
          label: Text(compact ? '返回' : '返回上一頁'),
          style: TextButton.styleFrom(
            foregroundColor: _ink,
            backgroundColor: const Color(0xF5FFFCF5),
            minimumSize: const Size(44, 40),
            padding: const EdgeInsets.symmetric(horizontal: 12),
            shape: const StadiumBorder(
              side: BorderSide(color: Color(0xFFF0DDC3)),
            ),
            textStyle: const TextStyle(
              fontFamily: 'NotoSansTC',
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _StepRail extends StatelessWidget {
  const _StepRail({required this.activationReady});

  final bool activationReady;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StepMark(
            label: '激活碼驗證',
            done: activationReady,
            current: false,
          ),
        ),
        const _StepLine(active: true),
        const Expanded(
          child: _StepMark(label: '建立旅社', done: false, current: true),
        ),
        const _StepLine(active: false),
        const Expanded(
          child: _StepMark(label: '開始設定', done: false, current: false),
        ),
      ],
    );
  }
}

class _StepMark extends StatelessWidget {
  const _StepMark({
    required this.label,
    required this.done,
    required this.current,
  });

  final String label;
  final bool done;
  final bool current;

  @override
  Widget build(BuildContext context) {
    final color = done || current ? _orange : const Color(0xFFCDB9A6);
    return Column(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: done
                ? const Color(0xFF5E8A45)
                : current
                ? _orange
                : const Color(0xFFFFF6EE),
            shape: BoxShape.circle,
            border: Border.all(color: color),
          ),
          child: Icon(
            done ? Icons.check_rounded : Icons.circle,
            size: done ? 14 : 7,
            color: done || current ? Colors.white : color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          maxLines: 2,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: current ? _ink : _muted,
            fontSize: 11,
            fontWeight: current ? FontWeight.w700 : FontWeight.w500,
            fontVariations: current ? _mediumAxes : _regularAxes,
            height: 1.25,
          ),
        ),
      ],
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 2,
      margin: const EdgeInsets.only(bottom: 18),
      color: active ? const Color(0xFFF3C2A4) : const Color(0xFFEADCCE),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // 直式照片 1024×1536，臉在中下段。容器取臉部附近，避免只切到耳朵。
        final photoHeight = (constraints.maxWidth * 0.64).clamp(188.0, 268.0);
        return Column(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(22),
              ),
              child: SizedBox(
                height: photoHeight,
                width: double.infinity,
                child: Image.asset(
                  _mobilePhoto,
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, 0.42),
                  cacheWidth: 960,
                  semanticLabel: '暖陽照入木質貓咪旅社',
                  errorBuilder: (context, error, stackTrace) =>
                      const ColoredBox(color: Color(0xFFF6E7D4)),
                ),
              ),
            ),
            Transform.translate(
              offset: const Offset(0, -20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                decoration: _cardDecoration(22),
                child: const _IntroCopy(),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _IntroCopy extends StatelessWidget {
  const _IntroCopy();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '幫你的旅社取個名字吧！',
          style: TextStyle(
            fontSize: 22,
            height: 1.35,
            fontWeight: FontWeight.w800,
            fontVariations: _boldAxes,
          ),
        ),
        SizedBox(height: 8),
        Text(
          '只要完成幾項基本資料，就能建立你的專屬 PetNest 旅社。',
          style: TextStyle(color: _muted, fontSize: 14, height: 1.6),
        ),
        SizedBox(height: 8),
        Text(
          '房型、價格和服務內容，都可以建立後再慢慢設定。',
          style: TextStyle(
            color: Color(0xFF8A5A32),
            fontSize: 13,
            height: 1.55,
          ),
        ),
      ],
    );
  }
}

class _ShopForm extends StatelessWidget {
  const _ShopForm({
    required this.nameController,
    required this.city,
    required this.district,
    required this.cities,
    required this.districts,
    required this.onCityChanged,
    required this.onDistrictChanged,
    required this.sideBySide,
  });

  final TextEditingController nameController;
  final String city;
  final String district;
  final List<String> cities;
  final List<String> districts;
  final ValueChanged<String?> onCityChanged;
  final ValueChanged<String?> onDistrictChanged;
  final bool sideBySide;

  @override
  Widget build(BuildContext context) {
    final cityField = _CityField(
      city: city,
      cities: cities,
      onChanged: onCityChanged,
    );
    final districtField = _DistrictField(
      city: city,
      district: district,
      districts: districts,
      onChanged: city.isEmpty ? null : onDistrictChanged,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      decoration: _cardDecoration(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NameField(controller: nameController),
          const SizedBox(height: 16),
          if (sideBySide)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cityField),
                const SizedBox(width: 12),
                Expanded(child: districtField),
              ],
            )
          else ...[
            cityField,
            const SizedBox(height: 16),
            districtField,
          ],
        ],
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('你的旅社叫什麼名字？'),
        TextField(
          key: const ValueKey('create-shop-name'),
          controller: controller,
          textInputAction: TextInputAction.next,
          style: const TextStyle(fontSize: 16, color: Color(0xFF30261E)),
          decoration: _fieldDecoration(hint: '例如：喵星人貓咪旅館'),
        ),
        const SizedBox(height: 6),
        const Text(
          '這個名稱會顯示在你的旅社頁面。',
          style: TextStyle(color: _muted, fontSize: 12, height: 1.4),
        ),
      ],
    );
  }
}

class _CityField extends StatelessWidget {
  const _CityField({
    required this.city,
    required this.cities,
    required this.onChanged,
  });

  final String city;
  final List<String> cities;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('旅社位於哪個縣市？'),
        DropdownButtonFormField<String>(
          key: const ValueKey('create-shop-city'),
          initialValue: city.isEmpty ? null : city,
          isExpanded: true,
          menuMaxHeight: 320,
          decoration: _fieldDecoration(hint: '選擇縣市'),
          items: [
            for (final item in cities)
              DropdownMenuItem(value: item, child: Text(item)),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _DistrictField extends StatelessWidget {
  const _DistrictField({
    required this.city,
    required this.district,
    required this.districts,
    required this.onChanged,
  });

  final String city;
  final String district;
  final List<String> districts;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    final selected = districts.contains(district) ? district : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('選擇所在區域'),
        DropdownButtonFormField<String>(
          // 縣市改變時重建，避免區域選單留下上一個縣市的選擇。
          key: ValueKey('create-shop-district-$city'),
          initialValue: selected,
          isExpanded: true,
          menuMaxHeight: 320,
          decoration: _fieldDecoration(hint: city.isEmpty ? '請先選擇縣市' : '選擇區域'),
          items: [
            for (final item in districts)
              DropdownMenuItem(value: item, child: Text(item)),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF30261E),
          fontSize: 14,
          fontWeight: FontWeight.w700,
          fontVariations: _mediumAxes,
          height: 1.4,
        ),
      ),
    );
  }
}

class _ActivationNote extends StatelessWidget {
  const _ActivationNote();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('create-shop-code-ready'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F8EF),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFD7E6CC)),
      ),
      child: const Row(
        children: [
          Icon(Icons.verified_rounded, color: Color(0xFF5E8A45), size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '激活碼已驗證完成',
                  style: TextStyle(
                    color: Color(0xFF3E6A32),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    fontVariations: _mediumAxes,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  '不需要再次輸入，建立後即可開始設定旅社。',
                  style: TextStyle(
                    color: Color(0xFF5E7354),
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.loading, required this.onSubmit});

  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: loading
              ? const [Color(0xFFE7B9A4), Color(0xFFE7B9A4)]
              : const [Color(0xFFFF751F), Color(0xFFF04F0C)],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [
          BoxShadow(
            color: Color(0x26E96920),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: FilledButton(
        key: const ValueKey('create-shop-submit'),
        onPressed: loading ? null : onSubmit,
        style: FilledButton.styleFrom(
          backgroundColor: Colors.transparent,
          disabledBackgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white70,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 54),
          shape: const StadiumBorder(),
        ),
        child: loading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                  SizedBox(width: 10),
                  Text('建立中...'),
                ],
              )
            : const Text(
                '建立我的旅社 →',
                style: TextStyle(
                  fontFamily: 'NotoSansTC',
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }
}

class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _DesktopBrand(),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(28)),
          child: ColoredBox(
            color: Color(0xFFF6E7D4),
            child: AspectRatio(
              aspectRatio: 1774 / 887,
              child: Image.asset(
                _desktopPhoto,
                fit: BoxFit.contain,
                alignment: Alignment.center,
                semanticLabel: '暖陽照入木質貓咪旅社，長毛虎斑貓躺在柔軟地毯上',
                errorBuilder: (context, error, stackTrace) =>
                    const ColoredBox(color: Color(0xFFF6E7D4)),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        const Text(
          '幫你的旅社\n取個名字吧',
          style: TextStyle(
            fontSize: 36,
            height: 1.2,
            fontWeight: FontWeight.w800,
            fontVariations: _boldAxes,
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          '只要完成幾項基本資料，就能建立你的專屬 PetNest 旅社。',
          style: TextStyle(fontSize: 16, height: 1.6),
        ),
        const SizedBox(height: 18),
        const _DesktopSteps(),
      ],
    );
  }
}

class _DesktopBrand extends StatelessWidget {
  const _DesktopBrand();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Icon(Icons.pets_rounded, size: 30, color: Color(0xFFB23A0B)),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PetNest',
              style: TextStyle(
                fontSize: 22,
                height: 1.1,
                fontWeight: FontWeight.w800,
                fontVariations: _boldAxes,
              ),
            ),
            Text('開店小幫手', style: TextStyle(fontSize: 12, height: 1.3)),
          ],
        ),
      ],
    );
  }
}

class _DesktopSteps extends StatelessWidget {
  const _DesktopSteps();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('1', '激活碼驗證', '資格已確認'),
      ('2', '建立旅社', '現在這一步'),
      ('3', '開始設定', '建立後再慢慢完成'),
    ];
    return Column(
      children: [
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF0D5),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    item.$1,
                    style: const TextStyle(
                      color: _orange,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  item.$2,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontVariations: _mediumAxes,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  item.$3,
                  style: const TextStyle(color: _muted, fontSize: 13),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({
    required this.form,
    required this.activationReady,
    required this.loading,
    required this.onSubmit,
    required this.onBack,
  });

  final Widget form;
  final bool activationReady;
  final bool loading;
  final VoidCallback onSubmit;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _cardDecoration(28),
      padding: const EdgeInsets.fromLTRB(28, 18, 28, 22),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('create-shop-back'),
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded, size: 16),
              label: const Text('返回上一頁'),
              style: TextButton.styleFrom(
                foregroundColor: _ink,
                minimumSize: const Size(44, 40),
              ),
            ),
          ),
          _StepRail(activationReady: activationReady),
          const SizedBox(height: 16),
          const Text(
            '幫你的旅社取個名字吧！',
            style: TextStyle(
              fontSize: 28,
              height: 1.3,
              fontWeight: FontWeight.w800,
              fontVariations: _boldAxes,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '房型、價格和服務內容，都可以建立後再慢慢設定。',
            style: TextStyle(color: _muted, fontSize: 14, height: 1.5),
          ),
          const SizedBox(height: 18),
          form,
          if (activationReady) ...[
            const SizedBox(height: 14),
            const _ActivationNote(),
          ],
          const SizedBox(height: 18),
          _CreateButton(loading: loading, onSubmit: onSubmit),
          const SizedBox(height: 8),
          const Text(
            '建立後，還可以隨時完善你的旅社設定。',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration(double radius) => BoxDecoration(
  color: _card,
  borderRadius: BorderRadius.circular(radius),
  border: Border.all(color: _line),
  boxShadow: const [
    BoxShadow(color: Color(0x0E784A22), blurRadius: 24, offset: Offset(0, 6)),
  ],
);

InputDecoration _fieldDecoration({required String hint}) {
  const border = OutlineInputBorder(
    borderRadius: BorderRadius.all(Radius.circular(14)),
    borderSide: BorderSide(color: Color(0xFFE7D7C6)),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFFB7A89A), fontSize: 14),
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    border: border,
    enabledBorder: border,
    disabledBorder: border,
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.all(Radius.circular(14)),
      borderSide: BorderSide(color: _orange, width: 1.6),
    ),
  );
}
