import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sms/sms_providers.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatTimestamp(DateTime dt) {
  final hour12 = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final minute = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'AM' : 'PM';
  return '${dt.day} ${_months[dt.month - 1]}, $hour12:$minute $period';
}

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(smsMessagesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Transactions')),
      body: messages.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (rows) {
          if (rows.isEmpty) return const _EmptyState();
          return ListView.builder(
            itemCount: rows.length,
            itemBuilder: (context, index) {
              final row = rows[index];
              return ListTile(
                leading: const Icon(Icons.sms_outlined),
                title: Text(row.sender),
                subtitle: Text(
                  row.messageBody,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Text(
                  _formatTimestamp(row.receivedAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            const Text('No transactions found.'),
            const Text('Start by importing SMS transactions.'),
          ],
        ),
      ),
    );
  }
}
