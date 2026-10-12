// 檔案名稱：lib/core/services/legal_pet_service.dart
// 功能說明：呼叫後端查核特寵字號、儲存首次地址，以及平台業者資料庫。

import 'package:cloud_functions/cloud_functions.dart';
import 'package:petnest_saas/core/legal_pet/directory_load_gate.dart';

class LegalPetService {
  LegalPetService._();

  static final instance = LegalPetService._();

  FirebaseFunctions get _functions {
    return FirebaseFunctions.instanceFor(region: 'asia-east1');
  }

  Future<LegalPetLookupResult> lookupLicense({
    required String shopId,
    required String licenseNumber,
    required String city,
    required String district,
    required String address,
  }) async {
    final data = await _call('lookupLegalPetLicense', {
      'shopId': shopId,
      'licenseNumber': licenseNumber,
      'city': city,
      'district': district,
      'address': address,
    });
    return LegalPetLookupResult.fromMap(data);
  }

  Future<void> saveInitialProfile({
    required String shopId,
    String? phone,
    String? city,
    String? district,
    String? address,
  }) async {
    final payload = <String, dynamic>{'shopId': shopId};
    if (phone != null) {
      payload['phone'] = phone;
    }
    if (address != null && address.trim().isNotEmpty) {
      payload['city'] = city ?? '';
      payload['district'] = district ?? '';
      payload['address'] = address;
    }
    await _call('saveShopInitialProfile', payload);
  }

  Future<void> submitCertification(Map<String, dynamic> payload) {
    return _call('submitShopCertification', payload);
  }

  Future<void> reviewRequest(Map<String, dynamic> payload) {
    return _call('reviewShopChangeRequest', payload);
  }

  Future<LegalPetDirectoryPage> listBusinesses({
    String query = '',
    String countyCode = '',
    String district = '',
    String animal = '',
    String bus = '',
    String businessState = '',
    String validity = '',
    String linkStatus = '',
    String contactStatus = '',
    String cursor = '',
  }) async {
    final data = await _call('listLegalPetBusinesses', {
      'query': query,
      'countyCode': countyCode,
      'district': district,
      'animal': animal,
      'bus': bus,
      'businessState': businessState,
      'validity': validity,
      'linkStatus': linkStatus,
      'contactStatus': contactStatus,
      'cursor': cursor,
    });
    return LegalPetDirectoryPage.fromMap(data);
  }

  Future<LegalPetBackfillResult> backfillLicenseLookup({
    String cursor = '',
    String passId = '',
  }) async {
    final data = await _call('backfillLicenseLookupKeys', {
      'cursor': cursor,
      'passId': passId,
    });
    return LegalPetBackfillResult.fromMap(data);
  }

  Future<LegalPetBackfillResult> backfillDirectory({
    String cursor = '',
    String passId = '',
    bool force = false,
  }) async {
    final data = await _call('backfillLegalPetDirectory', {
      'cursor': cursor,
      'passId': passId,
      'force': force,
    });
    return LegalPetBackfillResult.fromMap(data);
  }

  Future<Map<String, dynamic>> getBusiness(String govId) {
    return _call('getLegalPetBusiness', {'govId': govId});
  }

  Future<void> updateContact(Map<String, dynamic> payload) {
    return _call('updateLegalPetContact', payload);
  }

  Future<String> syncNow() async {
    final data = await _call('syncLegalPetBusinesses', {});
    return (data['summary'] ?? '').toString();
  }

  Future<Map<String, dynamic>> _call(
    String name,
    Map<String, dynamic> payload,
  ) async {
    try {
      final result = await _functions.httpsCallable(name).call(payload);
      final data = result.data;
      if (data is Map) {
        return Map<String, dynamic>.from(data);
      }
      return {};
    } on FirebaseFunctionsException catch (error) {
      throw LegalPetException(error.message ?? '操作失敗');
    }
  }
}

class LegalPetException implements Exception {
  LegalPetException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ParsedGovernmentAddress {
  const ParsedGovernmentAddress({
    required this.reliable,
    required this.city,
    required this.district,
    required this.detail,
    required this.raw,
  });

  final bool reliable;
  final String city;
  final String district;
  final String detail;
  final String raw;

  factory ParsedGovernmentAddress.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    return ParsedGovernmentAddress(
      reliable: map['reliable'] == true,
      city: (map['city'] ?? '').toString(),
      district: (map['district'] ?? '').toString(),
      detail: (map['detail'] ?? '').toString(),
      raw: (map['raw'] ?? '').toString(),
    );
  }
}

