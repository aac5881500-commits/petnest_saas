// 檔案名稱：lib/core/models/pet_snapshot.dart
// 功能說明：住宿／安親／後台共用的寵物快照欄位映射，避免 breed 與 type 混用。

class PetSnapshot {
  PetSnapshot._();

  static const List<String> knownKeys = <String>[
    'petId',
    'name',
    'photoUrl',
    'imageUrl',
    'species',
    'type',
    'breed',
    'gender',
    'age',
    'birthday',
    'weight',
    'isNeutered',
    'canSocial',
    'canMedicate',
    'medicalStatus',
    'vaccine',
    'vaccineStatus',
    'chipNumber',
    'litterType',
    'feedingInstructions',
    'medication',
    'allergy',
    'personality',
    'dislikes',
    'emergencyBehavior',
    'note',
    'adminNote',
    'staffNote',
  ];

  static Map<String, dynamic> fromPet(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) {
      return <String, dynamic>{};
    }
    final Map<String, dynamic> pet = Map<String, dynamic>.from(raw);
    final String petId = (pet['petId'] ?? pet['id'] ?? '').toString().trim();
    final String species = _firstNonEmpty(<dynamic>[
      pet['species'],
      pet['type'] == pet['breed'] ? null : pet['type'],
    ]);
    final String type = _firstNonEmpty(<dynamic>[pet['type'], species]);
    final String breed = (pet['breed'] ?? '').toString().trim();
    final Map<String, dynamic> out = <String, dynamic>{
      'petId': petId,
      'name': (pet['name'] ?? '').toString(),
      'photoUrl': (pet['photoUrl'] ?? pet['imageUrl'] ?? '').toString(),
      'imageUrl': (pet['imageUrl'] ?? pet['photoUrl'] ?? '').toString(),
      'species': species,
      'type': type,
      'breed': breed,
      'gender': (pet['gender'] ?? '').toString(),
      'age': (pet['age'] ?? '').toString(),
      'birthday': _jsonScalar(pet['birthday'])?.toString() ?? '',
      'weight': _jsonScalar(pet['weight']),
      'isNeutered': pet.containsKey('isNeutered')
          ? _jsonScalar(pet['isNeutered'])
          : null,
      'canSocial': _jsonScalar(pet['canSocial']),
      'canMedicate': _jsonScalar(pet['canMedicate']),
      'medicalStatus': (pet['medicalStatus'] ?? '').toString(),
      'vaccine': (pet['vaccine'] ?? '').toString(),
      'vaccineStatus': (pet['vaccineStatus'] ?? '').toString(),
      'chipNumber':
          (pet['chipNumber'] ??
                  pet['chip'] ??
                  pet['microchip'] ??
                  pet['chipId'] ??
                  '')
              .toString(),
      'litterType': (pet['litterType'] ?? '').toString(),
      'feedingInstructions': (pet['feedingInstructions'] ?? '').toString(),
      'medication': (pet['medication'] ?? '').toString(),
      'allergy': (pet['allergy'] ?? '').toString(),
      'personality': (pet['personality'] ?? '').toString(),
      'dislikes': (pet['dislikes'] ?? '').toString(),
      'emergencyBehavior': (pet['emergencyBehavior'] ?? '').toString(),
      'note': (pet['note'] ?? '').toString(),
      'adminNote': (pet['adminNote'] ?? '').toString(),
      'staffNote': (pet['staffNote'] ?? pet['adminNote'] ?? '').toString(),
    };
    return out;
  }

  /// 訂單快照優先；缺欄位才用店家會員寵物補上，不覆蓋已有值。
  static Map<String, dynamic> merge({
    required Map<String, dynamic> snapshot,
    Map<String, dynamic>? fallback,
  }) {
    final Map<String, dynamic> base = fromPet(fallback);
    final Map<String, dynamic> primary = fromPet(snapshot);
    final Map<String, dynamic> merged = Map<String, dynamic>.from(base);
    primary.forEach((String key, dynamic value) {
      if (!_isBlank(value)) {
        merged[key] = value;
      }
    });
    if (snapshot.containsKey('isNeutered')) {
      merged['isNeutered'] = snapshot['isNeutered'];
    } else if (fallback != null && fallback.containsKey('isNeutered')) {
      merged['isNeutered'] = fallback['isNeutered'];
    }
    for (final String key in <String>[
      'shopFormAnswers',
      'customFormAnswersByShop',
    ]) {
      if (snapshot[key] != null) {
        merged[key] = snapshot[key];
      } else if (fallback != null && fallback[key] != null) {
        merged[key] = fallback[key];
      }
    }
    return merged;
  }

  static bool isNeuteredFalse(Map<String, dynamic> pet) {
    final dynamic raw = pet['isNeutered'];
    return raw == false || raw == 'false' || raw == 0;
  }

  static String speciesLabel(Map<String, dynamic> pet) {
    return _firstNonEmpty(<dynamic>[pet['species'], pet['type']]);
  }

  static String breedLabel(Map<String, dynamic> pet) {
    return (pet['breed'] ?? '').toString().trim();
  }

  static List<MapEntry<String, String>> visibleRows(Map<String, dynamic> pet) {
    final List<MapEntry<String, String>> rows = <MapEntry<String, String>>[];
    void add(String label, dynamic value) {
      final String text = value == null ? '' : value.toString().trim();
      if (text.isEmpty || text == 'null') {
        return;
      }
      rows.add(MapEntry<String, String>(label, text));
    }

    add('種類', speciesLabel(pet));
    add('品種', breedLabel(pet));
    add('性別', pet['gender']);
    add('年齡', pet['age']);
    add('生日', pet['birthday']);
    if (pet.containsKey('isNeutered') && pet['isNeutered'] != null) {
      final bool flag = pet['isNeutered'] == true;
      rows.add(MapEntry<String, String>('結紮', flag ? '已結紮' : '未結紮'));
    }
    add('晶片', pet['chipNumber']);
    add('貓砂', pet['litterType']);
    add('體重', pet['weight']);
    add('個性', pet['personality']);
    add('備註', pet['note']);
    return rows;
  }

  static List<MapEntry<String, String>> safetyRows(Map<String, dynamic> pet) {
    final List<MapEntry<String, String>> rows = <MapEntry<String, String>>[];
    void add(String label, dynamic value) {
      final String text = value == null ? '' : value.toString().trim();
      if (text.isEmpty || text == 'null') {
        return;
      }
      rows.add(MapEntry<String, String>(label, text));
    }

    add('過敏', pet['allergy']);
    add('疾病／醫療', pet['medicalStatus']);
    add('藥物', pet['medication']);
    add('緊張或攻擊行為', pet['emergencyBehavior']);
    add('不喜歡', pet['dislikes']);
    return rows;
  }

  /// 卡片紅色標籤：僅在有疾病／醫療／需特別注意的安全資訊時顯示。
  static bool hasDiseaseAlert(Map<String, dynamic> pet) {
    return _firstNonEmpty(<dynamic>[
      pet['medicalStatus'],
      pet['allergy'],
      pet['medication'],
      pet['emergencyBehavior'],
    ]).isNotEmpty;
  }

  static String _firstNonEmpty(List<dynamic> values) {
    for (final dynamic value in values) {
      final String text = value == null ? '' : value.toString().trim();
      if (text.isNotEmpty && text != 'null') {
        return text;
      }
    }
    return '';
  }

  static Object? _jsonScalar(Object? value) {
    if (value == null || value is bool || value is num || value is String) {
      return value;
    }
    return value.toString();
  }

  static bool _isBlank(dynamic value) {
    if (value == null) {
      return true;
    }
    if (value is bool || value is num) {
      return false;
    }
    return value.toString().trim().isEmpty || value.toString() == 'null';
  }
}
