enum TransactionTypeFilter { all, credit, debit, refund, repayment }

/// Date range is deliberately NOT part of this filter - see
/// shared/providers/date_filter_provider.dart. It's a single filter shared
/// between the Dashboard and this screen, so picking a range on either
/// scopes both automatically.
class TransactionFilter {
  const TransactionFilter({
    this.minAmount,
    this.maxAmount,
    this.type = TransactionTypeFilter.all,
    this.paymentMethodType,
    this.upiProvider,
    this.cardId,
  });

  final double? minAmount;
  final double? maxAmount;
  final TransactionTypeFilter type;

  /// 'UPI' | 'CREDIT_CARD' | 'DEBIT_CARD' | 'BANK_TRANSFER' | null (any)
  final String? paymentMethodType;

  /// Only meaningful when paymentMethodType == 'UPI'.
  final String? upiProvider;

  /// Only meaningful when paymentMethodType is a card type.
  final int? cardId;

  bool get isActive =>
      minAmount != null ||
      maxAmount != null ||
      type != TransactionTypeFilter.all ||
      paymentMethodType != null;

  TransactionFilter copyWith({
    double? minAmount,
    double? maxAmount,
    bool clearAmounts = false,
    TransactionTypeFilter? type,
    String? paymentMethodType,
    bool clearPaymentMethodType = false,
    String? upiProvider,
    bool clearUpiProvider = false,
    int? cardId,
    bool clearCardId = false,
  }) {
    return TransactionFilter(
      minAmount: clearAmounts ? null : (minAmount ?? this.minAmount),
      maxAmount: clearAmounts ? null : (maxAmount ?? this.maxAmount),
      type: type ?? this.type,
      paymentMethodType: clearPaymentMethodType
          ? null
          : (paymentMethodType ?? this.paymentMethodType),
      upiProvider:
          clearUpiProvider ? null : (upiProvider ?? this.upiProvider),
      cardId: clearCardId ? null : (cardId ?? this.cardId),
    );
  }
}