class LegalPetMatch {
  const LegalPetMatch({
    required this.govId,
    required this.legalname,
    required this.legaladdress,
    required this.validnum,
    required this.validDate,
    required this.busitemLabel,
    required this.animalLabel,
    required this.stateLabel,
    required this.countyLabel,
    required this.addressComparison,
    required this.syncedAt,
    required this.parsedAddress,
    required this.busitemConfirmed,
    required this.stateConfirmed,
    required this.animalConfirmed,
  });

  final String govId;
  final String legalname;
  final String legaladdress;
  final String validnum;
  final String validDate;
  final String busitemLabel;
  final String animalLabel;
  final String stateLabel;
  final String countyLabel;
  final String addressComparison;
  final String syncedAt;
  final ParsedGovernmentAddress parsedAddress;
  final bool busitemConfirmed;
  final bool stateConfirmed;
  final bool animalConfirmed;

  factory LegalPetMatch.fromMap(Map<String, dynamic> data) {
    return LegalPetMatch(
      govId: (data['govId'] ?? '').toString(),
      legalname: (data['legalname'] ?? '').toString(),
      legaladdress: (data['legaladdress'] ?? '').toString(),
      validnum: (data['validnum'] ?? '').toString(),
      validDate: (data['validDate'] ?? data['validdateRaw'] ?? '').toString(),
      busitemLabel: (data['busitemLabel'] ?? '').toString(),
      animalLabel: (data['animalLabel'] ?? '').toString(),
      stateLabel: (data['stateLabel'] ?? '').toString(),
      countyLabel: (data['countyLabel'] ?? '').toString(),
      addressComparison: (data['addressComparison'] ?? '').toString(),
      syncedAt: (data['syncedAt'] ?? '').toString(),
      parsedAddress: ParsedGovernmentAddress.fromMap(
        data['parsedAddress'] is Map
            ? Map<String, dynamic>.from(data['parsedAddress'] as Map)
            : null,
      ),
      busitemConfirmed: data['busitemConfirmed'] == true,
      stateConfirmed: data['stateConfirmed'] == true,
      animalConfirmed: data['animalConfirmed'] == true,
    );
  }
}

class LegalPetLookupResult {
  const LegalPetLookupResult({
    required this.status,
    required this.message,
    required this.syncedAt,
    required this.matches,
  });

  final String status;
  final String message;
  final String syncedAt;
  final List<LegalPetMatch> matches;

  factory LegalPetLookupResult.fromMap(Map<String, dynamic> data) {
    final raw = data['matches'];
    final matches = raw is List
        ? raw
            .whereType<Map>()
            .map((item) => LegalPetMatch.fromMap(Map<String, dynamic>.from(item)))
            .toList()
        : const <LegalPetMatch>[];
    return LegalPetLookupResult(
      status: (data['status'] ?? 'unavailable').toString(),
      message: (data['message'] ?? '').toString(),
      syncedAt: (data['syncedAt'] ?? '').toString(),
      matches: matches,
    );
  }
}

class LegalPetDirectoryItem {
  const LegalPetDirectoryItem({
    required this.govId,
    required this.legalname,
    required this.countyLabel,
    required this.districtLabel,
    required this.districtPending,
    required this.validnum,
    required this.busitemLabel,
    required this.animalLabel,
    required this.linkStatus,
    required this.candidateCount,
    required this.contactStatus,
  });

  final String govId;
  final String legalname;
  final String countyLabel;
  final String districtLabel;
  final bool districtPending;
  final String validnum;
  final String busitemLabel;
  final String animalLabel;
  final String linkStatus;
  final int candidateCount;
  final String contactStatus;

  String get placeLabel {
    final district = districtPending || districtLabel.isEmpty
        ? '區域待確認'
        : districtLabel;
    if (countyLabel.isEmpty) return district;
    return '$countyLabel $district';
  }

  factory LegalPetDirectoryItem.fromMap(Map<String, dynamic> data) {
    return LegalPetDirectoryItem(
      govId: (data['govId'] ?? '').toString(),
      legalname: (data['legalname'] ?? '').toString(),
      countyLabel: (data['countyLabel'] ?? '').toString(),
      districtLabel: (data['districtLabel'] ?? '').toString(),
      districtPending: data['districtPending'] == true,
      validnum: (data['validnum'] ?? '').toString(),
      busitemLabel: (data['busitemLabel'] ?? '').toString(),
      animalLabel: (data['animalLabel'] ?? '').toString(),
      linkStatus: (data['linkStatus'] ?? 'unknown').toString(),
      candidateCount: data['candidateCount'] is num
          ? (data['candidateCount'] as num).toInt()
          : int.tryParse('${data['candidateCount']}') ?? 0,
      contactStatus: (data['contactStatus'] ?? 'unknown').toString(),
    );
  }
}

