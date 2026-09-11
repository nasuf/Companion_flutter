package com.bansheng.companion

import android.hardware.display.DisplayManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.view.Display
import android.view.Surface
import android.view.SurfaceControl
import android.view.SurfaceHolder
import android.view.SurfaceView
import android.view.View
import android.view.ViewGroup
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.android.FlutterSurfaceView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * ColorOS LTPO hops 120→30→120 when setFrameRate(ALWAYS) is issued while the
 * panel is already at peak. Plant a seamless 120 Hz vote once, then only
 * ALWAYS-recover after a real drop (typically 60 Hz) has lasted ~400 ms.
 */
class MainActivity : FlutterActivity() {

    private var flutterSurfaceView: FlutterSurfaceView? = null
    private var surfaceCallbackAttached = false
    private var windowModeApplied = false
    private var seamlessPeakVoteDone = false
    private var activityResumed = false
    private var displayListener: DisplayManager.DisplayListener? = null
    private var keepAlivePosted = false
    private var lastSurfaceVoteUptimeMs = 0L
    private var belowPeakSinceMs = 0L
    private var ignoreVotesUntilMs = 0L

    private val mainHandler = Handler(Looper.getMainLooper())
    private val keepAliveRunnable = object : Runnable {
        override fun run() {
            keepAlivePosted = false
            if (activityResumed) {
                lockPeakRefreshRate(writeWindow = false, allowSeamlessPlant = false)
                val peak = peakRefreshRate()
                val current = currentRefreshRate()
                val recovering = peak != null && current != null &&
                    current < peak - RATE_SLACK_HZ
                scheduleKeepAlive(
                    if (recovering) KEEP_ALIVE_RECOVER_MS else KEEP_ALIVE_IDLE_MS,
                )
            }
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "lockPeak" -> {
                        lockPeakRefreshRate(writeWindow = false, allowSeamlessPlant = false)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onFlutterSurfaceViewCreated(flutterSurfaceView: FlutterSurfaceView) {
        super.onFlutterSurfaceViewCreated(flutterSurfaceView)
        this.flutterSurfaceView = flutterSurfaceView
        attachSurfaceCallback(flutterSurfaceView)
        lockPeakRefreshRate(writeWindow = true, allowSeamlessPlant = true)
    }

    override fun onFlutterUiDisplayed() {
        super.onFlutterUiDisplayed()
        lockPeakRefreshRate(writeWindow = true, allowSeamlessPlant = true)
        startDisplayWatch()
        scheduleKeepAlive(KEEP_ALIVE_IDLE_MS)
    }

    override fun onPostResume() {
        super.onPostResume()
        activityResumed = true
        window.decorView.post {
            lockPeakRefreshRate(writeWindow = false, allowSeamlessPlant = true)
            scheduleKeepAlive(KEEP_ALIVE_IDLE_MS)
        }
    }

    override fun onWindowFocusChanged(hasFocus: Boolean) {
        super.onWindowFocusChanged(hasFocus)
        if (hasFocus) {
            lockPeakRefreshRate(writeWindow = false, allowSeamlessPlant = false)
        }
    }

    override fun onPause() {
        activityResumed = false
        stopKeepAlive()
        super.onPause()
    }

    override fun onDestroy() {
        stopDisplayWatch()
        stopKeepAlive()
        super.onDestroy()
    }

    private fun lockPeakRefreshRate(writeWindow: Boolean, allowSeamlessPlant: Boolean) {
        val peak = peakRefreshRate() ?: return
        if (writeWindow) applyWindowModeOnce()
        val current = currentRefreshRate() ?: return
        trackRate(current, peak)

        if (current >= peak - RATE_SLACK_HZ) {
            if (allowSeamlessPlant && !seamlessPeakVoteDone) {
                voteFlutterSurfaces(peak, changeAlways = false)
                seamlessPeakVoteDone = true
            }
            return
        }

        if (!shouldRecoverVote(current, peak)) {
            if (current < peak - RATE_SLACK_HZ) {
                scheduleKeepAlive(KEEP_ALIVE_RECOVER_MS)
            }
            return
        }

        voteFlutterSurfaces(peak, changeAlways = true)
        ignoreVotesUntilMs = SystemClock.uptimeMillis() + VOTE_COOLDOWN_MS
        seamlessPeakVoteDone = true
    }

    private fun trackRate(current: Float, peak: Float) {
        val now = SystemClock.uptimeMillis()
        if (current >= peak - RATE_SLACK_HZ) {
            belowPeakSinceMs = 0L
        } else if (belowPeakSinceMs == 0L) {
            belowPeakSinceMs = now
        }
    }

    private fun belowPeakForMs(): Long {
        if (belowPeakSinceMs == 0L) return 0L
        return SystemClock.uptimeMillis() - belowPeakSinceMs
    }

    private fun shouldRecoverVote(current: Float, peak: Float): Boolean {
        if (SystemClock.uptimeMillis() < ignoreVotesUntilMs) return false
        if (current >= peak - RATE_SLACK_HZ) return false
        return belowPeakForMs() >= STUCK_BELOW_PEAK_MS
    }

    private fun applyWindowModeOnce() {
        if (windowModeApplied) return
        val window = window ?: return
        val maxMode = peakDisplayMode() ?: return
        try {
            val params = window.attributes
            params.preferredDisplayModeId = maxMode.modeId
            params.preferredRefreshRate = maxMode.refreshRate
            window.attributes = params
            windowModeApplied = true
        } catch (_: Exception) {
        }
    }

    private fun voteFlutterSurfaces(maxRate: Float, changeAlways: Boolean) {
        val now = SystemClock.uptimeMillis()
        if (now - lastSurfaceVoteUptimeMs < VOTE_DEBOUNCE_MS) return
        lastSurfaceVoteUptimeMs = now

        val views = mutableListOf<SurfaceView>()
        flutterSurfaceView?.let { views.add(it) }
        findSurfaceViews(window.decorView, views)
        for (surfaceView in views.distinct()) {
            voteSurfaceView(surfaceView, maxRate, changeAlways)
        }
        if (Build.VERSION.SDK_INT >= 35) {
            try {
                window.decorView.setRequestedFrameRate(
                    View.REQUESTED_FRAME_RATE_CATEGORY_HIGH.toFloat(),
                )
                flutterSurfaceView?.setRequestedFrameRate(maxRate)
                window.setFrameRateBoostOnTouchEnabled(true)
            } catch (_: Exception) {
            }
        }
    }

    private fun voteSurfaceView(
        surfaceView: SurfaceView,
        maxRate: Float,
        changeAlways: Boolean,
    ) {
        if (Build.VERSION.SDK_INT >= 29) {
            try {
                val sc = surfaceView.surfaceControl
                if (sc != null && sc.isValid) {
                    voteSurfaceControl(sc, maxRate, changeAlways)
                }
            } catch (_: Exception) {
            }
        }
        try {
            val surface = surfaceView.holder.surface
            if (surface != null && surface.isValid) {
                if (Build.VERSION.SDK_INT >= 31) {
                    val strategy = if (changeAlways) {
                        Surface.CHANGE_FRAME_RATE_ALWAYS
                    } else {
                        Surface.CHANGE_FRAME_RATE_ONLY_IF_SEAMLESS
                    }
                    surface.setFrameRate(
                        maxRate,
                        Surface.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE,
                        strategy,
                    )
                } else if (Build.VERSION.SDK_INT >= 30) {
                    surface.setFrameRate(
                        maxRate,
                        Surface.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE,
                    )
                }
            }
        } catch (_: Exception) {
        }
        if (Build.VERSION.SDK_INT >= 35) {
            try {
                surfaceView.setRequestedFrameRate(maxRate)
            } catch (_: Exception) {
            }
        }
    }

    private fun voteSurfaceControl(
        surfaceControl: SurfaceControl,
        maxRate: Float,
        changeAlways: Boolean,
    ) {
        if (Build.VERSION.SDK_INT < 30) return
        try {
            val tx = SurfaceControl.Transaction()
            if (Build.VERSION.SDK_INT >= 31) {
                val strategy = if (changeAlways) {
                    Surface.CHANGE_FRAME_RATE_ALWAYS
                } else {
                    Surface.CHANGE_FRAME_RATE_ONLY_IF_SEAMLESS
                }
                tx.setFrameRate(
                    surfaceControl,
                    maxRate,
                    Surface.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE,
                    strategy,
                )
            } else {
                tx.setFrameRate(
                    surfaceControl,
                    maxRate,
                    Surface.FRAME_RATE_COMPATIBILITY_FIXED_SOURCE,
                )
            }
            tx.apply()
        } catch (_: Exception) {
        }
    }

    private fun attachSurfaceCallback(surfaceView: SurfaceView) {
        if (surfaceCallbackAttached) return
        surfaceCallbackAttached = true
        surfaceView.holder.addCallback(object : SurfaceHolder.Callback {
            override fun surfaceCreated(holder: SurfaceHolder) {
                seamlessPeakVoteDone = false
                lockPeakRefreshRate(writeWindow = true, allowSeamlessPlant = true)
            }

            override fun surfaceChanged(
                holder: SurfaceHolder,
                format: Int,
                width: Int,
                height: Int,
            ) {
                lockPeakRefreshRate(writeWindow = false, allowSeamlessPlant = false)
            }

            override fun surfaceDestroyed(holder: SurfaceHolder) {}
        })
    }

    private fun startDisplayWatch() {
        if (displayListener != null) return
        val dm = getSystemService(DISPLAY_SERVICE) as? DisplayManager ?: return
        val listener = object : DisplayManager.DisplayListener {
            override fun onDisplayAdded(displayId: Int) {}
            override fun onDisplayRemoved(displayId: Int) {}
            override fun onDisplayChanged(displayId: Int) {
                lockPeakRefreshRate(writeWindow = false, allowSeamlessPlant = false)
            }
        }
        displayListener = listener
        dm.registerDisplayListener(listener, mainHandler)
    }

    private fun stopDisplayWatch() {
        val listener = displayListener ?: return
        val dm = getSystemService(DISPLAY_SERVICE) as? DisplayManager
        dm?.unregisterDisplayListener(listener)
        displayListener = null
    }

    private fun scheduleKeepAlive(delayMs: Long) {
        if (keepAlivePosted) {
            mainHandler.removeCallbacks(keepAliveRunnable)
        }
        keepAlivePosted = true
        mainHandler.postDelayed(keepAliveRunnable, delayMs)
    }

    private fun stopKeepAlive() {
        keepAlivePosted = false
        mainHandler.removeCallbacks(keepAliveRunnable)
    }

    private fun peakDisplayMode(): Display.Mode? {
        val display = currentDisplay() ?: return null
        return display.supportedModes.maxByOrNull { it.refreshRate }
    }

    private fun peakRefreshRate(): Float? {
        val rate = peakDisplayMode()?.refreshRate ?: return null
        return if (rate > 61f) rate else null
    }

    private fun currentRefreshRate(): Float? = currentDisplay()?.refreshRate

    @Suppress("DEPRECATION")
    private fun currentDisplay(): Display? {
        return if (Build.VERSION.SDK_INT >= 30) display else windowManager.defaultDisplay
    }

    private fun findSurfaceViews(root: View, out: MutableList<SurfaceView>) {
        if (root is SurfaceView) out.add(root)
        if (root is ViewGroup) {
            for (i in 0 until root.childCount) {
                findSurfaceViews(root.getChildAt(i), out)
            }
        }
    }

    companion object {
        private const val CHANNEL = "companion/display_refresh"
        private const val VOTE_DEBOUNCE_MS = 80L
        private const val VOTE_COOLDOWN_MS = 500L
        private const val STUCK_BELOW_PEAK_MS = 400L
        private const val KEEP_ALIVE_RECOVER_MS = 400L
        private const val KEEP_ALIVE_IDLE_MS = 1500L
        private const val RATE_SLACK_HZ = 8f
    }
}
