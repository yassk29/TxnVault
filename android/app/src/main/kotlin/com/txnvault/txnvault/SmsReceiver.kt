package com.txnvault.txnvault

import android.content.BroadcastReceiver
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.sqlite.SQLiteDatabase
import android.provider.Telephony
import android.util.Log

/**
 * Captures incoming SMS and writes them straight into the app's SQLite file,
 * independent of whether the Flutter engine is currently running. Android
 * (especially vendor skins like ColorOS) can kill the app process aggressively,
 * so relying on a live Dart isolate to persist messages isn't reliable.
 *
 * Multi-part (concatenated) SMS arrive as multiple SmsMessage objects sharing
 * the same originating address and timestamp; they're joined into one row.
 */
class SmsReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (messages.isEmpty()) return

        val sender = messages[0].originatingAddress ?: "unknown"
        val body = messages.joinToString(separator = "") { it.messageBody ?: "" }
        val receivedAtSeconds = messages[0].timestampMillis / 1000

        try {
            val dbPath = context.getDatabasePath(SmsSchema.DB_NAME).absolutePath
            val db = SQLiteDatabase.openOrCreateDatabase(dbPath, null)
            db.use {
                it.execSQL(SmsSchema.CREATE_TABLE_IF_NOT_EXISTS)
                val values = ContentValues().apply {
                    put("sender", sender)
                    put("message_body", body)
                    put("received_at", receivedAtSeconds)
                    put("is_parsed", 0)
                    put("created_at", System.currentTimeMillis() / 1000)
                }
                it.insert("sms_messages", null, values)
            }
        } catch (e: Exception) {
            Log.e("SmsReceiver", "Failed to persist incoming SMS", e)
        }
    }
}
