package com.dawood.baqati

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.provider.Telephony

/**
 * Receives carrier SMS and forwards complete messages to Dart.
 *
 * Parsing and persistence happen on the Dart side, so this does no database
 * work and therefore needs no `goAsync()` — unlike the Kotlin original, which
 * correctly used it because it inserted into Room here.
 */
class SmsReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Telephony.Sms.Intents.SMS_RECEIVED_ACTION) return

        val messages = Telephony.Sms.Intents.getMessagesFromIntent(intent) ?: return
        if (messages.isEmpty()) return

        val first = messages[0]
        val sender = first.displayOriginatingAddress ?: first.originatingAddress

        // PORT-FIX: the Kotlin accepted any sender *containing* "111", so an
        // ordinary number like +96777111234 passed the filter.
        if (!SmsBridge.isCarrierSender(sender)) return

        // PORT-FIX: getMessagesFromIntent returns one SmsMessage PER PDU SEGMENT.
        // The Kotlin parsed each segment independently, so a long carrier message
        // split across parts had its keyword and its numbers land in different
        // fragments and matched nothing — those messages silently produced no
        // event on live receipt, and only ever appeared after a manual re-sync
        // (the inbox provider stores multipart bodies already joined).
        val body = messages.joinToString(separator = "") {
            it.displayMessageBody ?: it.messageBody ?: ""
        }
        if (body.isBlank()) return

        SmsBridge.emit(body, first.timestampMillis)
    }
}
