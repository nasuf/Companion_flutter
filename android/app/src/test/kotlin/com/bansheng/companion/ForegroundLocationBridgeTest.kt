package com.bansheng.companion

import android.Manifest
import android.app.Application
import android.content.Context
import android.location.Location
import android.location.LocationManager
import android.os.Looper
import android.os.SystemClock
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.FlutterException
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMethodCodec
import java.nio.ByteBuffer
import java.time.Duration
import org.junit.After
import org.junit.Assert.*
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowLocationManager

@RunWith(RobolectricTestRunner::class)
@Config(sdk = [24, 36], manifest = Config.NONE, application = Application::class)
class ForegroundLocationBridgeTest {
    private lateinit var bridge: ForegroundLocationBridge
    private lateinit var locations: ShadowLocationManager
    private lateinit var messenger: Messenger

    @Before fun setup() {
        val app = RuntimeEnvironment.getApplication()
        shadowOf(app).grantPermissions(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
        locations = shadowOf(app.getSystemService(Context.LOCATION_SERVICE) as LocationManager)
        locations.setProviderEnabled("gps", true)
        locations.setProviderEnabled("network", true)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(30))
        messenger = Messenger()
        bridge = ForegroundLocationBridge(app, MethodChannel(messenger, "test"))
    }
    @After fun cleanup() { bridge.dispose() }

    private fun fix(provider: String = "network", age: Long = 0, accuracy: Float = 20f) = Location(provider).apply {
        latitude = 31.2; longitude = 121.4; this.accuracy = accuracy
        time = System.currentTimeMillis() - age
        elapsedRealtimeNanos = SystemClock.elapsedRealtimeNanos() - age * 1_000_000
    }
    private fun requests(provider: String) = locations.getLegacyLocationRequests(provider).size

    @Test fun networkFixWinsWithoutWaitingForGps() {
        val reply = messenger.call("read", 1)
        assertEquals(1, requests("network")); assertEquals(1, requests("gps"))
        val fix = fix()
        locations.simulateLocation(fix); shadowOf(Looper.getMainLooper()).idle()
        assertEquals(fix.time, (reply.value as Map<*, *>)["timestamp"])
        assertEquals(0, requests("network")); assertEquals(0, requests("gps"))
        locations.simulateLocation(fix("gps")); shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(9))
        assertEquals(1, reply.count)
    }
    @Test fun gpsCanWinTheSameRace() {
        val reply = messenger.call("read", 1)
        locations.simulateLocation(fix("gps")); shadowOf(Looper.getMainLooper()).idle()
        assertNotNull(reply.value); assertEquals(0, requests("network"))
    }
    @Test fun deadlineRemovesEveryListenerAtEightSeconds() {
        val reply = messenger.call("read", 1)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(7)); assertEquals(0, reply.count)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        assertEquals("timeout", reply.error); assertEquals(1, reply.count)
        assertEquals(0, requests("gps")); assertEquals(0, requests("network"))
    }
    @Test fun cancelAndStopPreventLateCompletion() {
        val first = messenger.call("read", 1)
        messenger.call("cancel", 1); assertEquals("cancelled", first.error)
        val second = messenger.call("read", 2)
        bridge.stop(); assertEquals("cancelled", second.error)
        locations.simulateLocation(fix()); shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(10))
        assertEquals(1, first.count); assertEquals(1, second.count)
        assertEquals(0, requests("network")); assertEquals(0, requests("gps"))
    }
    @Test fun recentCacheIsImmediateButExplicitRefreshBypassesIt() {
        val cached = fix(age = 2_000)
        locations.setLastKnownLocation("network", cached)
        val reply = messenger.call("read", 1)
        assertEquals(cached.time, (reply.value as Map<*, *>)["timestamp"])
        assertEquals(0, requests("gps"))
        val fresh = messenger.call("read", 2, fresh = true)
        assertEquals(0, fresh.count); assertEquals(1, requests("network"))
    }
    @Test fun staleAndInaccurateFixesDoNotBecomeVerifiedLocations() {
        locations.setLastKnownLocation("network", fix(age = 16_000))
        val reply = messenger.call("read", 1)
        locations.simulateLocation(fix(accuracy = 500f)); shadowOf(Looper.getMainLooper()).idle()
        assertEquals(0, reply.count)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        locations.simulateLocation(fix()); shadowOf(Looper.getMainLooper()).idle()
        assertNotNull(reply.value)
    }
    @Test fun chatCanUseApproximateFixWhileArrivalWaitsForAccuracy() {
        val chat = messenger.call("read", 1, precise = false)
        val arrival = messenger.call("read", 2)
        locations.simulateLocation(fix(accuracy = 500f)); shadowOf(Looper.getMainLooper()).idle()
        assertNotNull(chat.value); assertEquals(0, arrival.count)
        shadowOf(Looper.getMainLooper()).idleFor(Duration.ofSeconds(1))
        locations.simulateLocation(fix(accuracy = 20f)); shadowOf(Looper.getMainLooper()).idle()
        assertNotNull(arrival.value); assertEquals(1, chat.count)
    }
    @Test fun deniedPermissionAndDisabledProvidersFailWithoutListening() {
        val app = RuntimeEnvironment.getApplication()
        shadowOf(app).denyPermissions(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION)
        assertEquals("permission_denied", messenger.call("read", 1).error)
        shadowOf(app).grantPermissions(Manifest.permission.ACCESS_FINE_LOCATION)
        for (provider in listOf("gps", "network", "fused")) locations.setProviderEnabled(provider, false)
        assertEquals("service_disabled", messenger.call("read", 2).error)
        assertEquals(0, requests("gps"))
    }

    private class Reply { var value: Any? = null; var error: String? = null; var count = 0 }
    private class Messenger : BinaryMessenger {
        private var handler: BinaryMessenger.BinaryMessageHandler? = null
        override fun send(channel: String, message: ByteBuffer?) {}
        override fun send(channel: String, message: ByteBuffer?, callback: BinaryMessenger.BinaryReply?) {}
        override fun setMessageHandler(channel: String, handler: BinaryMessenger.BinaryMessageHandler?) { this.handler = handler }
        fun call(method: String, id: Int, fresh: Boolean = false, precise: Boolean = true): Reply {
            val reply = Reply()
            val buffer = StandardMethodCodec.INSTANCE.encodeMethodCall(MethodCall(method, mapOf("id" to id, "fresh" to fresh, "precise" to precise)))
            buffer.flip()
            handler!!.onMessage(buffer) { result ->
                reply.count++
                result!!.flip()
                try { reply.value = StandardMethodCodec.INSTANCE.decodeEnvelope(result) }
                catch (error: FlutterException) { reply.error = error.code }
            }
            return reply
        }
    }
}
