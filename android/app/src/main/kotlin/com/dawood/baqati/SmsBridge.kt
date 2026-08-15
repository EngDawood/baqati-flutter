package com.dawood.baqati

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * Bridges carrier SMS into Dart.
 *
 * Two paths, because a BroadcastReceiver cannot reach Dart when the app process
 * is dead:
 *  - live: [SmsReceiver] pushes newly received messages through the event channel
 *    while the app is running.
 *  - backfill: [readInbox] re-reads the inbox at every app start, so anything
 *    that arrived while the process was dead is still picked up. Dart dedupes by
 *    message hash, which makes repeating this harmless.
 *
 * Permission handling lives here rather than in a plugin: the only permissions
 * this app needs are SMS ones, and the platform APIs for them are available
 * from API 23 upward, well below this app's minSdk of 24.
 */
class SmsBridge(private val activity: Activity, messenger: BinaryMessenger) {

    private val context: Context = activity.applicationContext
    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL)
    private val eventChannel = EventChannel(messenger, EVENT_CHANNEL)

    private var pendingPermissionResult: MethodChannel.Result? = null

    init {
        methodChannel.setMethodCallHandler { call, result ->
            when (call.method) {
                "readInbox" -> result.success(readInbox())
                "hasSmsPermission" -> result.success(hasSmsPermission())
                "requestSmsPermission" -> requestSmsPermission(result)
                else -> result.notImplemented()
            }
        }
        eventChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                sink = events
            }

            override fun onCancel(arguments: Any?) {
                sink = null
            }
        })
    }

    fun dispose() {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        pendingPermissionResult = null
        sink = null
    }

    private fun hasSmsPermission(): Boolean =
        SMS_PERMISSIONS.all {
            context.checkSelfPermission(it) == PackageManager.PERMISSION_GRANTED
        }

    private fun requestSmsPermission(result: MethodChannel.Result) {
        if (hasSmsPermission()) {
            result.success(true)
            return
        }
        if (pendingPermissionResult != null) {
            // A prompt is already on screen; don't stack a second one.
            result.success(false)
            return
        }
        pendingPermissionResult = result
        activity.requestPermissions(SMS_PERMISSIONS, PERMISSION_REQUEST_CODE)
    }

    /** Returns true when this bridge consumed the result. */
    fun onRequestPermissionsResult(requestCode: Int, grantResults: IntArray): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false

        val granted = grantResults.isNotEmpty() &&
            grantResults.all { it == PackageManager.PERMISSION_GRANTED }
        pendingPermissionResult?.success(granted)
        pendingPermissionResult = null
        return true
    }

    private fun readInbox(): List<Map<String, Any>> {
        if (!hasSmsPermission()) return emptyList()

        val results = mutableListOf<Map<String, Any>>()
        try {
            // PORT-FIX: the Kotlin selected with `address = ? OR address LIKE '%111%'`,
            // which also matched ordinary phone numbers containing "111" such as
            // +96777111234. An exact-match allowlist keeps real carrier variants
            // (with and without country code) while excluding coincidental matches.
            val placeholders = SENDER_ALLOWLIST.joinToString(",") { "?" }
            context.contentResolver.query(
                Uri.parse("content://sms/inbox"),
                arrayOf("_id", "address", "body", "date"),
                "address IN ($placeholders)",
                SENDER_ALLOWLIST.toTypedArray(),
                "date DESC LIMIT $INBOX_LIMIT"
            )?.use { cursor ->
                val bodyIndex = cursor.getColumnIndex("body")
                val dateIndex = cursor.getColumnIndex("date")
                while (cursor.moveToNext()) {
                    val body = if (bodyIndex != -1) cursor.getString(bodyIndex) else null
                    if (body.isNullOrBlank()) continue
                    val date =
                        if (dateIndex != -1) cursor.getLong(dateIndex)
                        else System.currentTimeMillis()
                    results.add(mapOf("body" to body, "date" to date))
                }
            }
        } catch (e: Exception) {
            Log.e(TAG, "Failed reading SMS inbox", e)
        }
        return results
    }

    companion object {
        private const val TAG = "SmsBridge"
        const val METHOD_CHANNEL = "baqati/sms"
        const val EVENT_CHANNEL = "baqati/sms_stream"
        private const val INBOX_LIMIT = 100
        private const val PERMISSION_REQUEST_CODE = 4711

        private val SMS_PERMISSIONS = arrayOf(
            Manifest.permission.READ_SMS,
            Manifest.permission.RECEIVE_SMS
        )

        /** Yemen Mobile's short code, with the country-code forms it may arrive as. */
        val SENDER_ALLOWLIST = listOf("111", "+967111", "967111")

        fun isCarrierSender(address: String?): Boolean =
            address != null && SENDER_ALLOWLIST.contains(address.trim())

        private val mainHandler = Handler(Looper.getMainLooper())

        @Volatile
        private var sink: EventChannel.EventSink? = null

        /**
         * Forwards one complete message to Dart.
         *
         * A null sink means no Dart listener is attached — the app is dead or
         * backgrounded past engine teardown. That message is not lost: the
         * backfill query picks it up at next launch.
         */
        fun emit(body: String, dateMillis: Long) {
            val target = sink ?: return
            mainHandler.post {
                target.success(mapOf("body" to body, "date" to dateMillis))
            }
        }
    }
}
