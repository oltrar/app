package dev.loopmate.android

import android.app.Activity
import android.content.ComponentName
import android.content.Intent
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.text.InputType
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.EditText
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.Spinner
import android.widget.ArrayAdapter
import android.widget.TextView
import android.widget.Toast

class MainActivity : Activity() {
    private val choices = listOf(
        "Tap position" to "tap",
        "Swipe up" to "swipe_up",
        "Swipe down" to "swipe_down",
        "Swipe left" to "swipe_left",
        "Swipe right" to "swipe_right"
    )
    private lateinit var status: TextView
    private lateinit var action: Spinner
    private lateinit var interval: EditText
    private lateinit var limit: EditText
    private lateinit var x: EditText
    private lateinit var y: EditText
    private val handler = Handler(Looper.getMainLooper())

    private val update = object : Runnable {
        override fun run() {
            refresh()
            handler.postDelayed(this, 800)
        }
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(28, 28, 28, 28)
        }
        val scroll = ScrollView(this)
        scroll.addView(root)
        setContentView(scroll)

        fun addLabel(text: String) = TextView(this).also {
            it.text = text
            it.textSize = 18f
            it.setPadding(0, 20, 0, 8)
            root.addView(it)
        }

        addLabel("LoopMate Android").apply { textSize = 27f }
        status = addLabel("Checking accessibility…")
        action = Spinner(this).apply {
            adapter = ArrayAdapter(this@MainActivity,
                android.R.layout.simple_spinner_dropdown_item, choices.map { it.first })
            setSelection(1)
        }
        addLabel("Action")
        root.addView(action)
        interval = entry(root, "10", "Interval in seconds (minimum 1)")
        limit = entry(root, "0", "Repeat limit (0 = unlimited)")
        x = entry(root, "50", "Tap X position (0-100%)")
        y = entry(root, "50", "Tap Y position (0-100%)")

        Button(this).apply {
            text = "Enable accessibility permission"
            setOnClickListener { startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS)) }
            root.addView(this)
        }
        Button(this).apply {
            text = "Start repeating"
            setOnClickListener { begin() }
            root.addView(this)
        }
        Button(this).apply {
            text = "Stop repeating"
            setOnClickListener {
                GestureService.active?.stop()
                refresh()
            }
            root.addView(this)
        }
        addLabel("Actions run while the accessibility service remains enabled. First gesture occurs after the selected interval; switch to your target app.")
    }

    private fun entry(root: LinearLayout, initial: String, hint: String): EditText {
        val label = TextView(this).apply {
            text = hint
            setPadding(0, 18, 0, 3)
        }
        root.addView(label)
        return EditText(this).also {
            it.setText(initial)
            it.inputType = InputType.TYPE_CLASS_NUMBER or InputType.TYPE_NUMBER_FLAG_DECIMAL
            it.layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
            )
            root.addView(it)
        }
    }

    private fun enabled(): Boolean {
        val expected = ComponentName(this, GestureService::class.java)
        val services = Settings.Secure.getString(contentResolver,
            Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES) ?: return false
        return services.split(':').any {
            ComponentName.unflattenFromString(it) == expected
        }
    }

    private fun begin() {
        val seconds = interval.text.toString().toIntOrNull()
        val repeats = limit.text.toString().toIntOrNull()
        val px = x.text.toString().toFloatOrNull()
        val py = y.text.toString().toFloatOrNull()
        if (seconds == null || seconds < 1 || repeats == null || repeats < 0 ||
            px == null || py == null || !px.isFinite() || !py.isFinite() ||
            px !in 0f..100f || py !in 0f..100f) {
            Toast.makeText(this, "Check interval, repeats, and coordinates.",
                Toast.LENGTH_LONG).show()
            return
        }
        val service = GestureService.active
        if (!enabled() || service == null) {
            Toast.makeText(this, "Enable LoopMate in Accessibility settings first.",
                Toast.LENGTH_LONG).show()
            startActivity(Intent(Settings.ACTION_ACCESSIBILITY_SETTINGS))
            return
        }
        service.start(choices[action.selectedItemPosition].second, seconds, repeats, px, py)
        refresh()
        Toast.makeText(this, "Started. Switch to your target app.", Toast.LENGTH_SHORT).show()
    }

    private fun refresh() {
        val service = GestureService.active
        status.text = when {
            !enabled() -> "Accessibility permission needed"
            service == null -> "Waiting for accessibility service…"
            service.isRunning() -> "Running · completed: ${service.count}"
            service.error != null -> "Stopped · ${service.error} · completed: ${service.count}"
            else -> "Ready · completed: ${service.count}"
        }
    }

    override fun onResume() {
        super.onResume()
        update.run()
    }

    override fun onPause() {
        handler.removeCallbacks(update)
        super.onPause()
    }
}
