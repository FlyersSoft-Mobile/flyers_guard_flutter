package com.flyerssoft.flyers_guard

import android.content.Context
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import com.flyerssoft.guard.FlyersGuard
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Method-channel bridge over the prebuilt FlyersGuard Android SDK. Holds no
 * detection logic of its own -- every call is delegated to the obfuscated
 * `com.flyerssoft.guard.FlyersGuard` in the vendored AAR.
 */
class FlyersGuardPlugin : FlutterPlugin, MethodCallHandler {

    private lateinit var channel: MethodChannel
    private var appContext: Context? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        appContext = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "flyers_guard")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        appContext = null
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        val context = appContext
        if (context == null) {
            result.error("NO_CONTEXT", "Plugin not attached to a context", null)
            return
        }
        when (call.method) {
            "getRootCheckReport" -> runOffThread {
                val report = FlyersGuard.getRootCheckReport(context)
                mainHandler.post { result.success(report) }
            }
            "isDeviceCompromised" -> runOffThread {
                val backendUrl = call.argument<String>("backendUrl") ?: ""
                val projectNumber = call.argument<String>("projectNumber")?.toLongOrNull()
                val compromised = FlyersGuard.isDeviceCompromised(context, backendUrl, projectNumber)
                mainHandler.post { result.success(compromised) }
            }
            else -> result.notImplemented()
        }
    }

    private fun runOffThread(block: () -> Unit) = Thread(block).start()
}
