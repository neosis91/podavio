package fr.podavio.podavio

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity : FlutterActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        AnalysisKeepAlive.activityCount += 1
        super.onCreate(savedInstanceState)
    }

    override fun onDestroy() {
        super.onDestroy()
        AnalysisKeepAlive.activityCount =
            (AnalysisKeepAlive.activityCount - 1).coerceAtLeast(0)
    }

    /// Seulement pendant une analyse : sinon une nouvelle activité
    /// repart sur un moteur neuf.
    override fun provideFlutterEngine(context: Context): FlutterEngine? {
        if (!AnalysisKeepAlive.active) return null
        return FlutterEngineCache.getInstance().get(AndroidAutoBridge.ENGINE_ID)
    }

    /// Une analyse en cours garde le moteur : quitter l’écran ne coupe pas le décodage.
    override fun shouldDestroyEngineWithHost(): Boolean = !AnalysisKeepAlive.active

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        val reused =
            FlutterEngineCache.getInstance().get(AndroidAutoBridge.ENGINE_ID) === flutterEngine
        if (!reused) {
            super.configureFlutterEngine(flutterEngine)
            FlutterEngineCache.getInstance().put(AndroidAutoBridge.ENGINE_ID, flutterEngine)
            AndroidAutoBridge.attach(flutterEngine)
            NearbySharePlugin.attach(flutterEngine, applicationContext)
            AudioDecodePlugin.attach(flutterEngine, applicationContext)
            WebCompanionPlugin.attach(flutterEngine, applicationContext)
            AnalysisPlugin.attach(flutterEngine, applicationContext)
        }
        DatabaseExportPlugin.attach(flutterEngine) { name ->
            val intent = Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                addCategory(Intent.CATEGORY_OPENABLE)
                type = "*/*"
                putExtra(Intent.EXTRA_TITLE, name)
            }
            @Suppress("DEPRECATION")
            startActivityForResult(intent, REQUEST_CREATE_DOCUMENT)
        }
    }

    @Deprecated("Required while MainActivity extends FlutterActivity, which is not a ComponentActivity.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != REQUEST_CREATE_DOCUMENT) {
            super.onActivityResult(requestCode, resultCode, data)
            return
        }
        val uri = data?.data
        if (resultCode == Activity.RESULT_OK && uri != null) {
            val flags = data.flags and
                (Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
            try {
                contentResolver.takePersistableUriPermission(uri, flags)
            } catch (_: SecurityException) {
            }
            DatabaseExportPlugin.complete(uri.toString())
        } else {
            DatabaseExportPlugin.complete(null)
        }
    }

    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        if (shouldDestroyEngineWithHost()) {
            val cache = FlutterEngineCache.getInstance()
            if (cache.get(AndroidAutoBridge.ENGINE_ID) === flutterEngine) {
                cache.remove(AndroidAutoBridge.ENGINE_ID)
            }
        }
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private companion object {
        const val REQUEST_CREATE_DOCUMENT = 0x70DA
    }
}
