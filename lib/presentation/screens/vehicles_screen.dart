import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/config/supabase_config.dart';
import '../../core/constants/provinces.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../data/services/sync_service.dart';
import '../../domain/models/vehicle.dart';
import '../providers/vehicle_provider.dart';
import '../widgets/vehicle_icon.dart';

class VehiclesScreen extends ConsumerStatefulWidget {
  final int? provinceId;

  const VehiclesScreen({super.key, this.provinceId});

  @override
  ConsumerState<VehiclesScreen> createState() => _VehiclesScreenState();
}

class _VehiclesScreenState extends ConsumerState<VehiclesScreen> {
  VehicleStatus? _statusFilter;

  @override
  void initState() {
    super.initState();
    if (widget.provinceId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedProvinceProvider.notifier).state = widget.provinceId;
      });
    }
  }

  Future<void> _onRefresh() async {
    if (SupabaseConfig.isConfigured) {
      await ref.read(syncServiceProvider.notifier).fullSync();
    }
    await ref.read(vehicleNotifierProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final selectedProvince = ref.watch(selectedProvinceProvider);
    final vehiclesAsync = ref.watch(vehiclesBySelectedProvinceProvider);

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Vehículos',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      if (selectedProvince != null)
                        Text(
                          ArgentinaProvinces.getById(selectedProvince).name,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.accentPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: () => context.push('/search'),
                      icon: const Icon(Icons.search, color: AppTheme.accentPrimary),
                    ),
                    IconButton(
                      onPressed: () => _showFilters(context),
                      icon: Badge(
                        isLabelVisible: selectedProvince != null || _statusFilter != null,
                        child: const Icon(Icons.filter_list, color: AppTheme.accentPrimary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Status filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _FilterChip(
                  label: 'Todos',
                  isSelected: _statusFilter == null,
                  onTap: () => setState(() => _statusFilter = null),
                ),
                const SizedBox(width: 8),
                ...VehicleStatus.values.map((status) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _FilterChip(
                    label: status.label,
                    isSelected: _statusFilter == status,
                    color: status.color,
                    onTap: () => setState(() => _statusFilter = status),
                  ),
                )),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Vehicle list
          Expanded(
            child: vehiclesAsync.when(
              data: (vehicles) {
                // Aplicar filtro de estado
                final filteredVehicles = _statusFilter == null
                    ? vehicles
                    : vehicles.where((v) => v.status == _statusFilter).toList();

                if (filteredVehicles.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _onRefresh,
                    color: AppTheme.accentPrimary,
                    child: ListView(
                      children: [
                        SizedBox(
                          height: MediaQuery.of(context).size.height * 0.5,
                          child: _EmptyState(
                            hasFilter: selectedProvince != null || _statusFilter != null,
                            onClearFilters: () {
                              ref.read(selectedProvinceProvider.notifier).state = null;
                              setState(() => _statusFilter = null);
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: _onRefresh,
                  color: AppTheme.accentPrimary,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: filteredVehicles.length,
                    itemBuilder: (context, index) {
                      final vehicle = filteredVehicles[index];
                      return _VehicleCard(
                        vehicle: vehicle,
                        onTap: () => context.push('/vehicle/${vehicle.id}'),
                      );
                    },
                  ),
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilters(BuildContext context) {
    final selectedProvince = ref.read(selectedProvinceProvider);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: Column(
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
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filtrar por Provincia',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (selectedProvince != null)
                      TextButton(
                        onPressed: () {
                          ref.read(selectedProvinceProvider.notifier).state = null;
                          Navigator.pop(context);
                        },
                        child: const Text('Limpiar'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  controller: scrollController,
                  itemCount: ArgentinaProvinces.all.length + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return ListTile(
                        leading: const Icon(Icons.public),
                        title: const Text('Todas las provincias'),
                        trailing: selectedProvince == null
                            ? const Icon(Icons.check, color: AppTheme.accentPrimary)
                            : null,
                        onTap: () {
                          ref.read(selectedProvinceProvider.notifier).state = null;
                          Navigator.pop(context);
                        },
                      );
                    }
                    
                    final province = ArgentinaProvinces.all[index - 1];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppTheme.surfaceLight,
                        child: Text(
                          province.abbreviation,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      title: Text(province.name),
                      trailing: selectedProvince == province.id
                          ? const Icon(Icons.check, color: AppTheme.accentPrimary)
                          : null,
                      onTap: () {
                        ref.read(selectedProvinceProvider.notifier).state = province.id;
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color? color;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? (color ?? AppTheme.accentPrimary).withValues(alpha: 0.2)
              : AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? (color ?? AppTheme.accentPrimary)
                : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (color != null && isSelected) ...[
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected 
                    ? (color ?? AppTheme.accentPrimary)
                    : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleCard extends StatelessWidget {
  final Vehicle vehicle;
  final VoidCallback onTap;

  const _VehicleCard({
    required this.vehicle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final province = ArgentinaProvinces.getById(vehicle.provinceId);
    final hasWarning = vehicle.isVtvExpiringSoon || 
                       vehicle.isInsuranceExpiringSoon ||
                       vehicle.isVtvExpired ||
                       vehicle.isInsuranceExpired;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasWarning 
                ? AppTheme.warning.withValues(alpha: 0.5)
                : AppTheme.border,
          ),
        ),
        child: Row(
          children: [
            VehicleIcon(
              type: vehicle.type,
              vehicleColor: vehicle.color,
              status: vehicle.status,
              size: 56,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          vehicle.displayName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      if (hasWarning)
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 18,
                          color: vehicle.isVtvExpired || vehicle.isInsuranceExpired
                              ? AppTheme.error
                              : AppTheme.warning,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    vehicle.plate,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.accentPrimary,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          '${vehicle.city}, ${province.abbreviation}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.person_outline,
                        size: 14,
                        color: AppTheme.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          vehicle.responsibleName,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right,
              color: AppTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool hasFilter;
  final VoidCallback onClearFilters;

  const _EmptyState({
    required this.hasFilter,
    required this.onClearFilters,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              hasFilter ? Icons.filter_alt_off : Icons.directions_car_outlined,
              size: 64,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              hasFilter 
                  ? 'No hay vehículos con estos filtros'
                  : 'No hay vehículos registrados',
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (hasFilter)
              OutlinedButton(
                onPressed: onClearFilters,
                child: const Text('Limpiar filtros'),
              )
            else
              ElevatedButton.icon(
                onPressed: () => context.push('/vehicle/new'),
                icon: const Icon(Icons.add),
                label: const Text('Agregar vehículo'),
              ),
          ],
        ),
      ),
    );
  }
}
