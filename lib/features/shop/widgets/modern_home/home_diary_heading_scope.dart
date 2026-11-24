import 'package:flutter/widgets.dart';

/// Lets existing sections defer their headings to an editable diary chapter.
class HomeDiaryHeadingScope extends InheritedWidget {
  const HomeDiaryHeadingScope({super.key, required super.child});
  static bool hidesHeading(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeDiaryHeadingScope>() !=
      null;
  @override
  bool updateShouldNotify(HomeDiaryHeadingScope oldWidget) => false;
}
