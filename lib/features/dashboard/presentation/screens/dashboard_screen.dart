import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/sms/sms_providers.dart';
import '../../../../core/sms/sms_status_provider.dart';
import '../../../../shared/helpers/currency_formatter.dart';
import '../../../../shared/providers/date_filter_provider.dart';
import '../../../../shared/widgets/date_filter_capsule.dart';
import '../../../transactions/providers/transactions_providers.dart';
import '../../../../shared/widgets/sync_duration_picker.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final permission = ref.watch(smsPermissionStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('TxnVault')),
      body: permission.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (granted) {
          if (!granted) return _PermissionGate(ref: ref);
          return const _DashboardBody();
        },
      ),
    );
  }
}

class _PermissionGate extends StatelessWidget {
  const _PermissionGate({required this.ref});

  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sms_outlined,
                size: 48, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 16),
            const Text(
              'TxnVault needs SMS permission to track transactions automatically.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final granted =
                    await ref.read(smsPermissionServiceProvider).request();
                ref.invalidate(smsPermissionStatusProvider);
                if (!granted) return;

                // Cancelling the picker still syncs everything here (unlike
                // Settings' re-scan) - this is the first-run flow and
                // shouldn't leave the user with nothing synced.
                final choice = context.mounted
                    ? await pickSyncSinceDate(context)
                    : const SyncDepthChoice.since(null);
                await ref
                    .read(smsSyncServiceProvider)
                    .syncInboxHistory(since: choice.since);
                await ref
                    .read(transactionIngestServiceProvider)
                    .ingestUnparsedMessages();
                ref.invalidate(smsMessagesProvider);
                ref.invalidate(transactionsListProvider);
              },
              child: const Text('Grant Permission'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusCounts = ref.watch(smsStatusCountsProvider);
    final transactions = ref.watch(transactionsListProvider);
    final dateFilter = ref.watch(sharedDateFilterProvider);
    final (startDate, endDate) = dateFilter.resolveBounds();

    final scopedTransactions = transactions.valueOrNull?.where((t) {
      if (startDate != null && t.transactionDate.isBefore(startDate)) return false;
      if (endDate != null && !t.transactionDate.isBefore(endDate)) return false;
      return true;
    });

    final totalSpend = scopedTransactions
        ?.where((t) => t.category == 'SPEND')
        .fold<double>(0, (sum, t) => sum + t.amount);
    final totalRepayments = scopedTransactions
        ?.where((t) => t.category == 'REPAYMENT')
        .fold<double>(0, (sum, t) => sum + t.amount);

    return statusCounts.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (counts) {
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Align(alignment: Alignment.centerLeft, child: DateFilterCapsule()),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Spend', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      formatIndianCurrency(totalSpend ?? 0),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text('Repayments', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      formatIndianCurrency(totalRepayments ?? 0),
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text('SMS Breakdown', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              'How every captured SMS has been classified - nothing is '
              'silently dropped.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.check_circle_outline, color: Colors.green),
                    title: const Text('Parsed as transactions'),
                    trailing: Text('${counts.parsed}',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.autorenew, color: Colors.blue),
                    title: const Text('Parsed as Autopay reference'),
                    subtitle: const Text('Mandate set up or cancelled - no money moved'),
                    trailing: Text('${counts.autopayReference}'),
                    onTap: counts.autopayReference == 0
                        ? null
                        : () => context.push('/autopay-events'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.blueGrey),
                    title: const Text('Recognized, not a transaction'),
                    subtitle: const Text('Bill reminders, mandate notices, etc.'),
                    trailing: Text('${counts.ignored}'),
                    onTap: counts.ignored == 0
                        ? null
                        : () => context.push('/sms-review?tab=0'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.help_outline, color: Colors.orange),
                    title: const Text('Not yet recognized'),
                    subtitle: const Text('New bank/format we don\'t parse yet'),
                    trailing: Text('${counts.unmatched}'),
                    onTap: counts.unmatched == 0
                        ? null
                        : () => context.push('/sms-review?tab=1'),
                  ),
                  if (counts.pending > 0) ...[
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.hourglass_empty),
                      title: const Text('Still processing'),
                      trailing: Text('${counts.pending}'),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
