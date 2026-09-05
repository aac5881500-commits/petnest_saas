// 檔案名稱：lib/features/shop/widgets/booking/booking_step_widgets.dart
// 功能說明：住宿預約三步驟共用：步驟指示、主題卡片、底部固定欄

import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/home_theme_model.dart';

class BookingStepIndicator extends StatelessWidget {
  const BookingStepIndicator({
    super.key,
    required this.currentStep,
    required this.theme,
    this.labels = const <String>['日期與貓咪', '房型與服務', '費用與確認'],
  });

  /// 1 = 日期與貓咪、2 = 房型與服務、3 = 費用與確認
  final int currentStep;
  final HomeThemeModel theme;
  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Row(
        children: List<Widget>.generate(3, (int index) {
          final int step = index + 1;
          final bool completed = step < currentStep;
          final bool active = step == currentStep;
          final Color circleColor = completed || active
              ? theme.primaryColor
              : theme.cardBorderColor;
          final Color textColor = completed || active
              ? theme.textColor
              : theme.textColor.withValues(alpha: 0.45);

          return Expanded(
            child: Column(
              children: <Widget>[
                Row(
                  children: <Widget>[
                    if (index > 0)
                      Expanded(
                        child: Container(
                          height: 1,
                          color: step <= currentStep
                              ? theme.primaryColor.withValues(alpha: 0.45)
                              : theme.cardBorderColor,
                        ),
                      )
                    else
                      const Expanded(child: SizedBox()),
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: completed || active
                            ? circleColor
                            : theme.cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: circleColor),
                      ),
                      child: completed
                          ? const Icon(
                              Icons.check,
                              size: 14,
                              color: Colors.white,
                            )
                          : Text(
                              '$step',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: active ? Colors.white : textColor,
                              ),
                            ),
                    ),
                    if (index < 2)
                      Expanded(
                        child: Container(
                          height: 1,
                          color: currentStep > step
                              ? theme.primaryColor.withValues(alpha: 0.45)
                              : theme.cardBorderColor,
                        ),
                      )
                    else
                      const Expanded(child: SizedBox()),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  labels[index],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                    color: textColor,
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }
}

class BookingThemedCard extends StatelessWidget {
  const BookingThemedCard({
    super.key,
    required this.theme,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin = const EdgeInsets.only(bottom: 12),
  });

  final HomeThemeModel theme;
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.cardBorderColor),
      ),
      child: child,
    );
  }
}

class BookingStickyBar extends StatelessWidget {
  const BookingStickyBar({super.key, required this.theme, required this.child});

  final HomeThemeModel theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: theme.cardColor,
      elevation: 0,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(top: BorderSide(color: theme.cardBorderColor)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class BookingPrimaryButton extends StatelessWidget {
  const BookingPrimaryButton({
    super.key,
    required this.theme,
    required this.label,
    required this.onPressed,
  });

  final HomeThemeModel theme;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          foregroundColor: Colors.white,
          disabledBackgroundColor: theme.cardBorderColor,
          disabledForegroundColor: theme.textColor.withValues(alpha: 0.4),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}
