package com.txnvault.txnvault

/**
 * Mirrors lib/core/database/tables/sms_messages_table.dart exactly (column
 * names, types, defaults). Drift stores DateTime as unix seconds (INTEGER),
 * not milliseconds - see drift's DateTime <-> int mapping.
 *
 * Kept in sync manually because native code (SmsReceiver) writes into this
 * table directly, bypassing Drift, so the app can capture SMS even when the
 * Flutter engine isn't running.
 */
object SmsSchema {
    const val DB_NAME = "txnvault.sqlite"

    const val CREATE_TABLE_IF_NOT_EXISTS = """
        CREATE TABLE IF NOT EXISTS sms_messages (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            sender TEXT NOT NULL,
            message_body TEXT NOT NULL,
            received_at INTEGER NOT NULL,
            is_parsed INTEGER NOT NULL DEFAULT 0 CHECK (is_parsed IN (0, 1)),
            parse_status TEXT,
            created_at INTEGER NOT NULL
        )
    """
}
