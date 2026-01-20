class Province {
  final int id;
  final String name;
  final String abbreviation;

  const Province({
    required this.id,
    required this.name,
    required this.abbreviation,
  });
}

class ArgentinaProvinces {
  static const List<Province> all = [
    Province(id: 1, name: 'Buenos Aires', abbreviation: 'BA'),
    Province(id: 2, name: 'Ciudad Autónoma de Buenos Aires', abbreviation: 'CABA'),
    Province(id: 3, name: 'Catamarca', abbreviation: 'CT'),
    Province(id: 4, name: 'Chaco', abbreviation: 'CC'),
    Province(id: 5, name: 'Chubut', abbreviation: 'CH'),
    Province(id: 6, name: 'Córdoba', abbreviation: 'CB'),
    Province(id: 7, name: 'Corrientes', abbreviation: 'CR'),
    Province(id: 8, name: 'Entre Ríos', abbreviation: 'ER'),
    Province(id: 9, name: 'Formosa', abbreviation: 'FO'),
    Province(id: 10, name: 'Jujuy', abbreviation: 'JY'),
    Province(id: 11, name: 'La Pampa', abbreviation: 'LP'),
    Province(id: 12, name: 'La Rioja', abbreviation: 'LR'),
    Province(id: 13, name: 'Mendoza', abbreviation: 'MZ'),
    Province(id: 14, name: 'Misiones', abbreviation: 'MI'),
    Province(id: 15, name: 'Neuquén', abbreviation: 'NQ'),
    Province(id: 16, name: 'Río Negro', abbreviation: 'RN'),
    Province(id: 17, name: 'Salta', abbreviation: 'SA'),
    Province(id: 18, name: 'San Juan', abbreviation: 'SJ'),
    Province(id: 19, name: 'San Luis', abbreviation: 'SL'),
    Province(id: 20, name: 'Santa Cruz', abbreviation: 'SC'),
    Province(id: 21, name: 'Santa Fe', abbreviation: 'SF'),
    Province(id: 22, name: 'Santiago del Estero', abbreviation: 'SE'),
    Province(id: 23, name: 'Tierra del Fuego', abbreviation: 'TF'),
    Province(id: 24, name: 'Tucumán', abbreviation: 'TU'),
  ];

  static Province getById(int id) {
    return all.firstWhere(
      (p) => p.id == id,
      orElse: () => all.first,
    );
  }

  static Province? getByName(String name) {
    try {
      return all.firstWhere(
        (p) => p.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }
}
