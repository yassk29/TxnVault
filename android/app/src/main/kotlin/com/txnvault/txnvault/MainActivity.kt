package com.txnvault.txnvault

import android.provider.Telephony
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.txnvault.txnvault/native"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDatabasePath" -> {
                        result.success(getDatabasePath(SmsSchema.DB_NAME).absolutePath)
                    }
                    "readSmsInbox" -> {
                        try {
                            val sinceMillis = call.argument<Long>("sinceMillis")
                            result.success(readSmsInbox(sinceMillis))
                        } catch (e: Exception) {
                            result.error("READ_SMS_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /// [sinceMillis], when provided, limits the query to messages received on
    /// or after that time - lets the user choose how far back to sync
    /// (Last 7 days / This month / etc.) instead of always pulling the whole
    /// SMS history, which can be years' worth of messages.
    private fun readSmsInbox(sinceMillis: Long?): List<Map<String, Any?>> {
        val messages = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
        )
        val selection = if (sinceMillis != null) "${Telephony.Sms.DATE} >= ?" else null
        val selectionArgs = if (sinceMillis != null) arrayOf(sinceMillis.toString()) else null
        contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            projection,
            selection,
            selectionArgs,
            "${Telephony.Sms.DATE} DESC",
        )?.use { cursor ->
            val addressIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val bodyIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val dateIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)
            while (cursor.moveToNext()) {
                val body = cursor.getString(bodyIndex) ?: ""
                if (!SmsRelevanceFilter.isRelevant(body)) continue
                messages.add(
                    mapOf(
                        "address" to (cursor.getString(addressIndex) ?: "unknown"),
                        "body" to body,
                        "date" to cursor.getLong(dateIndex),
                    )
                )
            }
        }
        return messages
    }
}
