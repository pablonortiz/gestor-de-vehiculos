import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/provinces.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/models/city.dart';
import '../providers/vehicle_provider.dart';
import '../providers/location_provider.dart';

/// Bottom-sheet con las ciudades de una provincia y su conteo de vehículos.
void showCitiesInProvinceSheet(
    BuildContext context, WidgetRef ref, Province province) {
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Ciudades en ${province.name}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: Consumer(
              builder: (context, ref, _) {
                final citiesAsync = ref.watch(citiesByProvinceProvider(province.id));
                final countsAsync = ref.watch(vehicleCountByCityProvider(province.id));

                return citiesAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (_, _) => const Center(child: Text('Error cargando ciudades')),
                  data: (cities) {
                    if (cities.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.all(20),
                        child: Text(
                          'No hay ciudades registradas en esta provincia',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return countsAsync.when(
                      loading: () => _buildCityList(sheetContext, ref, province, cities, {}),
                      error: (_, _) => _buildCityList(sheetContext, ref, province, cities, {}),
                      data: (counts) => _buildCityList(sheetContext, ref, province, cities, counts),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}

Widget _buildCityList(
  BuildContext context,
  WidgetRef ref,
  Province province,
  List<City> cities,
  Map<String, int> counts,
) {
  return ListView.builder(
    shrinkWrap: true,
    itemCount: cities.length,
    itemBuilder: (context, index) {
      final city = cities[index];
      final count = counts[city.id] ?? 0;

      return ListTile(
        leading: const Icon(Icons.location_city),
        title: Text(city.name),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (count > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  count.toString(),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.accentPrimary,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right),
          ],
        ),
        onTap: () {
          Navigator.pop(context);
          ref.read(locationFilterProvider.notifier).setProvince(province.id);
          ref.read(locationFilterProvider.notifier).setCity(city.id);
          GoRouter.of(context).go('/vehicles');
        },
      );
    },
  );
}

/// Bottom-sheet con los vehículos cuya documentación está próxima a vencer.
void showExpiringVehiclesSheet(BuildContext context, WidgetRef ref) {
  final vehicles = ref.read(expiringDocumentsProvider).valueOrNull;

  // Si el provider aún no resolvió (loading) o quedó en error, dar feedback
  // en vez de un tap que no hace nada.
  if (vehicles == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cargando documentos, probá de nuevo en un instante'),
      ),
    );
    return;
  }

  if (vehicles.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No hay documentos próximos a vencer'),
      ),
    );
    return;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Documentos por Vencer',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: vehicles.length,
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                return ListTile(
                  leading: Icon(
                    vehicle.isVtvExpired || vehicle.isInsuranceExpired
                        ? Icons.error
                        : Icons.warning_amber_rounded,
                    color: vehicle.isVtvExpired || vehicle.isInsuranceExpired
                        ? AppTheme.error
                        : AppTheme.warning,
                  ),
                  title: Text('${vehicle.brand} ${vehicle.model}'),
                  subtitle: Text(vehicle.plate),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/vehicle/${vehicle.id}');
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    ),
  );
}
