import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/enums/transaction_status.dart';
import '../../../../shared/helpers/currency_formatter.dart';
import '../../../../shared/providers/app_settings_provider.dart';
import '../../../../shared/providers/date_filter_provider.dart';
import '../../providers/transactions_providers.dart';
import '../widgets/transaction_filter_bar.dart';

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

// Many bank SMS templates only state a date, no time-of-day, so
// transactionDate's time component is often a meaningless midnight default -
// showing it would look like real precision that isn't there. Only the date
// is displayed; sorting instead uses the SMS's actual receipt time, which
// always has full precision (see transactionsListProvider).
String _formatDate(DateTime dt) => '${dt.day} ${_months[dt.month - 1]}';

TransactionStatus _statusFromString(String status) {
  return TransactionStatus.values.firstWhere(
    (s) => s.name.toUpperCase() == status.replaceAll('_', ''),
    orElse: () => TransactionStatus.success,
  );
}

Color _colorFor(TransactionListItem item) {
  final status = _statusFromString(item.status);
  if (status == TransactionStatus.success) {
    return item.direction == 'CREDIT' ? Colors.green : Colors.red;
  }
  return status.color;
}

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final transactions = ref.watch(transactionsListProvider);
    final filter = ref.watch(transactionFilterProvider);
    final dateFilter = ref.watch(sharedDateFilterProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.visibility_off_outlined),
            tooltip: 'Excluded transactions',
            onPressed: () => context.push('/excluded-transactions'),
          ),
        ],
      ),
      body: Column(
        children: [
          const TransactionFilterBar(),
          const _SwipeToExcludeHint(),
          const Divider(height: 1),
          Expanded(
            child: transactions.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
              data: (rows) {
                if (rows.isEmpty) {
                  return _EmptyState(
                    hasFilter: filter.isActive || dateFilter.isActive,
                  );
                }
                return ListView.builder(
                  itemCount: rows.length,
                  itemBuilder: (context, index) =>
                      _TransactionTile(rows[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// One-time nudge so users discover swipe-to-exclude, which otherwise has
/// no visible affordance on the list itself. Dismissing it persists via
/// AppSettings (see app_settings_provider.dart) so it never reappears once
/// closed, on this device.
class _SwipeToExcludeHint extends ConsumerWidget {
  const _SwipeToExcludeHint();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSeen = ref.watch(hasSeenHintProvider(swipeToExcludeHintKey));

    return hasSeen.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (seen) {
        if (seen) return const SizedBox.shrink();
        return Container(
          width: double.infinity,
          color: Theme.of(context).colorScheme.secondaryContainer,
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: Row(
            children: [
              Icon(Icons.swipe_left_outlined,
                  size: 20,
                  color: Theme.of(context).colorScheme.onSecondaryContainer),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Swipe a transaction left to exclude it from your history.',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSecondaryContainer,
                    fontSize: 13,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                color: Theme.of(context).colorScheme.onSecondaryContainer,
                onPressed: () => markHintSeen(ref, swipeToExcludeHintKey),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TransactionTile extends ConsumerWidget {
  const _TransactionTile(this.item);

  final TransactionListItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCredit = item.direction == 'CREDIT';
    final color = _colorFor(item);
    final title = item.merchantName ?? item.bankName ?? 'Transaction';
    final subtitleParts = [
      if (item.bankName != null) item.bankName!,
      if (item.cardLastFour != null) 'xx${item.cardLastFour}',
    ];

    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(
          Icons.visibility_off_outlined,
          color: Theme.of(context).colorScheme.onErrorContainer,
        ),
      ),
      confirmDismiss: (_) async {
        if (await readHintFlag(ref, skipExcludeConfirmKey)) return true;
        if (!context.mounted) return false;

        var dontAskAgain = false;
        final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => StatefulBuilder(
                builder: (context, setState) => AlertDialog(
                  title: const Text('Exclude this transaction?'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'It won\'t count toward totals or show in History. '
                        'You can restore it anytime from "Excluded '
                        'transactions".',
                      ),
                      CheckboxListTile(
                        value: dontAskAgain,
                        onChanged: (v) =>
                            setState(() => dontAskAgain = v ?? false),
                        title: const Text('Don\'t ask again'),
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Exclude'),
                    ),
                  ],
                ),
              ),
            ) ??
            false;

        if (confirmed && dontAskAgain) {
          await markHintSeen(ref, skipExcludeConfirmKey);
        }
        return confirmed;
      },
      onDismissed: (_) {
        excludeTransaction(ref, item.id);
        final messenger = ScaffoldMessenger.of(context);
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: const Text('Transaction excluded'),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Undo',
                // Tapping an action doesn't dismiss its SnackBar on its
                // own - without this it would otherwise sit there, visibly
                // "done", until its full duration elapses.
                onPressed: () {
                  restoreTransaction(ref, item.id);
                  messenger.hideCurrentSnackBar();
                },
              ),
            ),
          );
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.15),
          child: Icon(
            isCredit ? Icons.arrow_downward : Icons.arrow_upward,
            color: color,
          ),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: Text(title, overflow: TextOverflow.ellipsis)),
            if (item.category == 'REPAYMENT') ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Repayment',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                  ),
                ),
              ),
            ],
          ],
        ),
        subtitle: Text(subtitleParts.join(' · ')),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${isCredit ? '+' : '-'}${formatIndianCurrency(item.amount)}',
              style: TextStyle(fontWeight: FontWeight.w600, color: color),
            ),
            Text(
              _formatDate(item.transactionDate),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasFilter});

  final bool hasFilter;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inbox_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(
              hasFilter
                  ? 'No transactions match this filter.'
                  : 'No transactions found.',
            ),
            if (!hasFilter) const Text('Start by importing SMS transactions.'),
          ],
        ),
      ),
    );
  }
}
