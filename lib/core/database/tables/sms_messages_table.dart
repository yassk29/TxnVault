import 'package:drift/drift.dart';

/// Stores raw + parsed SMS history for the parser pipeline.
class SmsMessages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sender => text()();
  TextColumn get messageBody => text()();
  DateTimeColumn get receivedAt => dateTime()();
  BoolColumn get isParsed => boolean().withDefault(const Constant(false))();
  TextColumn get parseStatus => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}
