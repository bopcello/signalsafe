package com.example.signalsafe

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import android.os.Build
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.util.ArrayList

class MainActivity : FlutterActivity() {

    private val VPN_CHANNEL = "com.example.signalsafe/vpn"
    private val VPN_EVENTS_CHANNEL = "com.example.signalsafe/vpn_events"
    private val VPN_REQUEST_CODE = 4410

    private var pendingVpnResult: MethodChannel.Result? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // MethodChannel for VPN controls
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VPN_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "prepareVpn" -> {
                    val prepareIntent = VpnService.prepare(this)
                    if (prepareIntent != null) {
                        pendingVpnResult = result
                        startActivityForResult(prepareIntent, VPN_REQUEST_CODE)
                    } else {
                        // Already prepared & permitted
                        result.success(true)
                    }
                }
                "startVpn" -> {
                    val domains = call.argument<List<String>>("blockedDomains") ?: emptyList()
                    val serviceIntent = Intent(this, SignalSafeVpnService::class.java).apply {
                        action = SignalSafeVpnService.ACTION_START
                        putStringArrayListExtra(
                            SignalSafeVpnService.EXTRA_BLOCKED_DOMAINS,
                            ArrayList(domains)
                        )
                    }
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        startForegroundService(serviceIntent)
                    } else {
                        startService(serviceIntent)
                    }
                    result.success(true)
                }
                "stopVpn" -> {
                    val serviceIntent = Intent(this, SignalSafeVpnService::class.java).apply {
                        action = SignalSafeVpnService.ACTION_STOP
                    }
                    startService(serviceIntent)
                    result.success(true)
                }
                "isVpnRunning" -> {
                    result.success(SignalSafeVpnService.isRunning)
                }
                "updateBlocklist" -> {
                    val domains = call.argument<List<String>>("blockedDomains") ?: emptyList()
                    val serviceIntent = Intent(this, SignalSafeVpnService::class.java).apply {
                        action = SignalSafeVpnService.ACTION_UPDATE_BLOCKLIST
                        putStringArrayListExtra(
                            SignalSafeVpnService.EXTRA_BLOCKED_DOMAINS,
                            ArrayList(domains)
                        )
                    }
                    startService(serviceIntent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // EventChannel for streaming live DNS blocks, resolved queries, and VPN status
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, VPN_EVENTS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events

                    SignalSafeVpnService.onDnsEventListener = { event ->
                        mainHandler.post {
                            eventSink?.success(event)
                        }
                    }

                    SignalSafeVpnService.onStatusChangeListener = { isRunning ->
                        mainHandler.post {
                            eventSink?.success(
                                mapOf(
                                    "type" to "status",
                                    "isRunning" to isRunning
                                )
                            )
                        }
                    }

                    // Send initial status immediately upon listen
                    events?.success(
                        mapOf(
                            "type" to "status",
                            "isRunning" to SignalSafeVpnService.isRunning
                        )
                    )
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                    SignalSafeVpnService.onDnsEventListener = null
                    SignalSafeVpnService.onStatusChangeListener = null
                }
            }
        )
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == VPN_REQUEST_CODE) {
            val granted = (resultCode == Activity.RESULT_OK)
            pendingVpnResult?.success(granted)
            pendingVpnResult = null
        }
    }
}
