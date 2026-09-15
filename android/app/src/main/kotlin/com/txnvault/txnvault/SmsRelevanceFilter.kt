package com.txnvault.txnvault

/**
 * Decides whether an SMS is worth storing at all.
 *
 * Two earlier, stricter passes (currency+keyword, then currency+reference
 * marker) both ended up excluding real transaction SMS the parsers could
 * have recognized - the user explicitly wants every captured SMS visible
 * and triaged (parsed / autopay reference / recognized-not-a-transaction /
 * not-yet-recognized) rather than silently dropped before it's even stored,
 * with manual recategorization available for anything a parser misses.
 *
 * So this now captures everything, with exactly one exception: OTP-shaped
 * messages, per the app's own "never store OTP/PIN/CVV/password" rule -
 * that's a security requirement, not a parsing heuristic, and doesn't
 * belong in sms_messages even transiently.
 *
 * Applied natively, before a row is ever written - by SmsReceiver (live
 * capture) and MainActivity.readSmsInbox (historical backfill).
 */
object SmsRelevanceFilter {
    private val excludeKeywords = listOf(
        "otp", "one time password", "verification code", "verification pin",
    )

    fun isRelevant(body: String): Boolean {
        return excludeKeywords.none { body.contains(it, ignoreCase = true) }
    }
}
