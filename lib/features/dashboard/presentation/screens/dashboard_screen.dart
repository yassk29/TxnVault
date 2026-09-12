import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/sms/sms_providers.dart';

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
                if (granted) {
                  await ref.read(smsSyncServiceProvider).syncInboxHistory();
                  ref.invalidate(smsMessagesProvider);
                }
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
    final messages = ref.watch(smsMessagesProvider);

    return messages.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (rows) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            '${rows.length} SMS captured.\n\n'
            'Total Spend, Pending Refunds and Recent Transactions '
            'will appear here once parsing is implemented.',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
