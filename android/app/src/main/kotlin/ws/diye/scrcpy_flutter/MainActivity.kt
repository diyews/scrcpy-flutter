package ws.diye.scrcpy_flutter

import android.os.Handler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val scrcpyCHANNEL = "diye.ws/scrcpy"
    private val nativeSurfaceViewFactory = NativeSurfaceViewFactory();

    init {
//        nativeSurfaceViewFactory.connect("192.168.4.206", 7007, fun(v) {
//            println(v)
//        })

    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            scrcpyCHANNEL
        ).setMethodCallHandler { call, result ->
            if (call.method == "connectVideo") {
                val ip = call.argument<String>("ip")!!
                val port = call.argument<Int>("port")!!
                nativeSurfaceViewFactory.connect(ip, port, fun(v) {
                    activity.runOnUiThread(Runnable { kotlin.run {
                        result.success(v)
                    } })
                })
            } else if (call.method == "disconnectVideo") {
                nativeSurfaceViewFactory.disconnect()
                result.success(true)
            } else if (call.method == "getDeviceInfo") {
                result.success(nativeSurfaceViewFactory.deviceInfo)
            } else if (call.method == "start") {
                nativeSurfaceViewFactory.start()
                result.success(true)
            } else {
                result.notImplemented()
            }
        }
        flutterEngine.platformViewsController.registry.registerViewFactory("scrcpy-surface-view", nativeSurfaceViewFactory)

//        Handler().postDelayed(Runnable {
//            run() {
//            }
//        }, 0)
    }
}
