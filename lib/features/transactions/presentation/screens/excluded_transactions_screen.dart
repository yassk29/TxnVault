import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/helpers/currency_formatter.dart';
import '../../providers/transactions_providers.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime dt) => '${dt.day} ${_months[dt.month - 1]}';

/// Transactions the user excluded from History - hidden from the main list
/// and totals, but never deleted, so they can be reviewed and restored here.
class ExcludedTransactionsScreen extends ConsumerWidget {
  const ExcludedTransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final excluded = ref.watch(excludedTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Excluded Transactions')),
      body: excluded.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text('Nothing excluded.'));
          }
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final item = rows[index];
              final isCredit = item.direction == 'CREDIT';
              final title = item.merchantName ?? item.bankName ?? 'Transaction';
              return ListTile(
                title: Text(title),
                subtitle: Text(_formatDate(item.transactionDate)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${isCredit ? '+' : '-'}${formatIndianCurrency(item.amount)}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      onPressed: () => restoreTransaction(ref, item.id),
                      child: const Text('Restore'),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
