import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/providers/date_filter_provider.dart';
import '../../../../shared/widgets/date_filter_capsule.dart';
import '../../domain/transaction_filter.dart';
import '../../providers/transactions_providers.dart';

String _typeLabel(TransactionTypeFilter type) => switch (type) {
      TransactionTypeFilter.all => 'All',
      TransactionTypeFilter.credit => 'Credit',
      TransactionTypeFilter.debit => 'Debit',
      TransactionTypeFilter.refund => 'Refund',
      TransactionTypeFilter.repayment => 'Repayment',
    };

String _paymentMethodLabel(String? type) => switch (type) {
      null => 'Payment Method',
      'UPI' => 'UPI',
      'CREDIT_CARD' => 'Credit Card',
      'DEBIT_CARD' => 'Debit Card',
      'BANK_TRANSFER' => 'Bank Transfer',
      _ => 'Payment Method',
    };

/// A row of capsule chips (Date / Amount / Type / Payment Method), each
/// opening its own focused bottom sheet rather than one long combined form.
class TransactionFilterBar extends ConsumerWidget {
  const TransactionFilterBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(transactionFilterProvider);
    final dateFilter = ref.watch(sharedDateFilterProvider);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const DateFilterCapsule(),
          const SizedBox(width: 8),
          _FilterCapsule(
            label: 'Amount',
            value: (filter.minAmount == null && filter.maxAmount == null)
                ? null
                : '₹${filter.minAmount?.toStringAsFixed(0) ?? '0'}-${filter.maxAmount?.toStringAsFixed(0) ?? '∞'}',
            active: filter.minAmount != null || filter.maxAmount != null,
            onTap: () => _open(context, const _AmountFilterSheet()),
          ),
          const SizedBox(width: 8),
          _FilterCapsule(
            label: 'Type',
            value: filter.type == TransactionTypeFilter.all
                ? null
                : _typeLabel(filter.type),
            active: filter.type != TransactionTypeFilter.all,
            onTap: () => _open(context, const _TypeFilterSheet()),
          ),
          const SizedBox(width: 8),
          _FilterCapsule(
            label: 'Payment Method',
            value: filter.paymentMethodType == null
                ? null
                : _paymentMethodLabel(filter.paymentMethodType),
            active: filter.paymentMethodType != null,
            onTap: () => _open(context, const _PaymentMethodFilterSheet()),
          ),
          if (filter.isActive || dateFilter.isActive) ...[
            const SizedBox(width: 8),
            ActionChip(
              avatar: const Icon(Icons.close, size: 16),
              label: const Text('Clear'),
              onPressed: () {
                ref.read(transactionFilterProvider.notifier).state =
                    const TransactionFilter();
                ref.read(sharedDateFilterProvider.notifier).state =
                    const SharedDateFilter();
              },
            ),
          ],
        ],
      ),
    );
  }

  void _open(BuildContext context, Widget sheet) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => sheet,
    );
  }
}

class _FilterCapsule extends StatelessWidget {
  const _FilterCapsule({
    required this.label,
    required this.value,
    required this.active,
    required this.onTap,
  });

  final String label;
  final String? value;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? scheme.primaryContainer : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value ?? label,
              style: TextStyle(
                color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                fontWeight: active ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
            const SizedBox(width: 2),
            Icon(Icons.arrow_drop_down,
                size: 18,
                color: active ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}

/// Every filter sheet uses this same row style: a title, and either a
/// trailing check (this is the currently active leaf choice) or a trailing
/// chevron (tapping drills into a sub-list) - never a mix of radio buttons
/// and chevron rows, which read as two different UI languages in the same
/// sheet.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.title,
    required this.onTap,
    this.selected = false,
    this.drillDown = false,
  });

  final String title;
  final VoidCallback onTap;
  final bool selected;
  final bool drillDown;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: drillDown
          ? const Icon(Icons.chevron_right)
          : (selected
              ? Icon(Icons.check, color: Theme.of(context).colorScheme.primary)
              : null),
      onTap: onTap,
    );
  }
}

/// Bounds sheet height (so long lists scroll instead of overflowing the
/// screen) and keeps every sheet's shell consistent.
class _SheetShell extends StatelessWidget {
  const _SheetShell({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
        child: ListView(shrinkWrap: true, children: children),
      ),
    );
  }
}

class _SheetHeader extends StatelessWidget {
  const _SheetHeader(this.title, {this.onBack});

  final String title;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: onBack == null
          ? null
          : IconButton(icon: const Icon(Icons.arrow_back), onPressed: onBack),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class _AmountFilterSheet extends ConsumerStatefulWidget {
  const _AmountFilterSheet();

  @override
  ConsumerState<_AmountFilterSheet> createState() => _AmountFilterSheetState();
}

class _AmountFilterSheetState extends ConsumerState<_AmountFilterSheet> {
  late final TextEditingController _minController;
  late final TextEditingController _maxController;

  @override
  void initState() {
    super.initState();
    final filter = ref.read(transactionFilterProvider);
    _minController =
        TextEditingController(text: filter.minAmount?.toStringAsFixed(0) ?? '');
    _maxController =
        TextEditingController(text: filter.maxAmount?.toStringAsFixed(0) ?? '');
  }

