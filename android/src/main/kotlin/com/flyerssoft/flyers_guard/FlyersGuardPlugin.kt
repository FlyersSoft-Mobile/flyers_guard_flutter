package com.flyerssoft.flyers_guard

import android.content.Context
import com.flyerssoft.guard.FlyersGuardChannel
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Pure forwarder to the prebuilt FlyersGuard Android SDK.
 *
 * The channel contract (method keys, argument keys, threading and error
 * codes) lives in `com.flyerssoft.guard.FlyersGuardChannel` inside the
 * vendored AAR. This class only registers the channels and hands each call's
 * method key and raw arguments to that dispatcher.
 *
 * Two channels are served by the same dispatcher:
 *  - [FlyersGuardChannel.CHANNEL_NAME] (`flyers_guard/native`), which the
 *    Dart API uses on Android;
 *  - the legacy `flyers_guard` channel, kept so existing callers keep working.
 */
class FlyersGuardPlugin : FlutterPlugin, MethodCallHandler {

    private val channels = mutableListOf<MethodChannel>()
    private var appContext: Context? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        for (name in listOf(FlyersGuardChannel.CHANNEL_NAME, LEGACY_CHANNEL_NAME)) {
            channels += MethodChannel(binding.binaryMessenger, name).also {
                it.setMethodCallHandler(this)
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channels.forEach { it.setMethodCallHandler(null) }
        channels.clear()
        appContext = null
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        val context = appContext
        if (context == null) {
            result.error("NO_CONTEXT", "Plugin not attached to a context", null)
            return
        }
        FlyersGuardChannel.handle(context, call.method, call.arguments, result.asSdkResult())
    }

    private fun Result.asSdkResult() = object : FlyersGuardChannel.Result {
        override fun success(value: Any?) = this@asSdkResult.success(value)
        override fun error(code: String, message: String?, details: Any?) =
            this@asSdkResult.error(code, message, details)
        override fun notImplemented() = this@asSdkResult.notImplemented()
    }

    private companion object {
        const val LEGACY_CHANNEL_NAME = "flyers_guard"
    }
}
