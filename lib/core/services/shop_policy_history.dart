// 檔案名稱：lib/core/services/shop_policy_history.dart
// 功能說明：住宿／安親歷史條款讀取計畫；安親不可直接用住宿 v{n}

import 'package:petnest_saas/core/models/policy_applicable_service.dart';

class PolicyHistoryReadStep {
  const PolicyHistoryReadStep({
    required this.collectionId,
    required this.documentId,
    required this.requireExplicitDaycare,
  });

  /// policy_versions 或 daycare_policy_versions
  final String collectionId;
  final String documentId;
  final bool requireExplicitDaycare;
}

class ShopPolicyHistory {
  ShopPolicyHistory._();

  static const String policyVersions = 'policy_versions';
  static const String daycarePolicyVersions = 'daycare_policy_versions';
  static const String unknownService = 'unknown';

  static String documentId({
    required String serviceType,
    required int version,
  }) {
    if (version <= 0) {
      return '';
    }
    if (serviceType == PolicyApplicableService.daycare) {
      return 'daycare_v$version';
    }
    return 'v$version';
  }

  static String notFoundMessage(String serviceType) {
    if (serviceType == PolicyApplicableService.daycare) {
      return '找不到此安親訂單當時同意的條款版本';
    }
    return '找不到此住宿訂單當時同意的條款版本';
  }

  static bool isExplicitDaycarePolicy(Map<String, dynamic> data) {
    bool isDaycare(dynamic raw) =>
        raw != null && raw.toString().trim() == PolicyApplicableService.daycare;
    if (isDaycare(data['serviceType']) ||
        isDaycare(data['policyServiceType']) ||
        isDaycare(data['termsType'])) {
      return true;
    }
    final dynamic applicable = data['applicableServices'];
    if (applicable is List) {
      return applicable.any(
        (dynamic item) =>
            item.toString().trim() == PolicyApplicableService.daycare,
      );
    }
    return false;
  }

  static bool isExplicitStayPolicy(Map<String, dynamic> data) {
    bool isStay(dynamic raw) =>
        raw != null &&
        raw.toString().trim() == PolicyApplicableService.accommodation;
    return isStay(data['serviceType']) ||
        isStay(data['policyServiceType']) ||
        isStay(data['termsType']);
  }

  /// 住宿只讀 policy_versions/v{n}。
  /// 安親依序：daycare_v{n} → daycare_policy_versions/v{n} →
  /// 僅當文件明確標示 daycare 才可讀 policy_versions/v{n}。
  static List<PolicyHistoryReadStep> readPlan({
    required String serviceType,
    required int version,
    String preferredDocumentId = '',
  }) {
    if (version <= 0) {
      return const <PolicyHistoryReadStep>[];
    }
    if (serviceType == PolicyApplicableService.accommodation) {
      return <PolicyHistoryReadStep>[
        PolicyHistoryReadStep(
          collectionId: policyVersions,
          documentId: 'v$version',
          requireExplicitDaycare: false,
        ),
      ];
    }
    if (serviceType != PolicyApplicableService.daycare) {
      return const <PolicyHistoryReadStep>[];
    }
    final String preferred = preferredDocumentId.trim();
    final String daycareId = preferred.startsWith('daycare_v')
        ? preferred
        : 'daycare_v$version';
    return <PolicyHistoryReadStep>[
      PolicyHistoryReadStep(
        collectionId: policyVersions,
        documentId: daycareId,
        requireExplicitDaycare: false,
      ),
      PolicyHistoryReadStep(
        collectionId: daycarePolicyVersions,
        documentId: 'v$version',
        requireExplicitDaycare: false,
      ),
      PolicyHistoryReadStep(
        collectionId: policyVersions,
        documentId: 'v$version',
        requireExplicitDaycare: true,
      ),
    ];
  }

  static bool accepts({
    required PolicyHistoryReadStep step,
    required Map<String, dynamic> data,
  }) {
    if (step.requireExplicitDaycare) {
      return isExplicitDaycarePolicy(data);
    }
    return true;
  }

  static String page1Heading(String serviceType) {
    return serviceType == PolicyApplicableService.daycare
        ? '安親須知（前台第 1 頁）'
        : '入住須知（前台第 1 頁）';
  }

  static String page2Heading(String serviceType) {
    return serviceType == PolicyApplicableService.daycare
        ? '安親取消／退款與注意事項（前台第 2 頁）'
        : '訂房與退款（前台第 2 頁）';
  }

  static String sectionLabel(String key, String serviceType) {
    final bool daycare = serviceType == PolicyApplicableService.daycare;
    switch (key) {
      case 'checkinTime':
        return '營業時間與環境參觀時間';
      case 'checkOutFlow':
        return daycare ? '送達與接回安排' : '入住與退房安排';
      case 'basicCondition':
        return daycare ? '貓咪基本條件' : '貓咪入住基本條件';
      case 'ownerNotice':
        return daycare ? '飼主應告知資訊' : '貓咪入住前飼主應告知資訊';
      case 'checkinNotice':
        return daycare ? '安親須知' : '貓咪入住須知';
      case 'facility':
        return '本店提供的基本設施';
      case 'specialCase':
        return '特殊情況處理';
      case 'activity':
        return '探索活動安排';
      case 'extraNotice':
        return '額外注意事項';
      case 'cancelPolicy':
        return daycare ? '安親取消政策' : '訂房取消政策';
      default:
        return key;
    }
  }

  static const List<String> page1Keys = <String>[
    'checkinTime',
    'checkOutFlow',
    'basicCondition',
    'ownerNotice',
    'checkinNotice',
    'facility',
    'specialCase',
    'activity',
    'extraNotice',
  ];

  static const List<String> page2Keys = <String>['cancelPolicy'];

  static Map<String, dynamic>? pickFromStore({
    required List<PolicyHistoryReadStep> plan,
    required Map<String, Map<String, dynamic>> store,
  }) {
    for (final PolicyHistoryReadStep step in plan) {
      final Map<String, dynamic>? data =
          store['${step.collectionId}/${step.documentId}'];
      if (data == null) {
        continue;
      }
      if (!accepts(step: step, data: data)) {
        continue;
      }
      return data;
    }
    return null;
  }

  static int parseVersion(dynamic raw) {
    if (raw is num) {
      return raw.toInt();
    }
    final Match? match = RegExp(r'(\d+)').firstMatch(raw?.toString() ?? '');
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }
}
