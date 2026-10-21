package fr.podavio.podavio

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterEngineCache.getInstance().put(AndroidAutoBridge.ENGINE_ID, flutterEngine)
        AndroidAutoBridge.attach(flutterEngine)
        NearbySharePlugin.attach(flutterEngine, applicationContext)
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        FlutterEngineCache.getInstance().remove(AndroidAutoBridge.ENGINE_ID)
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
