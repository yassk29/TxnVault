import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sms/sms_status_provider.dart';
import '../../../../shared/providers/app_settings_provider.dart';
import '../widgets/manual_categorize_sheet.dart';

/// Lets a user see exactly which SMS were recognized-but-not-a-transaction
/// (bill reminders, mandate notices, etc.) or not recognized by any parser
/// yet, rather than just being shown an unexplained gap between "N captured"
/// and "M transactions parsed". Swipe an entry away to dismiss it from
/// review (reversible - see the "Dismissed" tab); tap it to categorize it
/// manually.
class SmsReviewScreen extends StatelessWidget {
  const SmsReviewScreen({super.key, required this.initialTab});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('SMS Review'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Not a transaction'),
            Tab(text: 'Not recognized'),
            Tab(text: 'Dismissed'),
          ]),
        ),
        body: const TabBarView(children: [
          _SmsList(status: 'ignored', emptyText: 'Nothing ignored.'),
          _SmsList(status: 'unmatched', emptyText: 'Nothing unrecognized.'),
          _DismissedList(),
        ]),
      ),
    );
  }
}

class _SmsList extends ConsumerWidget {
  const _SmsList({required this.status, required this.emptyText});

  final String status;
  final String emptyText;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(smsMessagesByStatusProvider(status));

    return messages.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (rows) {
        if (rows.isEmpty) return Center(child: Text(emptyText));
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) => _SmsTile(rows[index]),
        );
      },
    );
  }
}

class _SmsTile extends ConsumerWidget {
  const _SmsTile(this.sms);

  final SmsMessage sms;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey(sms.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Theme.of(context).colorScheme.errorContainer,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Icon(Icons.visibility_off_outlined,
            color: Theme.of(context).colorScheme.onErrorContainer),
      ),
      confirmDismiss: (_) async {
        if (await readHintFlag(ref, skipDismissSmsConfirmKey)) return true;
        if (!context.mounted) return false;

        var dontAskAgain = false;
        final confirmed = await showDialog<bool>(
              context: context,
              builder: (context) => StatefulBuilder(
                builder: (context, setState) => AlertDialog(
                  title: const Text('Dismiss this SMS?'),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'It\'ll be hidden from review and the Dashboard '
                        'count. You can restore it anytime from the '
                        '"Dismissed" tab.',
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
                        child: const Text('Cancel')),
                    FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text('Dismiss')),
                  ],
                ),
              ),
            ) ??
            false;

        if (confirmed && dontAskAgain) {
          await markHintSeen(ref, skipDismissSmsConfirmKey);
        }
        return confirmed;
      },
      onDismissed: (_) {
        dismissSmsMessage(ref, sms.id);
        final messenger = ScaffoldMessenger.of(context);
        messenger
          ..clearSnackBars()
          ..showSnackBar(
            SnackBar(
              content: const Text('SMS dismissed'),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  restoreSmsMessage(ref, sms.id);
                  messenger.hideCurrentSnackBar();
                },
              ),
            ),
          );
      },
      child: ListTile(
        title: Text(sms.sender, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sms.messageBody, maxLines: 3, overflow: TextOverflow.ellipsis),
        isThreeLine: true,
        trailing: const Icon(Icons.edit_outlined),
        onTap: () => showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          builder: (_) => ManualCategorizeSheet(sms: sms),
        ),
      ),
    );
  }
}

class _DismissedList extends ConsumerWidget {
  const _DismissedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(dismissedSmsMessagesProvider);

    return messages.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => Center(child: Text('Error: $err')),
      data: (rows) {
        if (rows.isEmpty) return const Center(child: Text('Nothing dismissed.'));
        return ListView.separated(
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(height: 1),
          itemBuilder: (context, index) {
            final sms = rows[index];
            return ListTile(
              title:
                  Text(sms.sender, style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle:
                  Text(sms.messageBody, maxLines: 2, overflow: TextOverflow.ellipsis),
              isThreeLine: true,
              trailing: TextButton(
                onPressed: () => restoreSmsMessage(ref, sms.id),
                child: const Text('Restore'),
              ),
            );
          },
        );
      },
    );
  }
}
