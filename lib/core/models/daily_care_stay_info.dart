// lib/core/models/daily_care_stay_info.dart
// 🐾 每日照護日誌用的住宿摘要
// 功能：從既有 booking / shop 快照讀出房間、寵物、住宿日期與店家 Logo。
// 不新增 Firestore 欄位，也不改 booking schema。

import 'package:cloud_firestore/cloud_firestore.dart';

import 'daily_care_date_helper.dart';

class DailyCareStayPet {
  const DailyCareStayPet({required this.name, required this.photoUrl});

  final String name;
  final String photoUrl;

  bool get hasPhoto => photoUrl.trim().isNotEmpty;
}

class DailyCareStayInfo {
  const DailyCareStayInfo({
    required this.roomName,
    required this.pets,
    this.startDate,
    this.endDate,
    this.shopLogoUrl = '',
  });

  final String roomName;
  final List<DailyCareStayPet> pets;
  final DateTime? startDate;
  final DateTime? endDate;
  final String shopLogoUrl;

  factory DailyCareStayInfo.fromBookingMap(
    Map<String, dynamic> data, {
    String fallbackRoomName = '',
    String shopLogoUrl = '',
  }) {
    final String roomName = _firstNonEmpty(<Object?>[
      data['roomName'],
      data['roomNumber'],
      data['roomNo'],
      fallbackRoomName,
    ]);

    List<DailyCareStayPet> pets = _readPets(
      data['pets'] ?? data['petNameSnapshots'] ?? data['petSummaries'],
    );
    if (pets.isEmpty) {
      pets = _readPets(data['petNames']);
    }
    if (pets.isEmpty) {
      final String petName = _firstNonEmpty(<Object?>[data['petName']]);
      if (petName.isNotEmpty) {
        pets = <DailyCareStayPet>[
          DailyCareStayPet(name: petName, photoUrl: ''),
        ];
      }
    }

    return DailyCareStayInfo(
      roomName: roomName,
      pets: pets,
      startDate:
          _readDate(data['startDate']) ??
          _readDate(data['checkInAt']) ??
          _readDate(data['checkInDate']),
      endDate:
          _readDate(data['endDate']) ??
          _readDate(data['checkOutAt']) ??
          _readDate(data['checkOutDate']),
      shopLogoUrl: shopLogoUrl.trim(),
    );
  }

  String get petNamesText {
    if (pets.isEmpty) {
      return '尚未指定寵物';
    }
    return pets.map((DailyCareStayPet pet) => pet.name).join('、');
  }

  String get stayDateText {
    if (startDate == null && endDate == null) {
      return '';
    }
    if (startDate != null && endDate != null) {
      return '${_dateText(startDate!)} ～ ${_dateText(endDate!)}';
    }
    final DateTime only = startDate ?? endDate!;
    return _dateText(only);
  }

  /// 住宿區間顯示仍含退房日；照護日期請用 [careDateKeys]。
  List<String> stayDateKeys() {
    if (startDate == null || endDate == null) {
      return const <String>[];
    }

    final DateTime start = DailyCareDateHelper.dateOnly(startDate!);
    DateTime end = DailyCareDateHelper.dateOnly(endDate!);
    if (end.isBefore(start)) {
      end = start;
    }

    final List<String> keys = <String>[];
    DateTime cursor = start;
    while (!cursor.isAfter(end)) {
      keys.add(DailyCareDateHelper.dateKey(cursor));
      cursor = cursor.add(const Duration(days: 1));
    }
    return keys;
  }

  /// 每日照護有效日期：入住日包含、退房日不包含。
  List<String> careDateKeys() {
    return DailyCareDateHelper.careDateKeys(
      checkIn: startDate,
      checkOut: endDate,
    );
  }

  bool includesCareDate(DateTime date) {
    return DailyCareDateHelper.isCareDate(
      date: date,
      checkIn: startDate,
      checkOut: endDate,
    );
  }

  DateTime currentCareDate({DateTime? now}) {
    return DailyCareDateHelper.resolveCurrentCareDate(
      checkIn: startDate,
      checkOut: endDate,
      now: now,
    );
  }

  static List<DailyCareStayPet> _readPets(Object? rawPets) {
    final List<DailyCareStayPet> pets = <DailyCareStayPet>[];
    if (rawPets is! List) {
      return pets;
    }

    for (final Object? rawPet in rawPets) {
      if (rawPet is String) {
        final String name = rawPet.trim();
        if (name.isNotEmpty) {
          pets.add(DailyCareStayPet(name: name, photoUrl: ''));
        }
        continue;
      }
      if (rawPet is! Map) {
        continue;
      }
      final Map<String, dynamic> pet = Map<String, dynamic>.from(rawPet);
      final String name = _firstNonEmpty(<Object?>[
        pet['name'],
        pet['petName'],
      ]);
      final String photoUrl = _firstNonEmpty(<Object?>[
        pet['photoUrl'],
        pet['imageUrl'],
        pet['image'],
      ]);
      if (name.isEmpty && photoUrl.isEmpty) {
        continue;
      }
      pets.add(
        DailyCareStayPet(name: name.isEmpty ? '毛孩' : name, photoUrl: photoUrl),
      );
    }
    return pets;
  }

  static String _firstNonEmpty(List<Object?> values) {
    for (final Object? value in values) {
      final String text = value?.toString().trim() ?? '';
      if (text.isNotEmpty) {
        return text;
      }
    }
    return '';
  }

  static DateTime? _readDate(Object? value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      return DateTime.tryParse(value);
    }
    return null;
  }

  static String _dateText(DateTime value) {
    return DailyCareDateHelper.dateKey(value);
  }
}
