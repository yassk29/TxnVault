import 'package:drift/drift.dart';

import 'merchants_table.dart';
import 'payment_methods_table.dart';
import 'cards_table.dart';

/// status: SUCCESS | FAILED | REFUND_REQUESTED | REFUND_INITIATED |
/// REFUND_RECEIVED | REFUND_DELAYED | REVERSAL_PENDING | REVERSED
class Transactions extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get externalTransactionId => text().nullable()();
  IntColumn get merchantId => integer().nullable().references(Merchants, #id)();
  IntColumn get paymentMethodId =>
      integer().nullable().references(PaymentMethods, #id)();
  IntColumn get cardId => integer().nullable().references(Cards, #id)();
  RealColumn get amount => real()();
  TextColumn get currency => text().withDefault(const Constant('INR'))();
  DateTimeColumn get transactionDate => dateTime()();
  TextColumn get status => text()();
  TextColumn get bankName => text().nullable()();
  TextColumn get description => text().nullable()();
  TextColumn get smsSource => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
