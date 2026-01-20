import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../core/constants/vehicle_constants.dart';
import '../../core/theme/app_theme.dart';

class VehicleIcon extends StatelessWidget {
  final VehicleType type;
  final Color vehicleColor;
  final double size;
  final VehicleStatus? status;
  final bool showStatusBadge;

  const VehicleIcon({
    super.key,
    required this.type,
    required this.vehicleColor,
    this.size = 48,
    this.status,
    this.showStatusBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: vehicleColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(size * 0.25),
            border: Border.all(
              color: vehicleColor.withValues(alpha: 0.3),
              width: 1.5,
            ),
          ),
          child: Center(
            child: SvgPicture.asset(
              type.iconAsset,
              width: size * 0.6,
              height: size * 0.6,
              colorFilter: ColorFilter.mode(
                vehicleColor,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
        if (showStatusBadge && status != null)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              width: size * 0.35,
              height: size * 0.35,
              decoration: BoxDecoration(
                color: status!.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppTheme.background,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: status!.color.withValues(alpha: 0.4),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                status!.icon,
                size: size * 0.18,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }
}

// Widget para seleccionar tipo de vehículo
class VehicleTypeSelector extends StatelessWidget {
  final VehicleType? selectedType;
  final ValueChanged<VehicleType> onSelected;
  final Color vehicleColor;

  const VehicleTypeSelector({
    super.key,
    this.selectedType,
    required this.onSelected,
    this.vehicleColor = AppTheme.accentPrimary,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: VehicleType.values.map((type) {
        final isSelected = type == selectedType;
        return GestureDetector(
          onTap: () => onSelected(type),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSelected 
                  ? vehicleColor.withValues(alpha: 0.2)
                  : AppTheme.surfaceLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? vehicleColor : AppTheme.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  type.iconAsset,
                  width: 36,
                  height: 36,
                  colorFilter: ColorFilter.mode(
                    isSelected ? vehicleColor : AppTheme.textSecondary,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  type.label,
                  style: TextStyle(
                    color: isSelected 
                        ? AppTheme.textPrimary 
                        : AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// Widget para seleccionar color del vehículo
class VehicleColorSelector extends StatelessWidget {
  final Color? selectedColor;
  final ValueChanged<Color> onSelected;

  const VehicleColorSelector({
    super.key,
    this.selectedColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: VehicleColors.options.map((option) {
        final isSelected = option.color.value == selectedColor?.value;
        return GestureDetector(
          onTap: () => onSelected(option.color),
          child: Tooltip(
            message: option.name,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: option.color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected 
                      ? AppTheme.accentPrimary 
                      : option.color == const Color(0xFFFFFFFF)
                          ? AppTheme.border
                          : Colors.transparent,
                  width: isSelected ? 3 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: option.color.withValues(alpha: 0.5),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: isSelected
                  ? Icon(
                      Icons.check,
                      color: option.color.computeLuminance() > 0.5
                          ? Colors.black
                          : Colors.white,
                      size: 20,
                    )
                  : null,
            ),
          ),
        );
      }).toList(),
    );
  }
}
