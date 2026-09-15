enum TransactionDirection { debit, credit }

enum PaymentMethodType { upi, creditCard, debitCard, bankTransfer }

/// SPEND/INCOME are the default for debit/credit respectively (see
/// TransactionIngestService); repayment - paying off a credit card or loan
/// bill - is neither a purchase nor income, so parsers that recognize a
/// repayment-shaped message set this explicitly.
enum TransactionKind { spend, income, repayment }

/// Output of a successful parse. Not a DB row yet - TransactionIngestService
/// maps this into merchants/payment_methods/cards/transactions rows.
class ParsedTransaction {
  const ParsedTransaction({
    required this.amount,
    required this.direction,
    required this.bankName,
    required this.paymentMethodType,
    required this.transactionDate,
    this.cardOrAccountLastFour,
    this.counterparty,
    this.referenceId,
    this.availableBalanceOrLimit,
    this.description,
    this.category,
  });

  final double amount;
  final TransactionDirection direction;
  final String bankName;
  final PaymentMethodType paymentMethodType;
  final DateTime transactionDate;
  final String? cardOrAccountLastFour;
  final String? counterparty;
  final String? referenceId;
  final double? availableBalanceOrLimit;
  final String? description;

  /// Null means "derive from direction" - see TransactionIngestService.
  final TransactionKind? category;
}

enum AutopayEventType { created, revoked }

/// A UPI AutoPay / mandate lifecycle event - reference-only, never becomes a
/// transaction (no money moves when a mandate is set up or cancelled).
class ParsedAutopayEvent {
  const ParsedAutopayEvent({
    required this.eventType,
    required this.merchantName,
    required this.amount,
    required this.bankName,
    required this.eventDate,
    this.referenceId,
  });

  final AutopayEventType eventType;
  final String merchantName;
  final double amount;
  final String bankName;
  final DateTime eventDate;
  final String? referenceId;
}
