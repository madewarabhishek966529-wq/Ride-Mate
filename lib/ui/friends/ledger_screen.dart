import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/friend.dart';
import '../../domain/models/settlement_record.dart';
import '../../providers/providers.dart';
import '../../services/ledger_service.dart';

class LedgerScreen extends ConsumerWidget {
  const LedgerScreen({super.key});

  void _showItemizedBreakdown(
    BuildContext context,
    WidgetRef ref,
    Friend friend,
    FriendLedgerSummary summary,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          maxChildSize: 0.9,
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
                  Text(
                    'Ledger: ${friend.name}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
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
                  if (summary.netBalance != 0)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          final record = SettlementRecord(
                            id: const Uuid().v4(),
                            friendId: friend.id,
                            amount: summary.netBalance,
                            date: DateTime.now(),
                          );
                          await ref
                              .read(settlementListProvider.notifier)
                              .addSettlement(record);
                          if (context.mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Marked ${friend.name} as Settled!'),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.check_circle),
                        label: const Text('Mark as Settled'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
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
                  child: ListTile(
                    leading: CircleAvatar(
                      child: Text(friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?'),
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
                        if (summary.netBalance != 0)
                          IconButton(
                            icon: const Icon(Icons.check_circle_outline, color: Colors.green),
                            tooltip: 'Mark as Settled',
                            onPressed: () async {
                              final record = SettlementRecord(
                                id: const Uuid().v4(),
                                friendId: friend.id,
                                amount: summary.netBalance,
                                date: DateTime.now(),
                              );
                              await ref
                                  .read(settlementListProvider.notifier)
                                  .addSettlement(record);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Marked ${friend.name} as Settled!'),
                                  ),
                                );
                              }
                            },
                          ),
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
