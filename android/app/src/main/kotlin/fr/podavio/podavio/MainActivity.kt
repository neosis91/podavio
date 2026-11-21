package fr.podavio.podavio

import android.app.Activity
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        FlutterEngineCache.getInstance().put(AndroidAutoBridge.ENGINE_ID, flutterEngine)
        AndroidAutoBridge.attach(flutterEngine)
        NearbySharePlugin.attach(flutterEngine, applicationContext)
        AudioDecodePlugin.attach(flutterEngine, applicationContext)
        WebCompanionPlugin.attach(flutterEngine, applicationContext)
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
        FlutterEngineCache.getInstance().remove(AndroidAutoBridge.ENGINE_ID)
        super.cleanUpFlutterEngine(flutterEngine)
    }

    private companion object {
        const val REQUEST_CREATE_DOCUMENT = 0x70DA
    }
}
