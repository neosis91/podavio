package fr.podavio.podavio

import android.content.Context
import com.google.android.gms.wearable.CapabilityClient
import com.google.android.gms.wearable.Wearable
import com.google.android.gms.wearable.WearableListenerService
import fr.podavio.podavio.wear.WearCodec
import fr.podavio.podavio.wear.WearCommand
import fr.podavio.podavio.wear.WearPaths
import fr.podavio.podavio.wear.WearReply
import fr.podavio.podavio.wear.WearState
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicLong
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.TimeoutCancellationException
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.flow.MutableStateFlow

class WatchListenerService : WearableListenerService() {
    override fun onCreate() {
        super.onCreate()
        WatchLink.install(this)
    }

    override fun onMessageReceived(event: com.google.android.gms.wearable.MessageEvent) {
        WatchLink.install(this)
        WatchLink.onMessage(event.path, event.data)
    }
}

object WatchLink {
    val state =
        MutableStateFlow(
            WearState(
                hasEpisode = false,
                playing = false,
                title = "",
                artist = "",
                positionMs = 0,
                durationMs = 0,
            ),
        )
    val reachable = MutableStateFlow(false)

    private val started = AtomicBoolean(false)
    private val ids = AtomicLong()
    private val pending = ConcurrentHashMap<String, CompletableDeferred<WearReply>>()

    @Volatile
    private var appContext: Context? = null

    @Volatile
    private var nodeId: String? = null

    fun install(context: Context) {
        val application = context.applicationContext
        appContext = application
        if (!started.compareAndSet(false, true)) return
        val client = Wearable.getCapabilityClient(application)
        runCatching {
            client.addListener(
                { info ->
                    nodeId = info.nodes.firstOrNull()?.id
                    reachable.value = nodeId != null
                },
                WearPaths.PHONE,
            )
            client
                .getCapability(WearPaths.PHONE, CapabilityClient.FILTER_REACHABLE)
                .addOnSuccessListener { info ->
                    nodeId = info.nodes.firstOrNull()?.id
                    reachable.value = nodeId != null
                }
        }
    }

    fun onMessage(path: String, data: ByteArray) {
        when (path) {
            WearPaths.STATE -> {
                val decoded = runCatching { WearCodec.decodeState(data) }.getOrNull() ?: return
                state.value = decoded
                reachable.value = true
                val context = appContext ?: return
                if (decoded.hasEpisode && decoded.playing) {
                    OngoingPlayback.show(context, decoded)
                } else {
                    OngoingPlayback.hide(context)
                }
            }
            WearPaths.REPLY -> {
                val reply = runCatching { WearCodec.decodeReply(data) }.getOrNull() ?: return
                pending.remove(reply.requestId)?.complete(reply)
            }
        }
    }

    suspend fun command(name: String, argument: String? = null): WearReply? {
        val node = phoneNode() ?: return null
        val requestId = ids.incrementAndGet().toString()
        val deferred = CompletableDeferred<WearReply>()
        pending[requestId] = deferred
        return try {
            val payload = WearCodec.encodeCommand(WearCommand(name, argument, requestId))
            val context = appContext ?: return null
            Wearable.getMessageClient(context)
                .sendMessage(node, WearPaths.COMMAND, payload)
                .await()
            withTimeout(8_000) { deferred.await() }
        } catch (timeout: TimeoutCancellationException) {
            null
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Exception) {
            null
        } finally {
            pending.remove(requestId)
        }
    }

    private suspend fun phoneNode(): String? {
        nodeId?.let { return it }
        val context = appContext ?: return null
        return try {
            val info =
                Wearable.getCapabilityClient(context)
                    .getCapability(WearPaths.PHONE, CapabilityClient.FILTER_REACHABLE)
                    .await()
            val id = info.nodes.firstOrNull()?.id
            nodeId = id
            reachable.value = id != null
            id
        } catch (cancelled: CancellationException) {
            throw cancelled
        } catch (_: Exception) {
            null
        }
    }
}
