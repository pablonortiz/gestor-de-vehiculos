import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/expense_summary.dart';
import 'db_change_provider.dart';
import 'fuel_charge_provider.dart';
import 'vehicle_provider.dart';

/// Dashboard de gastos consolidado (combustible + mantenimiento) de los últimos
/// 6 meses, agregando todos los vehículos. Se refresca ante cambios en cualquiera
/// de las fuentes.
final expenseDashboardProvider =
    FutureProvider.autoDispose<ExpenseDashboard>((ref) async {
  ref.watch(vehiclesChangeProvider);
  ref.watch(fuelChargesChangeProvider);
  ref.watch(maintenancesChangeProvider);

  final vehicles = await ref.watch(vehiclesProvider.future);
  final fuelCharges =
      await ref.watch(fuelChargeRepositoryProvider).getAllFuelCharges();
  final maintenances =
      await ref.watch(maintenanceRepositoryProvider).getAllMaintenances();

  return buildExpenseDashboard(
    vehicles: vehicles,
    fuelCharges: fuelCharges,
    maintenances: maintenances,
    now: DateTime.now(),
  );
});
