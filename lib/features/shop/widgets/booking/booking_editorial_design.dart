import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';
import 'booking_appearance_scope.dart';

class BookingEditorial {
  static const paper = Color(0xFFFAF7F1),
      green = Color(0xFF204528),
      olive = Color(0xFFE9EACF),
      line = Color(0xFFD3D0C7);
  static const serif = 'NotoSerifTC';
  static HomeThemeModel theme(BuildContext context) =>
      BookingAppearanceScope.of(context).applyLook(
        BookingAppearanceScope.of(context).style == 'cream'
            ? const HomeThemeModel(
                backgroundColorValue: 0xFFFFFEFB,
                cardColorValue: 0xFFFFFFFF,
                cardBorderColorValue: 0xFFB9DFF7,
                primaryColorValue: 0xFF429ADA,
                textColorValue: 0xFF60402D,
              )
            : const HomeThemeModel(
                backgroundColorValue: 0xFFFAF7F1,
                cardColorValue: 0xFFFAF7F1,
                cardBorderColorValue: 0xFFD3D0C7,
                primaryColorValue: 0xFF204528,
                textColorValue: 0xFF204528,
              ),
        frontendTheme: BookingAppearanceScope.frontendOf(context),
      );
  static Color tint(BuildContext context) {
    final a = BookingAppearanceScope.of(context);
    return a.suiteColorMode == 'template'
        ? a.style == 'cream'
              ? const Color(0xFFFFF5D6)
              : olive
        : Color.alphaBlend(
            theme(context).primaryColor.withValues(alpha: .12),
            theme(context).backgroundColor,
          );
  }

  static TextStyle title([
    double size = 24,
    BuildContext? context,
  ]) => TextStyle(
    fontFamily:
        context == null || BookingAppearanceScope.of(context).look.font.isEmpty
        ? context != null && BookingAppearanceScope.of(context).style == 'cream'
              ? 'jfOpenHuninn'
              : serif
        : BookingAppearanceScope.of(context).look.font,
    color: context == null ? green : theme(context).textColor,
    fontSize: size,
    fontWeight:
        context == null ||
            BookingAppearanceScope.of(context).look.fontWeight == null
        ? FontWeight.w800
        : FontWeight.values[(BookingAppearanceScope.of(
                    context,
                  ).look.fontWeight! ~/
                  100) -
              1],
    height: 1.4,
  );
  static TextStyle body([double size = 15, BuildContext? context]) =>
      title(size, context).copyWith(
        fontWeight:
            context == null ||
                BookingAppearanceScope.of(context).look.fontWeight == null
            ? FontWeight.w500
            : FontWeight.values[(BookingAppearanceScope.of(
                        context,
                      ).look.fontWeight! ~/
                      100) -
                  1],
        height: 1.55,
      );
  static Widget brand({String shopName = '貓咪旅館'}) => LayoutBuilder(
    builder: (context, c) => BookingAppearanceScope.of(context).style == 'cream'
        ? Text(
            shopName,
            style: title(20, context),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          )
        : Row(
            children: [
              Text('我要預約', style: title(17, context)),
              const SizedBox(width: 12),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    shopName,
                    style: title(18, context),
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ),
  );
  static Widget heading(
    String text, {
    String? subtitle,
    String? trailing,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: LayoutBuilder(
      builder: (context, c) =>
          BookingAppearanceScope.of(context).style == 'cream'
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: theme(context).primaryColor.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Icon(
                        Icons.pets_outlined,
                        color: theme(context).primaryColor,
                        size: 23,
                      ),
                      Text(text, style: title(22, context)),
                      if (trailing != null)
                        Text(trailing, style: body(13, context)),
                    ],
                  ),
                ),
                if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, left: 4),
                    child: Text(subtitle, style: body(13, context)),
                  ),
              ],
            )
          : Wrap(
              spacing: 12,
              runSpacing: 7,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '／',
                      style: body(
                        28,
                        context,
                      ).copyWith(fontWeight: FontWeight.w300),
                    ),
                    const SizedBox(width: 4),
                    Flexible(child: Text(text, style: title(24, context))),
                  ],
                ),
                if (trailing != null) Text(trailing, style: body(14, context)),
                if (subtitle != null)
                  SizedBox(
                    width: c.maxWidth < 340
                        ? c.maxWidth
                        : math.max(100.0, c.maxWidth - 220),
                    child: Text(subtitle, style: body(13, context)),
                  ),
              ],
            ),
    ),
  );
  static Widget trip(String text) => Builder(
    builder: (context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: tint(context),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.calendar_month_outlined,
            color: theme(context).primaryColor,
            size: 20,
          ),
          const SizedBox(width: 8),
          Flexible(child: Text(text, style: title(15, context))),
        ],
      ),
    ),
  );
  static Widget button(String label, VoidCallback? onPressed) => Builder(
    builder: (context) => SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme(context).primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: theme(context).cardBorderColor,
          minimumSize: const Size.fromHeight(48),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(
              BookingAppearanceScope.of(context).style == 'cream' ? 28 : 13,
            ),
          ),
        ),
        child: Wrap(
          spacing: 14,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: WrapAlignment.center,
          children: [
            Text(
              label,
              style: title(19, context).copyWith(color: Colors.white),
            ),
            const Icon(Icons.arrow_forward, size: 22),
          ],
        ),
      ),
    ),
  );
}

