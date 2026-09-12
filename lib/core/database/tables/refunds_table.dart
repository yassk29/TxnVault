import 'package:drift/drift.dart';

import 'transactions_table.dart';

/// refundStatus: INITIATED | RECEIVED | DELAYED
class Refunds extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().references(Transactions, #id)();
  RealColumn get refundAmount => real()();
  TextColumn get refundStatus => text()();
  DateTimeColumn get expectedRefundDate => dateTime().nullable()();
  DateTimeColumn get refundReceivedDate => dateTime().nullable()();
  TextColumn get notes => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
