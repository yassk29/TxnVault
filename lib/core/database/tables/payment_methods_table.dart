import 'package:drift/drift.dart';

/// type: UPI | CREDIT_CARD | DEBIT_CARD | CASH
class PaymentMethods extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get type => text()();
  TextColumn get provider => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