class BookingEditorialProgress extends StatelessWidget {
  const BookingEditorialProgress({super.key, required this.step});
  final int step;
  @override
  Widget build(BuildContext context) {
    final t = BookingEditorial.theme(context);
    if (BookingAppearanceScope.of(context).style == 'cream') {
      return BookingCreamProgress(step: step);
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 1; i <= 3; i++)
            Expanded(
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: i == 1
                            ? const SizedBox()
                            : Divider(color: t.primaryColor),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: step == i ? t.primaryColor : t.backgroundColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: t.primaryColor),
                        ),
                        child: step > i
                            ? Icon(Icons.check, size: 19, color: t.primaryColor)
                            : Text(
                                '$i',
                                style: BookingEditorial.title(17, context)
                                    .copyWith(
                                      color: step == i
                                          ? Colors.white
                                          : t.primaryColor,
                                    ),
                              ),
                      ),
                      Expanded(
                        child: i == 3
                            ? const SizedBox()
                            : Divider(color: t.primaryColor),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    const ['日期與貓咪', '房型與服務', '費用確認'][i - 1],
                    textAlign: TextAlign.center,
                    style: BookingEditorial.body(13, context).copyWith(
                      fontWeight: step == i ? FontWeight.w800 : FontWeight.w500,
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

class BookingEditorialFooter extends StatelessWidget {
  const BookingEditorialFooter({
    super.key,
    required this.left,
    required this.right,
    required this.onNext,
    this.hint,
    this.label = '下一步',
    this.step,
  });
  final String left, right, label;
  final int? step;
  final String? hint;
  final VoidCallback? onNext;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 18,
        runSpacing: 5,
        children: [
          Text(left, style: BookingEditorial.title(15, context)),
          Text(right, style: BookingEditorial.title(21, context)),
        ],
      ),
      if (hint != null)
        Padding(
          padding: const EdgeInsets.only(top: 5),
          child: Text(hint!, style: BookingEditorial.body(12, context)),
        ),
      if (BookingAppearanceScope.of(context).style == 'cream')
        BookingCreamProgress(step: step ?? (left.startsWith('已選') ? 1 : 2)),
      const SizedBox(height: 10),
      BookingEditorial.button(label, onNext),
    ],
  );
}

class BookingEditorialReminder extends StatelessWidget {
  const BookingEditorialReminder({
    super.key,
    required this.title,
    this.note = '',
  });
  final String title, note;
  @override
  Widget build(BuildContext context) {
    final t = BookingEditorial.theme(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: t.cardBorderColor, height: 24),
        BookingEditorial.heading(title),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.info_outline, color: t.primaryColor, size: 23),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('訂房安全提醒', style: BookingEditorial.title(18, context)),
                  const SizedBox(height: 6),
                  Text(
                    '本平台提供預約系統服務，實際住宿與照護內容由店家負責。',
                    style: BookingEditorial.body(14, context),
                  ),
                  if (note.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        note,
                        style: BookingEditorial.body(14, context),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        Divider(color: t.cardBorderColor, height: 28),
        Text('入住前請確認', style: BookingEditorial.title(18, context)),
        const SizedBox(height: 12),
        for (final text in ['確認住宿日期與入住貓咪', '如有飲食或照護需求，請提前告知店家'])
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_box_outlined, color: t.primaryColor, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(text, style: BookingEditorial.body(14, context)),
                ),
              ],
            ),
          ),
        Divider(color: t.cardBorderColor, height: 24),
        Text(
          '下一步將選擇房型與加購服務。',
          style: BookingEditorial.body(13, context),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class BookingCreamProgress extends StatelessWidget {
  const BookingCreamProgress({super.key, required this.step});
  final int step;
  @override
  Widget build(BuildContext context) {
    final t = BookingEditorial.theme(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Text(
            '$step/3',
            style: BookingEditorial.title(
              14,
              context,
            ).copyWith(color: t.primaryColor),
          ),
          const SizedBox(width: 12),
          for (var i = 1; i <= 3; i++)
            Expanded(
              child: Container(
                height: 5,
                margin: const EdgeInsets.only(right: 5),
                decoration: BoxDecoration(
                  color: i <= step
                      ? t.primaryColor
                      : t.cardBorderColor.withValues(alpha: .4),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
