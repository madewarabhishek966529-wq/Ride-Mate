import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../domain/models/ride.dart';
import '../services/ledger_service.dart';

class UpiPaymentService {
  /// Builds a standard Indian UPI payment deep-link URI.
  Uri buildUpiUri({
    required String upiId,
    required String payeeName,
    required double amount,
    String? note,
  }) {
    final cleanUpi = upiId.trim();
    final cleanName = Uri.encodeComponent(payeeName.trim());
    final cleanNote = Uri.encodeComponent(note ?? 'RideMate Settlement');
    final formattedAmount = amount.toStringAsFixed(2);

    return Uri.parse(
      'upi://pay?pa=$cleanUpi&pn=$cleanName&am=$formattedAmount&cu=INR&tn=$cleanNote',
    );
  }

  /// Attempts to launch the UPI payment app on device.
  Future<bool> launchUpiPayment({
    required String upiId,
    required String payeeName,
    required double amount,
    String? note,
  }) async {
    final uri = buildUpiUri(
      upiId: upiId,
      payeeName: payeeName,
      amount: amount,
      note: note,
    );

    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }

  /// Generates a shareable WhatsApp settlement text breakdown.
  String generateSettlementSummaryMessage({
    required String friendName,
    required FriendLedgerSummary summary,
    required List<Ride> friendRides,
    String? upiId,
  }) {
    final isOwedToUser = summary.netBalance > 0;
    final isUserOwes = summary.netBalance < 0;
    final balanceText = isOwedToUser
        ? 'Owes ₹${summary.netBalance.toStringAsFixed(2)}'
        : (isUserOwes ? 'Owed ₹${summary.netBalance.abs().toStringAsFixed(2)}' : 'Settled (₹0.00)');

    final buffer = StringBuffer();
    buffer.writeln('🚴 *RideMate Settlement Breakdown*');
    buffer.writeln('----------------------------------');
    buffer.writeln('Friend: *$friendName*');
    buffer.writeln('Balance Status: *$balanceText*');
    buffer.writeln();

    if (friendRides.isNotEmpty) {
      buffer.writeln('*Shared Rides Summary:*');
      for (var r in friendRides.take(5)) {
        buffer.writeln('• ${r.name}: ₹${r.totalFuelCost.toStringAsFixed(2)} total (${r.distanceKm.toStringAsFixed(1)} km)');
      }
      if (friendRides.length > 5) {
        buffer.writeln('• ...and ${friendRides.length - 5} more rides');
      }
      buffer.writeln();
    }

    if (upiId != null && upiId.trim().isNotEmpty && isOwedToUser) {
      buffer.writeln('💳 *Pay via UPI ID:* `${upiId.trim()}`');
      buffer.writeln();
    }

    buffer.writeln('_Shared via RideMate App 🚀_');
    return buffer.toString();
  }

  /// Shares the settlement summary directly via Share Sheet / WhatsApp.
  Future<void> shareSettlementSummary({
    required String friendName,
    required FriendLedgerSummary summary,
    required List<Ride> friendRides,
    String? upiId,
  }) async {
    final message = generateSettlementSummaryMessage(
      friendName: friendName,
      summary: summary,
      friendRides: friendRides,
      upiId: upiId,
    );

    await Share.share(message, subject: 'RideMate Settlement - $friendName');
  }
}
