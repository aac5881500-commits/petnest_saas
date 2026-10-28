import 'package:flutter/material.dart';
import 'package:petnest_saas/core/models/pet_service_module.dart';
import 'pet_service_operations_panel.dart';

const _ink = Color(0xff20242c),
    _muted = Color(0xff667085),
    _border = Color(0xffe6eaf0);

class PetServiceMenuTile extends StatelessWidget {
  const PetServiceMenuTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
  final String title, subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .018),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 76),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 8,
              ),
              leading: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  icon,
                  size: 22,
                  color: onTap == null ? _muted : color,
                ),
              ),
              title: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: onTap == null ? _muted : _ink,
                ),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: _muted,
                    height: 1.35,
                  ),
                ),
              ),
              trailing: Icon(
                onTap == null ? Icons.lock_outline : Icons.chevron_right,
                size: 19,
                color: _muted,
              ),
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }
}

class PetServiceSection extends StatelessWidget {
  const PetServiceSection({
    super.key,
    required this.title,
    required this.child,
  });
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: _border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .025),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 17,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const Divider(height: 1, color: _border),
        const SizedBox(height: 12),
        child,
      ],
    ),
  );
}

class _TileGrid extends StatelessWidget {
  const _TileGrid({required this.children, this.columns = 2});
  final List<Widget> children;
  final int columns;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final count = box.maxWidth >= (columns == 3 ? 870 : 590) ? columns : 1;
      final width = (box.maxWidth - 12 * (count - 1)) / count;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final child in children) SizedBox(width: width, child: child),
        ],
      );
    },
  );
}

