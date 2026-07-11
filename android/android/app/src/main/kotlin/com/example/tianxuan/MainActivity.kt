package com.example.tianxuan

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var pendingLink: String? = null
    private var linkStreamHandler: EventChannel.EventSink? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // Capture initial intent (deep link that launched the app)
        intent?.data?.toString()?.let { pendingLink = it }

        val messenger = flutterEngine.dartExecutor.binaryMessenger

        // Method channel: getInitialLink (consumed once)
        MethodChannel(messenger, "com.tianxuan.app/deeplink")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getInitialLink" -> {
                        val link = pendingLink
                        pendingLink = null // consume once
                        result.success(link)
                    }
                    else -> result.notImplemented()
                }
            }

        // Event channel: stream incoming deep links (onNewIntent)
        EventChannel(messenger, "com.tianxuan.app/deeplink/events")
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    linkStreamHandler = events
                }

                override fun onCancel(arguments: Any?) {
                    linkStreamHandler = null
                }
            })
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val data = intent.data?.toString()
        if (data != null) {
            pendingLink = data
            linkStreamHandler?.success(data)
        }
    }
}
