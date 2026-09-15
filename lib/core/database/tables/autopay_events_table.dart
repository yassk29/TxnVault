import 'package:drift/drift.dart';

/// Reference-only log of UPI AutoPay / mandate lifecycle events (created,
/// revoked) - deliberately NOT part of `transactions`, since no money moves
/// when a mandate is set up or cancelled. When a mandate actually executes
/// (money does move), that's a normal transaction row instead.
///
/// eventType: CREATED | REVOKED
class AutopayEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get eventType => text()();
  TextColumn get merchantName => text()();
  RealColumn get amount => real()();
  TextColumn get bankName => text()();
  DateTimeColumn get eventDate => dateTime()();
  TextColumn get referenceId => text().nullable()();
  TextColumn get smsSource => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
