import 'parsed_transaction.dart';

/// A parser claims a message via [canHandle], then [parse] either returns a
/// [ParsedTransaction] or null. Returning null after claiming the message
/// (rather than not claiming it at all) means "recognized format, but not a
/// money-movement event" - the registry then tries [parseAutopayEvent]
/// before finally falling back to "ignored". Most parsers have no autopay
/// formats and can rely on the default (no-op) implementation here.
abstract class SmsParser {
  String get id;

  bool canHandle(String sender, String body);

  ParsedTransaction? parse(String body, DateTime receivedAt);

  ParsedAutopayEvent? parseAutopayEvent(String body, DateTime receivedAt) => null;
}
