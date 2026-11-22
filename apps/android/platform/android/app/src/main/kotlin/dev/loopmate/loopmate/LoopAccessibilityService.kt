package dev.loopmate.loopmate

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent

/**
 * Dispatches only the user's configured gesture. No accessibility event content,
 * screen contents or text is read, collected or transmitted.
 */
class LoopAccessibilityService : AccessibilityService() {
    companion object {
        @Volatile
        var instance: LoopAccessibilityService? = null
            private set
    }

    private val handler = Handler(Looper.getMainLooper())
    private var loopRunnable: Runnable? = null
    private var running = false
    private var generation = 0
    private var action = "swipe_up"
    private var intervalMillis = 10_000L
    private var xPercent = 50f
    private var yPercent = 50f
    private var repeatLimit = 0
    private var executionCount = 0
    private var lastError: String? = null

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Deliberately ignore all window and accessibility event content.
    }

    override fun onInterrupt() {
        stopLoop()
    }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        stopLoop()
        if (instance === this) instance = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        stopLoop()
        if (instance === this) instance = null
        super.onDestroy()
    }

    fun startLoop(
        action: String,
        intervalMillis: Long,
        xPercent: Float,
        yPercent: Float,
        repeatCount: Int
    ) {
        stopLoop()
        this.action = action
        this.intervalMillis = intervalMillis.coerceAtLeast(1_000L)
        this.xPercent = xPercent.coerceIn(0f, 100f)
        this.yPercent = yPercent.coerceIn(0f, 100f)
        this.repeatLimit = repeatCount.coerceAtLeast(0)
        executionCount = 0
        lastError = null
        running = true
        loopRunnable = Runnable { executeNextGesture() }

        // Allow time to move into the app to automate before the first gesture.
        loopRunnable?.let { handler.postDelayed(it, this.intervalMillis) }
    }

    fun stopLoop() {
        generation++
        running = false
        loopRunnable?.let(handler::removeCallbacks)
        loopRunnable = null
    }

    fun isLoopRunning(): Boolean = running

    fun getExecutionCount(): Int = executionCount

    fun getLastError(): String? = lastError

    private fun executeNextGesture() {
        if (!running) return
        val token = generation
        val gesture = buildGesture()
        if (gesture == null) {
            lastError = "Unknown gesture action."
            stopLoop()
            return
        }
        val callback = object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                if (!running || token != generation) return
                executionCount++
                if (repeatLimit > 0 && executionCount >= repeatLimit) {
                    stopLoop()
                } else {
                    loopRunnable?.let { handler.postDelayed(it, intervalMillis) }
                }
            }

            override fun onCancelled(gestureDescription: GestureDescription?) {
                if (running && token == generation) {
                    lastError = "Android cancelled the gesture."
                    stopLoop()
                }
            }
        }

        if (!dispatchGesture(gesture, callback, handler)) {
            lastError = "Android could not dispatch the gesture."
            stopLoop()
        }
    }

    private fun buildGesture(): GestureDescription? {
        val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        windowManager.defaultDisplay.getRealMetrics(metrics)

        val width = metrics.widthPixels.toFloat().coerceAtLeast(3f)
        val height = metrics.heightPixels.toFloat().coerceAtLeast(3f)
        val x = (width * (xPercent / 100f)).coerceIn(1f, width - 1f)
        val y = (height * (yPercent / 100f)).coerceIn(1f, height - 1f)

        val path = Path()
        val duration: Long
        when (action) {
            "tap" -> {
                path.moveTo(x, y)
                path.lineTo(x, y)
                duration = 90L
            }
            "swipe_up" -> {
                path.moveTo(width * 0.5f, height * 0.82f)
                path.lineTo(width * 0.5f, height * 0.18f)
                duration = 350L
            }
            "swipe_down" -> {
                path.moveTo(width * 0.5f, height * 0.18f)
                path.lineTo(width * 0.5f, height * 0.82f)
                duration = 350L
            }
            "swipe_left" -> {
                path.moveTo(width * 0.82f, height * 0.5f)
                path.lineTo(width * 0.18f, height * 0.5f)
                duration = 350L
            }
            "swipe_right" -> {
                path.moveTo(width * 0.18f, height * 0.5f)
                path.lineTo(width * 0.82f, height * 0.5f)
                duration = 350L
            }
            else -> return null
        }
        val stroke = GestureDescription.StrokeDescription(path, 0L, duration)
        return GestureDescription.Builder().addStroke(stroke).build()
    }
}
