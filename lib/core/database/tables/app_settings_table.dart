import 'package:drift/drift.dart';

class AppSettings extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get settingKey => text().unique()();
  TextColumn get settingValue => text()();
  DateTimeColumn get updatedAt => dateTime().withDefault(currentDateAndTime)();
}
