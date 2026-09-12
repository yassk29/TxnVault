import 'package:drift/drift.dart';

/// Stores card metadata only. Never store CVV or full card number.
class Cards extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get bankName => text()();
  TextColumn get cardName => text().nullable()();
  TextColumn get lastFourDigits => text()();
  TextColumn get cardType => text()();
  IntColumn get billingCycleDay => integer().nullable()();
  IntColumn get dueDay => integer().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
