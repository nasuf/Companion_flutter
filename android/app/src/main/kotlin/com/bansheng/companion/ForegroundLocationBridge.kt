package com.bansheng.companion

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.MethodChannel

/** Foreground-only, cancellable GPS/network race. No Play Services dependency. */
class ForegroundLocationBridge(context: Context, private val channel: MethodChannel) {
    private val context = context.applicationContext
    private val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private val handler = Handler(Looper.getMainLooper())
    private val reads = mutableMapOf<Int, Read>()

    init {
        channel.setMethodCallHandler { call, result ->
            val id = call.argument<Int>("id")
            if (id == null) {
                result.error("invalid_request", "Missing location request ID", null)
            } else when (call.method) {
                "read" -> start(id, call.argument<Boolean>("fresh") == true, call.argument<Boolean>("precise") != false, result)
                "cancel" -> { reads[id]?.finish(error = "cancelled"); result.success(null) }
                else -> result.notImplemented()
            }
        }
    }

    fun stop() { reads.values.toList().forEach { it.finish(error = "cancelled") } }
    fun dispose() { stop(); channel.setMethodCallHandler(null) }

    private fun permitted(): Boolean =
        context.checkSelfPermission(Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED ||
            context.checkSelfPermission(Manifest.permission.ACCESS_COARSE_LOCATION) == PackageManager.PERMISSION_GRANTED

    private fun usable(location: Location, precise: Boolean): Boolean {
        val ageMs = (SystemClock.elapsedRealtimeNanos() - location.elapsedRealtimeNanos) / 1_000_000
        val wallAgeMs = System.currentTimeMillis() - location.time
        return location.latitude.isFinite() && location.latitude in -90.0..90.0 &&
            location.longitude.isFinite() && location.longitude in -180.0..180.0 &&
            location.hasAccuracy() && location.accuracy.isFinite() &&
            location.accuracy > 0 && (!precise || location.accuracy <= 100) &&
            ageMs in 0..15_000 && wallAgeMs in 0..15_000
    }

    @Suppress("MissingPermission")
    private fun start(id: Int, fresh: Boolean, precise: Boolean, result: MethodChannel.Result) {
        if (!permitted()) {
            result.error("permission_denied", "Location permission unavailable", null)
            return
        }
        val providers = listOf(LocationManager.NETWORK_PROVIDER, LocationManager.GPS_PROVIDER, "fused")
            .filter { try { manager.isProviderEnabled(it) } catch (_: Exception) { false } }
        if (providers.isEmpty()) {
            result.error("service_disabled", "Location services unavailable", null)
            return
        }
        reads[id]?.finish(error = "cancelled")
        val read = Read(id, precise, result)
        reads[id] = read
        // A cached position is accepted only with both a recent monotonic age
        // and a valid wall timestamp; that original timestamp goes to the API.
        if (!fresh) {
            val cached = providers.mapNotNull {
                try { manager.getLastKnownLocation(it) } catch (_: Exception) { null }
            }.filter { usable(it, precise) }.maxByOrNull { it.elapsedRealtimeNanos }
            if (cached != null) { read.finish(location = cached); return }
        }
        var listening = false
        for (provider in providers) {
            try {
                // Start all available system providers together. GPS does not
                // monopolize the deadline on indoor/no-GMS phones.
                manager.requestLocationUpdates(provider, 500L, 0f, read, Looper.getMainLooper())
                listening = true
            } catch (_: Exception) { /* Another enabled provider can still work. */ }
        }
        if (!listening) {
            read.finish(error = if (permitted()) "unavailable" else "permission_denied")
        } else {
            handler.postDelayed(read.deadline, 8_000L)
        }
    }

    private inner class Read(val id: Int, val precise: Boolean, val result: MethodChannel.Result) : LocationListener {
        var completed = false
        val deadline = Runnable { finish(error = "timeout") }
        override fun onLocationChanged(location: Location) {
            if (usable(location, precise)) finish(location = location)
        }
        override fun onProviderEnabled(provider: String) {}
        override fun onProviderDisabled(provider: String) {}
        @Deprecated("Required on Android before API 30")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) {}

        fun finish(location: Location? = null, error: String? = null) {
            if (completed) return
            completed = true
            reads.remove(id)
            handler.removeCallbacks(deadline)
            try { manager.removeUpdates(this) } catch (_: Exception) {}
            if (location == null) {
                result.error(error ?: "unavailable", "Location request ended", null)
            } else {
                result.success(mapOf(
                    "latitude" to location.latitude, "longitude" to location.longitude,
                    "accuracy" to location.accuracy.toDouble(), "timestamp" to location.time,
                    "altitude" to location.altitude, "heading" to location.bearing.toDouble(),
                    "speed" to location.speed.toDouble(), "is_mocked" to location.isFromMockProvider,
                ))
            }
        }
    }
}
