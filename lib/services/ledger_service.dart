import '../domain/models/ride.dart';
import '../domain/models/settlement_record.dart';

class LedgerItem {
  final String rideId;
  final String rideName;
  final DateTime date;
  final double amount; // positive if friend owes user, negative if user owes friend
  final String paidBy;

  LedgerItem({
    required this.rideId,
    required this.rideName,
    required this.date,
    required this.amount,
    required this.paidBy,
  });
}

class FriendLedgerSummary {
  final String friendId;
  final double netBalance; // positive = friend owes user, negative = user owes friend, 0 = settled
  final int rideCount;
  final List<LedgerItem> contributingRides;
  final double totalSettled;

  FriendLedgerSummary({
    required this.friendId,
    required this.netBalance,
    required this.rideCount,
    required this.contributingRides,
    required this.totalSettled,
  });
}

class LedgerService {
  FriendLedgerSummary calculateFriendBalance({
    required String friendId,
    required List<Ride> rides,
    required List<SettlementRecord> settlements,
  }) {
    final friendRides = rides.where((r) => r.participantIds.contains(friendId)).toList();

    double grossBalance = 0.0;
    final List<LedgerItem> items = [];

    for (final ride in friendRides) {
      double lineAmount = 0.0;
      if (ride.paidBy == 'ME') {
        // User paid: friend owes user their share
        final friendShare = ride.participantShares[friendId] ?? 0.0;
        lineAmount = friendShare;
      } else if (ride.paidBy == friendId) {
        // Friend paid: user owes friend user's share
        final userShare = ride.participantShares['ME'] ?? 0.0;
        lineAmount = -userShare;
      }

      grossBalance += lineAmount;
      items.add(LedgerItem(
        rideId: ride.id,
        rideName: ride.name,
        date: ride.date,
        amount: lineAmount,
        paidBy: ride.paidBy,
      ));
    }

    final friendSettlements = settlements.where((s) => s.friendId == friendId);
    double totalSettled = 0.0;
    for (final s in friendSettlements) {
      totalSettled += s.amount;
    }

    final rawNet = grossBalance - totalSettled;
    final netBalance = double.parse(rawNet.toStringAsFixed(2));

    return FriendLedgerSummary(
      friendId: friendId,
      netBalance: netBalance,
      rideCount: friendRides.length,
      contributingRides: items,
      totalSettled: totalSettled,
    );
  }
}
