import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/friend.dart';
import '../../providers/providers.dart';
import 'ledger_screen.dart';

class FriendsListScreen extends ConsumerWidget {
  const FriendsListScreen({super.key});

  void _showAddFriendDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Friend'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Friend Name',
              hintText: 'e.g. Rahul, Amit',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  final newFriend = Friend(
                    id: const Uuid().v4(),
                    name: name,
                  );
                  await ref.read(friendListProvider.notifier).addFriend(newFriend);
                }
                if (context.mounted) Navigator.of(context).pop();
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final friends = ref.watch(friendListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            tooltip: 'Group Ledger',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const LedgerScreen()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Banner for Ledger Shortcut
          Card(
            margin: const EdgeInsets.all(12),
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.blueGrey.shade800
                : Colors.blue.shade50,
            child: ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.account_balance_wallet, color: Colors.white),
              ),
              title: const Text(
                'Group Ledger',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('View running balances across shared rides'),
              trailing: const Icon(Icons.arrow_forward),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (context) => const LedgerScreen()),
                );
              },
            ),
          ),
          Expanded(
            child: friends.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.people_outline, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('No friends added yet.'),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => _showAddFriendDialog(context, ref),
                          icon: const Icon(Icons.person_add),
                          label: const Text('Add Friend'),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      final summary = ref.watch(friendLedgerProvider(friend.id));

                      return Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          leading: CircleAvatar(
                            child: Text(friend.name.isNotEmpty ? friend.name[0].toUpperCase() : '?'),
                          ),
                          title: Text(
                            friend.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            summary.rideCount == 0
                                ? 'No rides yet'
                                : summary.netBalance > 0
                                    ? 'Owes you ₹${summary.netBalance.toStringAsFixed(2)}'
                                    : summary.netBalance < 0
                                        ? 'You owe ₹${summary.netBalance.abs().toStringAsFixed(2)}'
                                        : 'Settled up',
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                            onPressed: () async {
                              await ref
                                  .read(friendListProvider.notifier)
                                  .deleteFriend(friend.id);
                            },
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddFriendDialog(context, ref),
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
