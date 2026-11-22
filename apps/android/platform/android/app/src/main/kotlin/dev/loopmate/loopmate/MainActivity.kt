package dev.loopmate.loopmate

import android.content.ComponentName
import android.content.Intent
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "dev.loopmate.loopmate/automation"
        private val ACTIONS =
            setOf("tap", "swipe_up", "swipe_down", "swipe_left", "swipe_right")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAccessibilityEnabled" -> result.success(isLoopMateAccessibilityEnabled())

                    "openAccessibilitySettings" -> {
                        startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
                        result.success(true)
                    }

                    "startRepeating" -> {
                        if (!isLoopMateAccessibilityEnabled()) {
                            result.error(
                                "ACCESSIBILITY_DISABLED",
                                "Enable LoopMate in Android Accessibility settings first.",
                                null
                            )
                            return@setMethodCallHandler
                        }

                        val action = call.argument<String>("action") ?: "tap"
                        val intervalSeconds = call.argument<Int>("intervalSeconds") ?: 10
                        val xPercent = call.argument<Number>("xPercent")?.toFloat() ?: 50f
                        val yPercent = call.argument<Number>("yPercent")?.toFloat() ?: 50f
                        val repeatCount = call.argument<Int>("repeatCount") ?: 0

                        if (action !in ACTIONS || intervalSeconds < 1 ||
                            repeatCount < 0 || xPercent !in 0f..100f ||
                            yPercent !in 0f..100f
                        ) {
                            result.error("INVALID_CONFIG", "The repeat configuration is invalid.", null)
                            return@setMethodCallHandler
                        }

                        val service = LoopAccessibilityService.instance
                        if (service == null) {
                            result.error(
                                "SERVICE_NOT_CONNECTED",
                                "Android has not connected the accessibility service yet. Reopen the app and try again.",
                                null
                            )
                        } else {
                            service.startLoop(
                                action = action,
                                intervalMillis = intervalSeconds * 1000L,
                                xPercent = xPercent,
                                yPercent = yPercent,
                                repeatCount = repeatCount
                            )
                            result.success(true)
                        }
                    }

                    "stopRepeating" -> {
                        LoopAccessibilityService.instance?.stopLoop()
                        result.success(true)
                    }

                    "getRunState" -> {
                        val service = LoopAccessibilityService.instance
                        result.success(
                            mapOf(
                                "running" to (service?.isLoopRunning() ?: false),
                                "count" to (service?.getExecutionCount() ?: 0),
                                "error" to service?.getLastError()
                            )
                        )
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private fun isLoopMateAccessibilityEnabled(): Boolean {
        val enabledServices = Settings.Secure.getString(
            contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
        ) ?: return false

        val expected = ComponentName(this, LoopAccessibilityService::class.java)
        return enabledServices.split(':').any { flattened ->
            val component = ComponentName.unflattenFromString(flattened)
            component == expected || flattened.equals(expected.flattenToString(), ignoreCase = true)
        }
    }
}
