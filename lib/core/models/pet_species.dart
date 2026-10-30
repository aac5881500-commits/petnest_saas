/// Canonical species shared by profiles and booking eligibility.
class PetSpecies {
  PetSpecies._();
  static String normalize(Object? value) =>
      switch ('$value'.trim().toLowerCase()) {
        'cat' || '貓' || '貓咪' || '貓貓' => 'cat',
        'dog' || '狗' || '狗狗' || '犬' => 'dog',
        _ => '',
      };
  static String of(Map<String, dynamic> pet) {
    final explicit = normalize(pet['species']);
    if (explicit.isNotEmpty) return explicit;
    final type = normalize(pet['type']);
    if (type.isNotEmpty) return type;
    return switch (pet['gender']) {
      '公貓' || '母貓' => 'cat',
      '公狗' || '母狗' => 'dog',
      _ => '',
    };
  }

  static String genderLabel(Object? value) => switch ('$value'.trim()) {
    '公' || '公貓' || '公狗' || 'male' => '公',
    '母' || '母貓' || '母狗' || 'female' => '母',
    _ => '',
  };
  static String label(String species) => switch (species) {
    'cat' => '貓咪',
    'dog' => '狗狗',
    _ => '種類待補齊',
  };
}
