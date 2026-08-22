import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/friend.dart';
import '../../domain/models/settlement_record.dart';
import '../../providers/providers.dart';
import '../../services/ledger_service.dart';
import '../widgets/gradient_button.dart';

class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({super.key});

  void _showUpiPaymentDialog(BuildContext context, WidgetRef ref, Friend friend, double amount) {
    final upiController = TextEditingController(text: '${friend.name.toLowerCase().replaceAll(' ', '')}@okaxis');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.payment, color: Color(0xFF6366F1)),
              const SizedBox(width: 8),
              Expanded(child: Text('Pay ${friend.name} via UPI')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Amount to Pay: ₹${amount.abs().toStringAsFixed(2)}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: upiController,
                decoration: const InputDecoration(
                  labelText: "Receiver's UPI ID",
                  hintText: 'e.g. rahul@upi or 9876543210@paytm',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.account_balance),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                final upiId = upiController.text.trim();
                if (upiId.isEmpty) return;

                final upiService = ref.read(upiPaymentServiceProvider);
                final launched = await upiService.launchUpiPayment(
                  upiId: upiId,
                  payeeName: friend.name,
                  amount: amount.abs(),
                  note: 'RideMate Settlement - ${friend.name}',
                );

                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                  if (!launched) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('UPI payment link opened for $upiId (₹${amount.abs().toStringAsFixed(2)})'),
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('Launch UPI App'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6366F1),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showItemizedBreakdown(
    BuildContext context,
    WidgetRef ref,
    Friend friend,
    FriendLedgerSummary summary,
  ) {
    final rides = ref.read(rideListProvider);
    final friendRides = rides.where((r) => r.participantIds.contains(friend.id)).toList();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade400,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Ledger: ${friend.name}',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.share, color: Color(0xFF6366F1)),
                        tooltip: 'Share on WhatsApp',
                        onPressed: () {
                          ref.read(upiPaymentServiceProvider).shareSettlementSummary(
                                friendName: friend.name,
                                summary: summary,
                                friendRides: friendRides,
                                upiId: '${friend.name.toLowerCase().replaceAll(' ', '')}@okaxis',
                              );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    summary.netBalance > 0
                        ? 'Owes you ₹${summary.netBalance.toStringAsFixed(2)}'
                        : summary.netBalance < 0
                            ? 'You owe ₹${summary.netBalance.abs().toStringAsFixed(2)}'
                            : 'Settled up',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: summary.netBalance > 0
                          ? Colors.green
                          : summary.netBalance < 0
                              ? Colors.red
                              : Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const Text(
                    'Itemized Ride Contributions',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: summary.contributingRides.isEmpty
                        ? const Center(child: Text('No rides associated with this friend.'))
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: summary.contributingRides.length,
                            itemBuilder: (context, index) {
                              final item = summary.contributingRides[index];
                              final isOwed = item.amount >= 0;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: isOwed ? Colors.green.shade100 : Colors.red.shade100,
                                  child: Icon(
                                    isOwed ? Icons.arrow_downward : Icons.arrow_upward,
                                    color: isOwed ? Colors.green.shade800 : Colors.red.shade800,
                                    size: 18,
                                  ),
                                ),
                                title: Text(item.rideName),
                                subtitle: Text(
                                  '${DateFormat('MMM d, yyyy').format(item.date)} • Paid by: ${item.paidBy == 'ME' ? 'Me' : friend.name}',
                                ),
                                trailing: Text(
                                  '${isOwed ? "+" : "-"}₹${item.amount.abs().toStringAsFixed(2)}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: isOwed ? Colors.green.shade800 : Colors.red.shade800,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 12),
                  if (summary.netBalance != 0) ...[
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showUpiPaymentDialog(context, ref, friend, summary.netBalance),
                            icon: const Icon(Icons.payment),
                            label: const Text('Pay via UPI'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: GradientButton(
                            text: 'Mark Settled',
                            icon: Icons.check_circle,
                            gradientColors: const [Color(0xFF10B981), Color(0xFF059669)],
                            height: 42,
                            onPressed: () async {
                              final record = SettlementRecord(
                                id: const Uuid().v4(),
                                friendId: friend.id,
                                amount: summary.netBalance,
                                date: DateTime.now(),
                              );
                              await ref.read(settlementListProvider.notifier).addSettlement(record);
                              if (context.mounted) {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Marked ${friend.name} as Settled!'),
                                  ),
                                );
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendListProvider);
    final rides = ref.watch(rideListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Group Ledger'),
      ),
      body: friends.isEmpty
          ? const Center(
              child: Text(
                'No friends added yet.\nAdd friends to view running ledger balances.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: friends.length,
              itemBuilder: (context, index) {
                final friend = friends[index];
                final summary = ref.watch(friendLedgerProvider(friend.id));
                final friendRides = rides.where((r) => r.participantIds.contains(friend.id)).toList();

                String balanceText;
                Color balanceColor;

                if (summary.rideCount == 0) {
                  balanceText = 'No rides yet';
                  balanceColor = Colors.grey;
                } else if (summary.netBalance > 0) {
                  balanceText = 'Owes you ₹${summary.netBalance.toStringAsFixed(2)}';
                  balanceColor = Colors.green;
                } else if (summary.netBalance < 0) {
                  balanceText = 'You owe ₹${summary.netBalance.abs().toStringAsFixed(2)}';
                  balanceColor = Colors.red;
                } else {
                  balanceText = 'Settled up';
                  balanceColor = Colors.grey;
                }

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFF6366F1).withValues(alpha: 0.15),
                      child: Text(
                        friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?',
                        style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF6366F1)),
                      ),
                    ),
                    title: Text(
                      friend.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: summary.rideCount > 0
                        ? Text(
                            '$balanceText  (across ${summary.rideCount} ride${summary.rideCount == 1 ? '' : 's'})',
                            style: TextStyle(color: balanceColor, fontWeight: FontWeight.w600),
                          )
                        : Text(
                            balanceText,
                            style: TextStyle(color: balanceColor),
                          ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (summary.netBalance != 0) ...[
                          IconButton(
                            icon: const Icon(Icons.payment, color: Color(0xFF6366F1), size: 20),
                            tooltip: 'Pay via UPI',
                            onPressed: () => _showUpiPaymentDialog(context, ref, friend, summary.netBalance),
                          ),
                          IconButton(
                            icon: const Icon(Icons.share, color: Colors.green, size: 20),
                            tooltip: 'Share on WhatsApp',
                            onPressed: () {
                              ref.read(upiPaymentServiceProvider).shareSettlementSummary(
                                    friendName: friend.name,
                                    summary: summary,
                                    friendRides: friendRides,
                                    upiId: '${friend.name.toLowerCase().replaceAll(' ', '')}@okaxis',
                                  );
                            },
                          ),
                        ],
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                    onTap: () => _showItemizedBreakdown(context, ref, friend, summary),
                  ),
                );
              },
            ),
    );
  }
}
