import 'package:flutter/material.dart';

import 'medication_task_page.dart';

typedef CareReportTarget = ({
  String shopId,
  String bookingId,
  String? taskKey,
  bool canManage,
});

class CareReportWorkspace extends InheritedWidget {
  const CareReportWorkspace({
    super.key,
    required this.open,
    required super.child,
  });

  final ValueChanged<CareReportTarget> open;

  @override
  bool updateShouldNotify(CareReportWorkspace oldWidget) =>
      open != oldWidget.open;
}

void openCareReportResult(
  BuildContext context, {
  required String shopId,
  required String bookingId,
  required String taskId,
  required bool medication,
  bool canManage = true,
}) {
  final target = (
    shopId: shopId,
    bookingId: bookingId,
    taskKey: '${medication ? 'medication' : 'service'}:$taskId',
    canManage: canManage,
  );
  _openOrderReportPage(context, target);
}

Future<void> _openOrderReportPage(
  BuildContext context,
  CareReportTarget target,
) async {
  final workspace = context
      .getInheritedWidgetOfExactType<CareReportWorkspace>();
  if (workspace != null) {
    workspace.open(target);
    return;
  }
  await Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => CareReportResultPage(target: target)),
  );
}

class CareReportResultPage extends StatelessWidget {
  const CareReportResultPage({super.key, required this.target, this.onBack});

  final CareReportTarget target;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('訂單照護待辦'),
      leading: onBack == null ? null : BackButton(onPressed: onBack),
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1440),
        child: MedicationTaskPage.orderRecords(
          shopId: target.shopId,
          bookingId: target.bookingId,
          taskId: target.taskKey,
          canManage: target.canManage,
          embedded: true,
        ),
      ),
    ),
  );
}
