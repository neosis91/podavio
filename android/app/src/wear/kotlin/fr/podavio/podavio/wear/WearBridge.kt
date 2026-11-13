package fr.podavio.podavio.wear

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.database.Cursor
import android.net.Uri
import android.os.Handler
import android.os.Looper
import com.google.android.gms.tasks.Tasks
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.MessageEvent
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import fr.podavio.podavio.AndroidAutoBridge
import fr.podavio.podavio.WearPlaybackFanout
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/** Démarre le pont au lancement du processus, avant la première commande. */
class WearBridgeProvider : ContentProvider() {
    override fun onCreate(): Boolean {
        context?.let { WearBridge.install(it) }
        return true
    }

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor? = null

    override fun getType(uri: Uri): String? = null

    override fun insert(uri: Uri, values: ContentValues?): Uri? = null

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun update(
        uri: Uri,
        values: ContentValues?,
        selection: String?,
        selectionArgs: Array<out String>?,
    ): Int = 0
}

/** Reçoit les commandes montre et les envoie au canal Android Auto. */
class PodavioWearListenerService : WearableListenerService() {
    override fun onMessageReceived(event: MessageEvent) {
        if (event.path != WearPaths.COMMAND) return
        val command = runCatching { WearCodec.decodeCommand(event.data) }.getOrNull() ?: return
        val app = applicationContext
        val nodeId = event.sourceNodeId
        Handler(Looper.getMainLooper()).post {
            dispatch(app, nodeId, command)
        }
    }

    private fun dispatch(app: Context, nodeId: String, command: WearCommand) {
        val engine = FlutterEngineCache.getInstance().get(AndroidAutoBridge.ENGINE_ID)
        if (engine == null) {
            send(app, nodeId, hint(command.requestId))
            return
        }
        val channel =
            MethodChannel(
                engine.dartExecutor.binaryMessenger,
                AndroidAutoBridge.CHANNEL_TO_DART,
            )
        channel.invokeMethod(
            command.name,
            argumentOf(command),
            object : MethodChannel.Result {
                override fun success(result: Any?) {
                    val items =
                        if (command.name == WearCommands.GET_CHILDREN && result is List<*>) {
                            wearItemsFromMaps(result)
                        } else {
                            emptyList()
                        }
                    send(app, nodeId, WearReply(command.requestId, ok = true, items = items))
                }

                override fun error(code: String, message: String?, details: Any?) {
                    send(app, nodeId, hint(command.requestId))
                }

                override fun notImplemented() {
                    send(app, nodeId, hint(command.requestId))
                }
            },
        )
    }

    private fun argumentOf(command: WearCommand): Any? =
        when (command.name) {
            WearCommands.SEEK -> command.argument?.toLongOrNull() ?: 0L
            WearCommands.GET_CHILDREN -> command.argument ?: WearFolders.ROOT
            WearCommands.PLAY_FROM_MEDIA_ID -> command.argument.orEmpty()
            else -> null
        }

    private fun hint(requestId: String) =
        WearReply(
            requestId = requestId,
            ok = false,
            items =
                listOf(
                    WearItem(
                        id = WearFolders.HINT_OPEN,
                        title = "Ouvrez Podavio sur le téléphone",
                        subtitle = "Puis choisissez un épisode",
                    ),
                ),
        )

    private fun send(app: Context, nodeId: String, reply: WearReply) {
        runCatching {
            Wearable.getMessageClient(app).sendMessage(
                nodeId,
                WearPaths.REPLY,
                WearCodec.encodeReply(reply),
            )
        }
    }
}

object WearBridge {
    private val executor =
        Executors.newSingleThreadExecutor { runnable ->
            Thread(runnable, "podavio-wear").apply { isDaemon = true }
        }

    fun install(context: Context) {
        val app = context.applicationContext
        WearPlaybackFanout.dispatch = { state ->
            executor.execute { runCatching { pushState(app, state) } }
        }
    }

    private fun pushState(context: Context, raw: Map<*, *>) {
        val payload = WearCodec.encodeState(wearStateFromMap(raw))
        val capability =
            Tasks.await(
                Wearable.getCapabilityClient(context).getCapability(
                    WearPaths.WATCH,
                    CapabilityClient.FILTER_REACHABLE,
                ),
                4,
                TimeUnit.SECONDS,
            )
        for (node in capability.nodes) {
            Tasks.await(
                Wearable.getMessageClient(context).sendMessage(
                    node.id,
                    WearPaths.STATE,
                    payload,
                ),
                4,
                TimeUnit.SECONDS,
            )
        }
    }
}