class LegalPetSyncStatus {
  const LegalPetSyncStatus({
    required this.phase,
    required this.successText,
    required this.directoryReady,
    required this.errorSummary,
    this.checkedText = '',
    this.contentChangedText = '',
    this.sourceUnchanged = false,
  });

  final String phase;
  final String successText;
  final bool directoryReady;
  final String errorSummary;
  final String checkedText;
  final String contentChangedText;
  final bool sourceUnchanged;

  String get headline {
    return directorySyncHeadline(
      phase: phase,
      successText: successText,
      hasItems: false,
    );
  }

  factory LegalPetSyncStatus.fromMap(Map<String, dynamic>? data) {
    final map = data ?? const <String, dynamic>{};
    final rawPhase = map['phase'];
    final phase = rawPhase == null || rawPhase.toString().isEmpty
        ? 'unknown'
        : rawPhase.toString();
    return LegalPetSyncStatus(
      phase: phase,
      successText: (map['successText'] ?? '').toString(),
      directoryReady: map['directoryReady'] == true,
      errorSummary: (map['errorSummary'] ?? '').toString(),
      checkedText: (map['checkedText'] ?? '').toString(),
      contentChangedText: (map['contentChangedText'] ?? '').toString(),
      sourceUnchanged: map['sourceUnchanged'] == true,
    );
  }
}

class LegalPetBackfillResult {
  const LegalPetBackfillResult({
    required this.updated,
    required this.skipped,
    required this.nextCursor,
    required this.done,
    required this.ready,
    required this.passId,
    required this.directoryApiVersion,
  });

  final int updated;
  final int skipped;
  final String nextCursor;
  final bool done;
  final bool ready;
  final String passId;
  final int directoryApiVersion;

  factory LegalPetBackfillResult.fromMap(Map<String, dynamic> data) {
    int number(dynamic value) {
      if (value is num) return value.toInt();
      return int.tryParse('$value') ?? 0;
    }

    return LegalPetBackfillResult(
      updated: number(data['updated']),
      skipped: number(data['skipped']),
      nextCursor: (data['nextCursor'] ?? '').toString(),
      done: data['done'] == true,
      ready: data['ready'] == true,
      passId: (data['passId'] ?? '').toString(),
      directoryApiVersion: number(data['directoryApiVersion']),
    );
  }
}

class LegalPetDirectoryPage {
  const LegalPetDirectoryPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.needsBackfill,
    required this.outcome,
    required this.sync,
    required this.counties,
    required this.districts,
    required this.directoryApiVersion,
    this.candidateReads = 0,
  });

  final List<LegalPetDirectoryItem> items;
  final String nextCursor;
  final bool hasMore;
  final bool needsBackfill;
  final String outcome;
  final LegalPetSyncStatus sync;
  final Map<String, String> counties;
  final Map<String, List<String>> districts;
  final int directoryApiVersion;
  final int candidateReads;

  factory LegalPetDirectoryPage.fromMap(Map<String, dynamic> data) {
    final rawItems = data['items'];
    final rawCounties = data['counties'];
    final rawDistricts = data['districts'];
    final sync = data['sync'] is Map
        ? Map<String, dynamic>.from(data['sync'] as Map)
        : const <String, dynamic>{};
    return LegalPetDirectoryPage(
      items: rawItems is List
          ? rawItems
              .whereType<Map>()
              .map(
                (item) => LegalPetDirectoryItem.fromMap(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList()
          : const <LegalPetDirectoryItem>[],
      nextCursor: (data['nextCursor'] ?? '').toString(),
      hasMore: data['hasMore'] == true,
      needsBackfill: data['needsBackfill'] == true,
      outcome: (data['outcome'] ?? '').toString(),
      sync: LegalPetSyncStatus.fromMap(sync),
      counties: rawCounties is Map
          ? rawCounties.map(
              (key, value) => MapEntry(key.toString(), value.toString()),
            )
          : const <String, String>{},
      districts: _districtMap(rawDistricts),
      directoryApiVersion: data['directoryApiVersion'] is num
          ? (data['directoryApiVersion'] as num).toInt()
          : int.tryParse('${data['directoryApiVersion']}') ?? 0,
      candidateReads: data['candidateReads'] is num
          ? (data['candidateReads'] as num).toInt()
          : int.tryParse('${data['candidateReads']}') ?? 0,
    );
  }

  static Map<String, List<String>> _districtMap(dynamic raw) {
    if (raw is! Map) return const {};
    return raw.map((key, value) {
      final items = value is List
          ? value.map((item) => item.toString()).toList()
          : const <String>[];
      return MapEntry(key.toString(), items);
    });
  }
}
