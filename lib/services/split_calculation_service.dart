class SplitCalculationService {
  /// Splits total cost evenly among participants.
  Map<String, double> calculateEvenShares(double totalCost, List<String> participantIds) {
    if (participantIds.isEmpty) return {};
    final share = double.parse((totalCost / participantIds.length).toStringAsFixed(2));
    final Map<String, double> shares = {};
    for (final id in participantIds) {
      shares[id] = share;
    }
    return shares;
  }
}