  @override
  void dispose() {
    _minController.dispose();
    _maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
            16, 8, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Amount Range', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Min ₹'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _maxController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Max ₹'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () {
                      final current = ref.read(transactionFilterProvider);
                      ref.read(transactionFilterProvider.notifier).state =
                          current.copyWith(clearAmounts: true);
                      Navigator.of(context).pop();
                    },
                    child: const Text('Clear'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () {
                      final current = ref.read(transactionFilterProvider);
                      ref.read(transactionFilterProvider.notifier).state =
                          TransactionFilter(
                        minAmount: double.tryParse(_minController.text.trim()),
                        maxAmount: double.tryParse(_maxController.text.trim()),
                        type: current.type,
                        paymentMethodType: current.paymentMethodType,
                        upiProvider: current.upiProvider,
                        cardId: current.cardId,
                      );
                      Navigator.of(context).pop();
                    },
                    child: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeFilterSheet extends ConsumerWidget {
  const _TypeFilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filter = ref.watch(transactionFilterProvider);
    return _SheetShell(children: [
      const _SheetHeader('Type'),
      for (final type in TransactionTypeFilter.values)
        _OptionTile(
          title: _typeLabel(type),
          selected: filter.type == type,
          onTap: () {
            ref.read(transactionFilterProvider.notifier).state =
                filter.copyWith(type: type);
            Navigator.of(context).pop();
          },
        ),
    ]);
  }
}

class _PaymentMethodFilterSheet extends ConsumerStatefulWidget {
  const _PaymentMethodFilterSheet();

  @override
  ConsumerState<_PaymentMethodFilterSheet> createState() =>
      _PaymentMethodFilterSheetState();
}

class _PaymentMethodFilterSheetState
    extends ConsumerState<_PaymentMethodFilterSheet> {
  // null = showing the top-level type list; otherwise drilled into a
  // provider/card sub-list for that type.
  String? _drilledType;

  void _apply(TransactionFilter Function(TransactionFilter) update) {
    final current = ref.read(transactionFilterProvider);
    ref.read(transactionFilterProvider.notifier).state = update(current);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_drilledType == 'UPI') return _buildUpiList(context);
    if (_drilledType == 'CREDIT_CARD' || _drilledType == 'DEBIT_CARD') {
      return _buildCardList(context, _drilledType!);
    }
    return _buildTypeList(context);
  }

  Widget _buildTypeList(BuildContext context) {
    final filter = ref.watch(transactionFilterProvider);
    return _SheetShell(children: [
      const _SheetHeader('Payment Method'),
      _OptionTile(
        title: 'All',
        selected: filter.paymentMethodType == null,
        onTap: () => _apply((f) => f.copyWith(
            clearPaymentMethodType: true,
            clearUpiProvider: true,
            clearCardId: true)),
      ),
      _OptionTile(
        title: 'UPI',
        drillDown: true,
        onTap: () => setState(() => _drilledType = 'UPI'),
      ),
      _OptionTile(
        title: 'Credit Card',
        drillDown: true,
        onTap: () => setState(() => _drilledType = 'CREDIT_CARD'),
      ),
      _OptionTile(
        title: 'Debit Card',
        drillDown: true,
        onTap: () => setState(() => _drilledType = 'DEBIT_CARD'),
      ),
      _OptionTile(
        title: 'Bank Transfer',
        selected: filter.paymentMethodType == 'BANK_TRANSFER',
        onTap: () => _apply((f) => f.copyWith(
            paymentMethodType: 'BANK_TRANSFER',
            clearUpiProvider: true,
            clearCardId: true)),
      ),
    ]);
  }

  Widget _buildUpiList(BuildContext context) {
    final providersAsync = ref.watch(availableUpiProvidersProvider);
    return _SheetShell(children: [
      _SheetHeader('UPI Provider', onBack: () => setState(() => _drilledType = null)),
      _OptionTile(
        title: 'Any UPI provider',
        onTap: () => _apply((f) => f.copyWith(
            paymentMethodType: 'UPI', clearUpiProvider: true, clearCardId: true)),
      ),
      providersAsync.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
        error: (e, _) =>
            Padding(padding: const EdgeInsets.all(16), child: Text('Error: $e')),
        data: (providers) => Column(
          children: [
            for (final p in providers)
              _OptionTile(
                title: p,
                onTap: () => _apply((f) => f.copyWith(
                    paymentMethodType: 'UPI', upiProvider: p, clearCardId: true)),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _buildCardList(BuildContext context, String type) {
    final cardsAsync = ref.watch(availableCardsProvider);
    final wantType = type == 'CREDIT_CARD' ? 'CREDIT' : 'DEBIT';
    return _SheetShell(children: [
      _SheetHeader(type == 'CREDIT_CARD' ? 'Credit Card' : 'Debit Card',
          onBack: () => setState(() => _drilledType = null)),
      _OptionTile(
        title: 'Any ${type == 'CREDIT_CARD' ? 'credit' : 'debit'} card',
        onTap: () => _apply((f) => f.copyWith(
            paymentMethodType: type, clearUpiProvider: true, clearCardId: true)),
      ),
      cardsAsync.when(
        loading: () => const Padding(
            padding: EdgeInsets.all(16), child: LinearProgressIndicator()),
        error: (e, _) =>
            Padding(padding: const EdgeInsets.all(16), child: Text('Error: $e')),
        data: (cards) {
          final filtered = cards.where((c) => c.cardType == wantType).toList();
          if (filtered.isEmpty) {
            return const Padding(
                padding: EdgeInsets.all(16), child: Text('No cards seen yet.'));
          }
          return Column(
            children: [
              for (final c in filtered)
                _OptionTile(
                  title: '${c.bankName} xx${c.lastFourDigits}',
                  onTap: () => _apply((f) => f.copyWith(
                      paymentMethodType: type,
                      cardId: c.id,
                      clearUpiProvider: true)),
                ),
            ],
          );
        },
      ),
    ]);
  }
}
