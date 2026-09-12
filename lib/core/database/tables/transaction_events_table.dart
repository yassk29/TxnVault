import 'package:drift/drift.dart';

import 'transactions_table.dart';

/// Tracks lifecycle changes. Timeline can be reconstructed entirely from this table.
class TransactionEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get transactionId => integer().references(Transactions, #id)();
  TextColumn get oldStatus => text().nullable()();
  TextColumn get newStatus => text()();
  DateTimeColumn get eventTimestamp =>
      dateTime().withDefault(currentDateAndTime)();
  TextColumn get remarks => text().nullable()();
}
