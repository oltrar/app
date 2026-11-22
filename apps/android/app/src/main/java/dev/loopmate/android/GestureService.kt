package dev.loopmate.android

import android.accessibilityservice.AccessibilityService
import android.accessibilityservice.GestureDescription
import android.graphics.Path
import android.os.Handler
import android.os.Looper
import android.util.DisplayMetrics
import android.view.WindowManager
import android.view.accessibility.AccessibilityEvent

/** Uses gesture dispatch only; no screen contents are inspected or transmitted. */
class GestureService : AccessibilityService() {
    companion object {
        @Volatile
        var active: GestureService? = null
            private set
    }

    private val handler = Handler(Looper.getMainLooper())
    private var pending: Runnable? = null
    private var running = false
    private var generation = 0
    private var action = "swipe_up"
    private var intervalMs = 10000L
    private var xPercent = 50f
    private var yPercent = 50f
    private var limit = 0

    var count = 0
        private set
    var error: String? = null
        private set

    override fun onServiceConnected() {
        super.onServiceConnected()
        active = this
    }

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {}
    override fun onInterrupt() { stop() }

    override fun onUnbind(intent: android.content.Intent?): Boolean {
        stop()
        if (active === this) active = null
        return super.onUnbind(intent)
    }

    override fun onDestroy() {
        stop()
        if (active === this) active = null
        super.onDestroy()
    }

    fun isRunning(): Boolean = running

    fun start(type: String, seconds: Int, repeats: Int, x: Float, y: Float) {
        require(type in setOf("tap", "swipe_up", "swipe_down", "swipe_left", "swipe_right"))
        require(seconds > 0 && repeats >= 0 && x in 0f..100f && y in 0f..100f)
        stop()
        action = type
        intervalMs = seconds * 1000L
        limit = repeats
        xPercent = x
        yPercent = y
        error = null
        count = 0
        running = true
        val token = generation
        // Delay first action to let the user switch to the target app.
        schedule(token)
    }

    fun stop() {
        generation++
        running = false
        pending?.let { handler.removeCallbacks(it) }
        pending = null
    }

    private fun schedule(token: Int) {
        if (!running || token != generation) return
        val job = Runnable { dispatchNext(token) }
        pending = job
        handler.postDelayed(job, intervalMs)
    }

    private fun dispatchNext(token: Int) {
        if (!running || token != generation) return
        val gesture = createGesture()
        val callback = object : GestureResultCallback() {
            override fun onCompleted(gestureDescription: GestureDescription?) {
                if (!running || generation != token) return
                count++
                if (limit > 0 && count >= limit) stop() else schedule(token)
            }

            override fun onCancelled(gestureDescription: GestureDescription?) {
                if (!running || generation != token) return
                error = "Android cancelled the gesture."
                stop()
            }
        }
        if (!dispatchGesture(gesture, callback, handler)) {
            error = "Android rejected the gesture."
            stop()
        }
    }

    private fun createGesture(): GestureDescription {
        @Suppress("DEPRECATION")
        val wm = getSystemService(WINDOW_SERVICE) as WindowManager
        val metrics = DisplayMetrics()
        @Suppress("DEPRECATION")
        wm.defaultDisplay.getRealMetrics(metrics)
        val width = metrics.widthPixels.toFloat().coerceAtLeast(3f)
        val height = metrics.heightPixels.toFloat().coerceAtLeast(3f)
        val x = (width * xPercent / 100f).coerceIn(1f, width - 1f)
        val y = (height * yPercent / 100f).coerceIn(1f, height - 1f)

        val path = Path()
        val duration = if (action == "tap") 90L else 350L
        when (action) {
            "tap" -> { path.moveTo(x, y); path.lineTo(x, y) }
            "swipe_up" -> {
                path.moveTo(width / 2, height * 0.82f)
                path.lineTo(width / 2, height * 0.18f)
            }
            "swipe_down" -> {
                path.moveTo(width / 2, height * 0.18f)
                path.lineTo(width / 2, height * 0.82f)
            }
            "swipe_left" -> {
                path.moveTo(width * 0.82f, height / 2)
                path.lineTo(width * 0.18f, height / 2)
            }
            "swipe_right" -> {
                path.moveTo(width * 0.18f, height / 2)
                path.lineTo(width * 0.82f, height / 2)
            }
        }
        val stroke = GestureDescription.StrokeDescription(path, 0, duration)
        return GestureDescription.Builder().addStroke(stroke).build()
    }
}
