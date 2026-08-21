class FuelCalculationService {
  /// Fuel used in liters = distanceKm / mileage
  double calculateFuelUsed(double distanceKm, double mileageKmPerLiter) {
    if (mileageKmPerLiter <= 0) return 0.0;
    final fuel = distanceKm / mileageKmPerLiter;
    return double.parse(fuel.toStringAsFixed(2));
  }

  /// Total fuel cost = fuelUsedLiters * pricePerLiter
  double calculateFuelCost(double fuelUsedLiters, double pricePerLiter) {
    final cost = fuelUsedLiters * pricePerLiter;
    return double.parse(cost.toStringAsFixed(2));
  }
}
