import 'package:drift/drift.dart';

/// Stores raw + parsed SMS history for the parser pipeline.
///
/// isDismissed: added in schema v6. Lets a user hide a reviewed SMS from the
/// "recognized, not a transaction"/"not yet recognized" lists (and the
/// Dashboard counts) without changing its parseStatus - reversible, mirrors
/// transactions.isExcluded.
class SmsMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sender => text()();
  TextColumn get messageBody => text()();
  DateTimeColumn get receivedAt => dateTime()();
  BoolColumn get isParsed => boolean().withDefault(const Constant(false))();
  TextColumn get parseStatus => text().nullable()();
  BoolColumn get isDismissed => boolean().withDefault(const Constant(false))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
