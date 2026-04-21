import '../../features/profile/providers/weight_unit_notifier.dart';

/// Convierte kg al valor en la unidad preferida del usuario.
double toDisplayUnit(double kg, WeightUnit unit) =>
    unit == WeightUnit.lbs ? kg * 2.20462 : kg;

/// Convierte el valor ingresado por el usuario de su unidad preferida a kg.
double fromDisplayUnit(double value, WeightUnit unit) =>
    unit == WeightUnit.lbs ? value / 2.20462 : value;

/// Formatea un peso (en kg) como string con la unidad del usuario.
/// Ejemplo: formatWeight(80, WeightUnit.lbs) → "176.4 lbs"
String formatWeight(double kg, WeightUnit unit, {int decimals = 1}) {
  final val = toDisplayUnit(kg, unit);
  final label = unit == WeightUnit.lbs ? 'lbs' : 'kg';
  return '${val.toStringAsFixed(decimals)} $label';
}
