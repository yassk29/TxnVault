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
                            result.success(readSmsInbox())
                        } catch (e: Exception) {
                            result.error("READ_SMS_FAILED", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun readSmsInbox(): List<Map<String, Any?>> {
        val messages = mutableListOf<Map<String, Any?>>()
        val projection = arrayOf(
            Telephony.Sms.ADDRESS,
            Telephony.Sms.BODY,
            Telephony.Sms.DATE,
        )
        contentResolver.query(
            Telephony.Sms.Inbox.CONTENT_URI,
            projection,
            null,
            null,
            "${Telephony.Sms.DATE} DESC",
        )?.use { cursor ->
            val addressIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.ADDRESS)
            val bodyIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.BODY)
            val dateIndex = cursor.getColumnIndexOrThrow(Telephony.Sms.DATE)
            while (cursor.moveToNext()) {
                messages.add(
                    mapOf(
                        "address" to (cursor.getString(addressIndex) ?: "unknown"),
                        "body" to (cursor.getString(bodyIndex) ?: ""),
                        "date" to cursor.getLong(dateIndex),
                    )
                )
            }
        }
        return messages
    }
}
