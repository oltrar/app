package dev.loopmate.loopmate

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.util.DisplayMetrics
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent
import android.os.Handler
import android.os.Looper

/**
 * Sends the configured tap or swipe. It does not inspect window contents,
 * read text, take screenshots, or transmit data.
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
    private var action = "swipe_up"
    private var intervalMillis = 10_000L
    private var xPercent = 50f
    private var yPercent = 50f
    private var repeatLimit = 0
    private var executionCount = 0

    override fun onServiceConnected() {
        super.onServiceConnected()
        instance = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        // Screen content and accessibility events are not inspected.
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
        this.executionCount = 0
        this.running = true
        loopRunnable = Runnable { executeNextGesture() }
        executeNextGesture()
    }

    fun stopLoop() {
        running = false
        loopRunnable?.let(handler::removeCallbacks)
        loopRunnable = null
    }

    fun isLoopRunning(): Boolean = running

    fun getExecutionCount(): Int = executionCount

    private fun executeNextGesture() {
        if (!running) return
        if (repeatLimit > 0 && executionCount >= repeatLimit) {
            stopLoop()
            return
        }

        dispatchConfiguredGesture()
        executionCount += 1

        if (repeatLimit > 0 && executionCount >= repeatLimit) {
            stopLoop()
            return
        }
        loopRunnable?.let { handler.postDelayed(it, intervalMillis) }
    }

    private fun dispatchConfiguredGesture() {
        val windowManager = getSystemService(WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        windowManager.defaultDisplay.getRealMetrics(metrics)

        val width = metrics.widthPixels.toFloat().coerceAtLeast(1f)
        val height = metrics.heightPixels.toFloat().coerceAtLeast(1f)
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
            else -> return
        }

        val stroke = GestureDescription.StrokeDescription(path, 0L, duration)
        val gesture = GestureDescription.Builder().addStroke(stroke).build()
        dispatchGesture(gesture, null, handler)
    }
}
