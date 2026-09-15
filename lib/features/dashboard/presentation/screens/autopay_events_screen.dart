import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sms/sms_status_provider.dart';
import '../../../../shared/helpers/currency_formatter.dart';

const _months = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

String _formatDate(DateTime dt) => '${dt.day} ${_months[dt.month - 1]} ${dt.year}';

/// Reference log of UPI AutoPay / mandate lifecycle events - deliberately
/// separate from the Transactions list, since setting up or cancelling a
/// mandate isn't a money movement.
class AutopayEventsScreen extends ConsumerWidget {
  const AutopayEventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final events = ref.watch(autopayEventsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Autopay Reference')),
      body: events.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (rows) {
          if (rows.isEmpty) {
            return const Center(child: Text('No autopay activity seen yet.'));
          }
          return ListView.separated(
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, index) => _AutopayTile(rows[index]),
          );
        },
      ),
    );
  }
}

class _AutopayTile extends StatelessWidget {
  const _AutopayTile(this.event);

  final AutopayEvent event;

  @override
  Widget build(BuildContext context) {
    final isCreated = event.eventType == 'CREATED';
    return ListTile(
      leading: Icon(
        isCreated ? Icons.autorenew : Icons.block,
        color: isCreated ? Colors.blue : Colors.grey,
      ),
      title: Text(event.merchantName),
      subtitle: Text('${isCreated ? 'Set up' : 'Cancelled'} · ${event.bankName}'),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(formatIndianCurrency(event.amount),
              style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(_formatDate(event.eventDate),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}
