// 檔案名稱：lib/core/legal_pet/shop_profile_lock.dart
// 功能說明：電話與地址首次設定分開判斷，既有地址不因未認證或電話空白而解鎖。

bool isAddressSetupCompleted(Map<String, dynamic>? shop) {
  if (shop == null) {
    return false;
  }
  if (shop['addressSetupCompleted'] == true) {
    return true;
  }
  return (shop['address'] ?? '').toString().trim().isNotEmpty;
}

bool isPhoneSetupCompleted(Map<String, dynamic>? shop) {
  if (shop == null) {
    return false;
  }
  if (shop['phoneSetupCompleted'] == true) {
    return true;
  }
  return (shop['phone'] ?? '').toString().trim().isNotEmpty;
}

class LegalPetLookupInputs {
  const LegalPetLookupInputs({
    required this.license,
    required this.city,
    required this.district,
    required this.address,
  });

  final String license;
  final String city;
  final String district;
  final String address;

  bool matches(LegalPetLookupInputs other) {
    return license == other.license &&
        city == other.city &&
        district == other.district &&
        address == other.address;
  }
}
