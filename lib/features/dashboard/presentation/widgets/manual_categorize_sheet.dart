import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/sms/parser/parsed_transaction.dart';
import '../../../../core/sms/sms_status_provider.dart';
import '../../../transactions/providers/transactions_providers.dart';

enum _ManualChoice { transaction, autopayCreated, autopayRevoked }

/// Lets a user fix a message the parsers got wrong - move an "ignored" or
/// "unmatched" SMS into an actual transaction or autopay reference event,
/// since no set of regex parsers will ever cover every bank format.
class ManualCategorizeSheet extends ConsumerStatefulWidget {
  const ManualCategorizeSheet({super.key, required this.sms});

  final SmsMessage sms;

  @override
  ConsumerState<ManualCategorizeSheet> createState() =>
      _ManualCategorizeSheetState();
}

class _ManualCategorizeSheetState extends ConsumerState<ManualCategorizeSheet> {
  _ManualChoice _choice = _ManualChoice.transaction;
  TransactionDirection _direction = TransactionDirection.debit;
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();
    _merchantController = TextEditingController();
    _date = widget.sms.receivedAt;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Categorize this SMS',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(widget.sms.messageBody,
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              const SizedBox(height: 16),
              SegmentedButton<_ManualChoice>(
                segments: const [
                  ButtonSegment(
                      value: _ManualChoice.transaction, label: Text('Transaction')),
                  ButtonSegment(
                      value: _ManualChoice.autopayCreated,
                      label: Text('Autopay set up')),
                  ButtonSegment(
                      value: _ManualChoice.autopayRevoked,
                      label: Text('Autopay cancelled')),
                ],
                selected: {_choice},
                onSelectionChanged: (s) => setState(() => _choice = s.first),
              ),
              const SizedBox(height: 16),
              if (_choice == _ManualChoice.transaction) ...[
                SegmentedButton<TransactionDirection>(
                  segments: const [
                    ButtonSegment(
                        value: TransactionDirection.debit, label: Text('Debit')),
                    ButtonSegment(
                        value: TransactionDirection.credit, label: Text('Credit')),
                  ],
                  selected: {_direction},
                  onSelectionChanged: (s) => setState(() => _direction = s.first),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Amount ₹'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _merchantController,
                decoration: InputDecoration(
                  labelText: _choice == _ManualChoice.transaction
                      ? 'Merchant (optional)'
                      : 'Merchant',
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Date: ${_date.day}/${_date.month}/${_date.year}'),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2015),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
              const SizedBox(height: 8),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }
    if (_choice != _ManualChoice.transaction &&
        _merchantController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter a merchant name')));
      return;
    }

    setState(() => _saving = true);
    final service = ref.read(transactionIngestServiceProvider);

    if (_choice == _ManualChoice.transaction) {
      await service.createManualTransaction(
        smsMessageId: widget.sms.id,
        smsBody: widget.sms.messageBody,
        amount: amount,
        direction: _direction,
        category: _direction == TransactionDirection.credit
            ? TransactionKind.income
            : TransactionKind.spend,
        merchantName: _merchantController.text.trim().isEmpty
            ? null
            : _merchantController.text.trim(),
        bankName: widget.sms.sender,
        transactionDate: _date,
        smsReceivedAt: widget.sms.receivedAt,
      );
    } else {
      await service.createManualAutopayEvent(
        smsMessageId: widget.sms.id,
        smsBody: widget.sms.messageBody,
        eventType: _choice == _ManualChoice.autopayCreated
            ? AutopayEventType.created
            : AutopayEventType.revoked,
        merchantName: _merchantController.text.trim(),
        amount: amount,
        bankName: widget.sms.sender,
        eventDate: _date,
      );
    }

    ref.invalidate(smsMessagesByStatusProvider);
    ref.invalidate(smsStatusCountsProvider);
    ref.invalidate(transactionsListProvider);
    ref.invalidate(autopayEventsProvider);

    if (mounted) Navigator.of(context).pop();
  }
}
