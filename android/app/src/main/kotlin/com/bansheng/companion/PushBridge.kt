package com.bansheng.companion

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import cn.jpush.android.api.JPushInterface
import cn.jpush.android.api.NotificationMessage
import cn.jpush.android.service.JCommonService
import cn.jpush.android.service.JPushMessageReceiver
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/** Only initialized after authenticated Flutter configuration (privacy acceptance). */
object PushBridge {
    var channel: MethodChannel? = null
    private var authorizationRequested = false
    private var initialized = false
    private const val EXTRA = "companion_push_payload"

    fun configure(activity: Activity, channel: MethodChannel) {
        this.channel = channel
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestAuthorizationAndRegister", "refreshRegistration" -> {
                    val key = activity.packageManager.getApplicationInfo(
                        activity.packageName, android.content.pm.PackageManager.GET_META_DATA
                    ).metaData?.getString("JPUSH_APPKEY").orEmpty()
                    if (key.isBlank()) {
                        result.error("not_configured", "JPush AppKey is missing", null)
                    } else {
                        JPushInterface.setDebugMode(false)
                        if (!initialized) {
                            JPushInterface.init(activity.applicationContext)
                            initialized = true
                        }
                        JPushInterface.resumePush(activity.applicationContext)
                        if (call.method == "requestAuthorizationAndRegister" && !authorizationRequested && Build.VERSION.SDK_INT >= 33 &&
                            activity.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                            authorizationRequested = true
                            activity.requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4601)
                        }
                        if (call.method == "requestAuthorizationAndRegister") {
                            result.success(true)
                        } else {
                            result.success(JPushInterface.getRegistrationID(activity.applicationContext))
                        }
                    }
                }
                "getToken" -> result.success(JPushInterface.getRegistrationID(activity.applicationContext))
                "stopPush" -> {
                    JPushInterface.stopPush(activity.applicationContext)
                    JPushInterface.clearAllNotifications(activity.applicationContext)
                    result.success(null)
                }
                "appMetadata" -> {
                    val info = activity.packageManager.getPackageInfo(activity.packageName, 0)
                    result.success(mapOf("bundle_id" to activity.packageName, "app_version" to info.versionName))
                }
                "takeInitialNotification" -> result.success(takePayload(activity.intent))
                else -> result.notImplemented()
            }
        }
    }

    fun takePayload(intent: Intent?): Map<String, Any?>? {
        val raw = intent?.getStringExtra(EXTRA) ?: return null
        intent.removeExtra(EXTRA)
        val json = JSONObject(raw)
        return json.keys().asSequence().associateWith { json.opt(it) }
    }

    fun open(context: Context, message: NotificationMessage) {
        val json = try { JSONObject(message.notificationExtras ?: "{}") } catch (_: Exception) { JSONObject() }
        json.put("title", message.notificationTitle)
        json.put("body", message.notificationContent)
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return
        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        intent.putExtra(EXTRA, json.toString())
        context.startActivity(intent)
    }
}

class CompanionPushReceiver : JPushMessageReceiver() {
    override fun onRegister(context: Context, registrationId: String) {
        android.os.Handler(android.os.Looper.getMainLooper()).post {
            PushBridge.channel?.invokeMethod("jpushToken", registrationId)
        }
    }
    override fun onNotifyMessageOpened(context: Context, message: NotificationMessage) {
        PushBridge.open(context, message)
    }
}

class CompanionPushService : JCommonService()
