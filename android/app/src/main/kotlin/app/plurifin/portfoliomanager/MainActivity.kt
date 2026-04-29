package app.plurifin.portfoliomanager

import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Hosts a method channel that lets the Dart layer toggle FLAG_SECURE on the
 * Activity window. FLAG_SECURE blocks screenshots, screen recording, and
 * mirrors over USB / Cast for the entire app surface, which we apply on the
 * pages that show the user's portfolio data and AI conversations.
 *
 * The channel name is namespaced under `app.plurifin.portfoliomanager` to
 * avoid collisions with any third-party plugin.
 */
class MainActivity : FlutterActivity() {

    private val secureScreenChannel = "app.plurifin.portfoliomanager/secure_screen"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, secureScreenChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "enable" -> {
                        runOnUiThread {
                            window.setFlags(
                                WindowManager.LayoutParams.FLAG_SECURE,
                                WindowManager.LayoutParams.FLAG_SECURE
                            )
                        }
                        result.success(true)
                    }
                    "disable" -> {
                        runOnUiThread {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
