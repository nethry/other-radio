package pl.otherradio.other_radio

import com.ryanheise.audioservice.AudioServiceActivity
import android.app.UiModeManager
import android.content.Context
import android.content.res.Configuration
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "pl.otherradio/device")
            .setMethodCallHandler { call, result ->
                if (call.method == "isTelevision") {
                    val mode = getSystemService(Context.UI_MODE_SERVICE) as UiModeManager
                    result.success(mode.currentModeType == Configuration.UI_MODE_TYPE_TELEVISION)
                } else {
                    result.notImplemented()
                }
            }
    }
}
