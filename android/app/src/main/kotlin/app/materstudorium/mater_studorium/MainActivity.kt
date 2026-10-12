package app.materstudorium.mater_studorium

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // T16: «О приложении» в системных настройках, чтобы включить микрофон
        // после отказа в разрешении (диктовка, ADR-32).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "app.materstudorium/system")
            .setMethodCallHandler { call, result ->
                if (call.method == "openAppSettings") {
                    val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                        .setData(Uri.fromParts("package", packageName, null))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    try {
                        startActivity(intent)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("unavailable", "settings screen not found", null)
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
