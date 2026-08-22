import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/models/friend.dart';
import '../../providers/providers.dart';
import '../widgets/gradient_button.dart';
import 'ledger_screen.dart';

class FriendsListScreen extends ConsumerWidget {
  const FriendsListScreen({super.key});

  void _showAddFriendDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Add Friend'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              labelText: 'Friend Name',
              hintText: 'e.g. Rahul, Amit',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
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
                if (dialogContext.mounted) Navigator.of(dialogContext).pop();
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
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people, color: Color(0xFF6366F1)),
            SizedBox(width: 8),
            Text('Friends & Ledger', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
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
          // Colorful Banner for Ledger Shortcut
          Container(
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF3B82F6)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Colors.white24,
                  child: Icon(Icons.account_balance_wallet, color: Colors.white),
                ),
                title: const Text(
                  'Group Ledger Summary',
                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                ),
                subtitle: const Text(
                  'View balances across all shared rides',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 16),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const LedgerScreen()),
                  );
                },
              ),
            ),
          ),
          Expanded(
            child: friends.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.purple.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.people_outline, size: 64, color: Color(0xFF8B5CF6)),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'No Friends Added Yet',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Add your friends to split fuel costs automatically!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          GradientButton(
                            text: 'Add Friend',
                            icon: Icons.person_add,
                            gradientColors: const [Color(0xFF8B5CF6), Color(0xFFEC4899)],
                            onPressed: () => _showAddFriendDialog(context, ref),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      final summary = ref.watch(friendLedgerProvider(friend.id));

                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: 1.0),
                        duration: Duration(milliseconds: 200 + (index * 50)),
                        builder: (context, value, child) {
                          return Transform.translate(
                            offset: Offset(0, 16 * (1 - value)),
                            child: Opacity(
                              opacity: value,
                              child: child,
                            ),
                          );
                        },
                        child: Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
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
                            subtitle: Text(
                              summary.rideCount == 0
                                  ? 'No shared rides'
                                  : summary.netBalance > 0
                                      ? 'Owes you ₹${summary.netBalance.toStringAsFixed(2)}'
                                      : summary.netBalance < 0
                                          ? 'You owe ₹${summary.netBalance.abs().toStringAsFixed(2)}'
                                          : 'Settled up',
                              style: TextStyle(
                                color: summary.netBalance > 0
                                    ? Colors.green.shade700
                                    : summary.netBalance < 0
                                        ? Colors.red.shade700
                                        : Colors.grey,
                                fontWeight: summary.netBalance != 0 ? FontWeight.bold : FontWeight.normal,
                              ),
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                              onPressed: () async {
                                await ref
                                    .read(friendListProvider.notifier)
                                    .deleteFriend(friend.id);
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF8B5CF6), Color(0xFFEC4899)],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5CF6).withValues(alpha: 0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          heroTag: 'add_friend_fab',
          elevation: 0,
          backgroundColor: Colors.transparent,
          onPressed: () => _showAddFriendDialog(context, ref),
          icon: const Icon(Icons.person_add, color: Colors.white),
          label: const Text('Add Friend', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}
