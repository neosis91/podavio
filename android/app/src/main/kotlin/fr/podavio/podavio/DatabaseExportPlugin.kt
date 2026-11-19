package fr.podavio.podavio

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Ouvre « Enregistrer sous » et renvoie seulement l’URI du document.
 * Le contenu est écrit ensuite par morceaux, pour ne pas allouer la base
 * entière dans le tas Java.
 */
object DatabaseExportPlugin {
    private const val CHANNEL = "fr.podavio.podavio/database_export"

    private var pending: MethodChannel.Result? = null
    private var launch: ((String) -> Unit)? = null

    fun attach(engine: FlutterEngine, launch: (String) -> Unit) {
        this.launch = launch
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "createDocument" -> open(call.argument("fileName"), result)
                    else -> result.notImplemented()
                }
            }
    }

    fun complete(uri: String?) {
        val result = pending
        pending = null
        result?.success(uri)
    }

    private fun open(fileName: String?, result: MethodChannel.Result) {
        if (fileName.isNullOrEmpty()) {
            result.error("invalid", "Missing file name", null)
            return
        }
        if (pending != null) {
            result.error("busy", "A save dialog is already open", null)
            return
        }
        val opener = launch
        if (opener == null) {
            result.error("unavailable", "Save dialog is unavailable", null)
            return
        }
        pending = result
        try {
            opener(fileName)
        } catch (error: Exception) {
            pending = null
            result.error("create_document", error.message, null)
        }
    }
}