/// Card-group layout matching the existing cat-hotel dashboard, with its own actions.
class PetServiceOverview extends StatelessWidget {
  const PetServiceOverview({
    super.key,
    required this.module,
    required this.config,
    required this.rows,
    required this.canConfigure,
    required this.canManage,
    required this.onOpenRequests,
    required this.onOpenCatalogue,
    required this.onOpenStaff,
    required this.onOpenSettings,
    required this.onOpenIntake,
    required this.onOpenWorkflow,
    required this.onOpenRecord,
    required this.onFilter,
    required this.onOpenRequest,
    this.loading = false,
    this.failed = false,
  });
  final PetServiceModule module;
  final PetServiceConfig config;
  final List<Map<String, dynamic>> rows;
  final bool canConfigure, canManage, loading, failed;
  final VoidCallback onOpenRequests,
      onOpenCatalogue,
      onOpenStaff,
      onOpenSettings,
      onOpenIntake,
      onOpenWorkflow,
      onOpenRecord;
  final ValueChanged<String> onFilter;
  final ValueChanged<Map<String, dynamic>> onOpenRequest;
  @override
  Widget build(BuildContext context) {
    final pending = rows.where((e) => e['status'] == 'pending').length;
    final active = rows.where((e) => e['status'] == 'arrived').length;
    final count = loading || failed ? '讀取中' : '待確認 $pending 筆・服務中 $active 筆';
    final title = module.isDog
        ? '住宿與安親設定'
        : module.isHospital
        ? '門診與醫師設定'
        : '美容服務與排班';
    final setup = PetServiceSection(
      key: const ValueKey('service-settings-section'),
      title: title,
      child: _TileGrid(
        children: [
          PetServiceMenuTile(
            key: const ValueKey('service-menu-catalogue'),
            title: module.catalogueTitle,
            subtitle: module.isDog
                ? '設定住宿、安親、適應評估與接待量'
                : module.isHospital
                ? '設定門診科別、參考費用與服務項目'
                : '設定洗澡、造型、護理與服務價目',
            icon: Icons.view_quilt_outlined,
            onTap: onOpenCatalogue,
          ),
          PetServiceMenuTile(
            key: const ValueKey('service-menu-staff'),
            title: module.staffTitle,
            subtitle: '設定服務範圍、每週班表與可受理時間',
            icon: Icons.badge_outlined,
            onTap: onOpenStaff,
          ),
          PetServiceMenuTile(
            key: const ValueKey('service-menu-settings'),
            title: '預約開放與須知',
            subtitle: '設定預約開關、營業日、時段與服務須知',
            icon: Icons.event_available_outlined,
            onTap: canConfigure ? onOpenSettings : null,
          ),
          PetServiceMenuTile(
            title: '服務前資料',
            subtitle: module.isDog
                ? '查看入住前的體型、疫苗與照護資料'
                : module.isHospital
                ? '查看就診原因、病史與用藥填寫項目'
                : '查看品種、毛況、造型與接送填寫項目',
            icon: Icons.fact_check_outlined,
            onTap: onOpenIntake,
          ),
        ],
      ),
    );
    final rules = PetServiceSection(
      key: const ValueKey('service-records-section'),
      title: '規則與紀錄',
      child: Column(
        children: [
          if (canManage)
            PetServiceMenuTile(
              key: const ValueKey('service-menu-records'),
              title: module.recordTitle,
              subtitle: '從預約明細新增評估、服務與交接紀錄',
              icon: Icons.assignment_outlined,
              onTap: onOpenRecord,
            ),
          if (canManage) const SizedBox(height: 12),
          PetServiceMenuTile(
            title: '受理流程與須知',
            subtitle: '查看受理步驟、接待提醒與目前服務須知',
            icon: Icons.rule_outlined,
            onTap: onOpenWorkflow,
          ),
        ],
      ),
    );
    final upcoming = canManage
        ? PetServiceSection(
            title: '接下來的工作',
            child: PetServiceOperationsPanel(
              module: module,
              rows: rows,
              onOpen: onOpenRequest,
              onFilter: onFilter,
              loading: loading,
              failed: failed,
              showMetrics: false,
              showHeading: false,
              maxUpcoming: 3,
            ),
          )
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!config.ready) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xffedf2fc),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  '尚未完成服務設定，請先建立項目與實際服務人員。',
                  style: TextStyle(fontSize: 13, color: _muted),
                ),
                TextButton(
                  onPressed: onOpenCatalogue,
                  child: const Text('建立服務項目'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (canManage) ...[
          PetServiceSection(
            key: const ValueKey('service-today-section'),
            title: '今日營運',
            child: _TileGrid(
              columns: 3,
              children: [
                PetServiceMenuTile(
                  key: const ValueKey('service-menu-requests'),
                  title: '預約管理',
                  subtitle: failed ? '讀取失敗，請重試' : count,
                  icon: Icons.event_note_outlined,
                  onTap: onOpenRequests,
                ),
                PetServiceMenuTile(
                  title: module.isDog
                      ? '今日入住與安親'
                      : module.isHospital
                      ? '今日門診排程'
                      : '今日美容排程',
                  subtitle: '查看今天已確認的接待與服務安排',
                  icon: Icons.today_outlined,
                  onTap: () => onFilter('today'),
                ),
                PetServiceMenuTile(
                  title: module.isDog
                      ? '入住／安親中'
                      : module.isHospital
                      ? '門診處理中'
                      : '美容服務中',
                  subtitle: failed || loading
                      ? '尚未取得最新數量'
                      : '目前 $active 筆・查看處理中的預約',
                  icon: Icons.timelapse,
                  onTap: () => onFilter('arrived'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
        ],
        LayoutBuilder(
          builder: (context, box) {
            if (box.maxWidth < 940) {
              return Column(
                children: [
                  setup,
                  const SizedBox(height: 18),
                  rules,
                  if (upcoming != null) ...[
                    const SizedBox(height: 18),
                    upcoming,
                  ],
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      setup,
                      if (upcoming != null) ...[
                        const SizedBox(height: 18),
                        upcoming,
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 18),
                Expanded(child: rules),
              ],
            );
          },
        ),
      ],
    );
  }
}
