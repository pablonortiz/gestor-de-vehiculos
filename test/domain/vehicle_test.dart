import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gestor_vehiculos/core/constants/vehicle_constants.dart';
import 'package:gestor_vehiculos/domain/models/vehicle.dart';

Vehicle _sample() => Vehicle(
      id: 'v1',
      plate: 'AB123CD',
      type: VehicleType.car,
      brand: 'Toyota',
      model: 'Corolla',
      year: 2020,
      color: const Color(0xFFFFFFFF),
      km: 50000,
      fuelType: FuelType.nafta,
      status: VehicleStatus.available,
      provinceId: 1,
      city: 'La Plata',
      responsibleName: 'Juan',
      responsiblePhone: '221555',
      createdAt: DateTime(2024, 1, 1),
      updatedAt: DateTime(2024, 1, 1),
    );

void main() {
  group('Vehicle enum parsing (#B2)', () {
    test('fromMap tolera un index de enum fuera de rango sin crashear', () {
      final map = _sample().toMap()..['type'] = 99;
      expect(() => Vehicle.fromMap(map), returnsNormally);
      expect(Vehicle.fromMap(map).type, VehicleType.car);
    });

    test('fromSupabase tolera fuel_type fuera de rango', () {
      final map = _sample().toSupabase()
        ..['fuel_type'] = 99
        ..['created_at'] = DateTime(2024, 1, 1).toIso8601String()
        ..['updated_at'] = DateTime(2024, 1, 1).toIso8601String();
      expect(() => Vehicle.fromSupabase(map), returnsNormally);
      expect(Vehicle.fromSupabase(map).fuelType, FuelType.nafta);
    });

    test('fromJson tolera un nombre de enum desconocido', () {
      final json = _sample().toJson()..['status'] = 'vendido';
      expect(() => Vehicle.fromJson(json), returnsNormally);
      expect(Vehicle.fromJson(json).status, VehicleStatus.available);
    });
  });

  group('Vehicle equality (#B13)', () {
    test('dos vehiculos con los mismos campos son iguales y comparten hashCode', () {
      expect(_sample(), equals(_sample()));
      expect(_sample().hashCode, equals(_sample().hashCode));
    });

    test('cambiar un campo rompe la igualdad', () {
      expect(_sample(), isNot(equals(_sample().copyWith(km: 1))));
    });
  });

  group('Vehicle.copyWith (#B14)', () {
    test('copyWith sin updatedAt preserva el updatedAt original', () {
      final v = _sample();
      expect(v.copyWith(km: 60000).updatedAt, equals(v.updatedAt));
    });

    test('copyWith con updatedAt explicito lo respeta', () {
      final v = _sample();
      final t = DateTime(2025, 5, 5);
      expect(v.copyWith(updatedAt: t).updatedAt, equals(t));
    });
  });

  group('VehicleColors.getByColor (#B22)', () {
    test('matchea un color predefinido vía toARGB32', () {
      expect(VehicleColors.getByColor(const Color(0xFFDC2626)).name, 'Rojo');
    });

    test('un color desconocido cae al primero', () {
      expect(VehicleColors.getByColor(const Color(0xFF123456)).name, 'Blanco');
    });
  });
}
