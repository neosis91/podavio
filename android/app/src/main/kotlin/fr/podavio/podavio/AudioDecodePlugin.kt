package fr.podavio.podavio

import android.content.Context
import android.media.AudioFormat
import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder

/**
 * Décode un épisode téléchargé en PCM mono 16 bits, en écrivant au fil
 * de l’eau. Les URI `content:` passent par le ContentResolver.
 */
object AudioDecodePlugin {
    const val CHANNEL = "fr.podavio.podavio/audio_decode"

    @Volatile
    private var progressSink: EventChannel.EventSink? = null
    private var lastProgressAt = 0L

    fun attach(engine: FlutterEngine, context: Context) {
        val main = Handler(Looper.getMainLooper())
        EventChannel(engine.dartExecutor.binaryMessenger, "$CHANNEL/progress")
            .setStreamHandler(
                object : EventChannel.StreamHandler {
                    override fun onListen(arguments: Any?, events: EventChannel.EventSink) {
                        progressSink = events
                    }

                    override fun onCancel(arguments: Any?) {
                        progressSink = null
                    }
                },
            )
        MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "decodeToPcm") {
                result.notImplemented()
                return@setMethodCallHandler
            }
            val path = call.argument<String>("path")?.trim().orEmpty()
            val sampleRate = call.argument<Int>("sampleRate") ?: 11025
            val deadlineMs = call.argument<Int>("deadlineMs") ?: 360_000
            if (path.isEmpty()) {
                result.success(null)
                return@setMethodCallHandler
            }
            // Jamais le thread principal : MediaCodec synchrone y provoque un ANR.
            Thread {
                try {
                    val decoded = decode(context, path, sampleRate, deadlineMs.toLong())
                    main.post { result.success(decoded) }
                } catch (error: Exception) {
                    main.post { result.error("decode", error.message, null) }
                }
            }.start()
        }
    }

    private fun decode(
        context: Context,
        path: String,
        targetRate: Int,
        deadlineMs: Long,
    ): Map<String, Any?>? {
        val extractor = MediaExtractor()
        var codec: MediaCodec? = null
        var outFile: File? = null
        try {
            if (path.startsWith("content:")) {
                extractor.setDataSource(context, Uri.parse(path), null)
            } else {
                extractor.setDataSource(path)
            }
            var track = -1
            var format: MediaFormat? = null
            for (index in 0 until extractor.trackCount) {
                val candidate = extractor.getTrackFormat(index)
                val mime = candidate.getString(MediaFormat.KEY_MIME) ?: continue
                if (mime.startsWith("audio/")) {
                    track = index
                    format = candidate
                    break
                }
            }
            if (track < 0 || format == null) return null
            extractor.selectTrack(track)
            val mime = format.getString(MediaFormat.KEY_MIME) ?: return null
            codec = MediaCodec.createDecoderByType(mime)
            codec.configure(format, null, null, 0)
            codec.start()
            outFile = File.createTempFile("podavio-pcm-", ".pcm", context.cacheDir)
            FileOutputStream(outFile).use { stream ->
                val writer = PcmWriter(targetRate, stream)
                if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE) ||
                    format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)
                ) {
                    writer.update(format)
                }
                val info = MediaCodec.BufferInfo()
                var inputDone = false
                var outputDone = false
                var idle = 0
                var emptyReads = 0
                var failed = false
                val deadline = SystemClock.elapsedRealtime() + deadlineMs.coerceAtLeast(1_000)
                val durationUs = if (format.containsKey(MediaFormat.KEY_DURATION)) {
                    format.getLong(MediaFormat.KEY_DURATION)
                } else {
                    0L
                }
                val expected = if (durationUs > 0L) {
                    durationUs * targetRate / 1_000_000L
                } else {
                    0L
                }
                while (!outputDone) {
                    if (SystemClock.elapsedRealtime() >= deadline) {
                        failed = true
                        break
                    }
                    var progressed = false
                    if (!inputDone) {
                        val inIndex = codec.dequeueInputBuffer(10_000)
                        if (inIndex >= 0) {
                            val buffer = codec.getInputBuffer(inIndex)
                            if (buffer == null) {
                                codec.queueInputBuffer(inIndex, 0, 0, 0, 0)
                            } else {
                                val size = extractor.readSampleData(buffer, 0)
                                if (size == 0) emptyReads += 1
                                if (size > 0) emptyReads = 0
                                val exhausted = size < 0 || emptyReads >= 8
                                if (exhausted) {
                                    codec.queueInputBuffer(
                                        inIndex,
                                        0,
                                        0,
                                        0,
                                        MediaCodec.BUFFER_FLAG_END_OF_STREAM,
                                    )
                                    inputDone = true
                                } else {
                                    codec.queueInputBuffer(
                                        inIndex,
                                        0,
                                        size.coerceAtLeast(0),
                                        extractor.sampleTime.coerceAtLeast(0),
                                        0,
                                    )
                                    extractor.advance()
                                }
                            }
                            progressed = true
                        }
                    }
                    when (val outIndex = codec.dequeueOutputBuffer(info, 10_000)) {
                        MediaCodec.INFO_TRY_AGAIN_LATER -> Unit
                        MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                            writer.update(codec.outputFormat)
                            progressed = true
                        }
                        else -> {
                            if (outIndex >= 0) {
                                val config = info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG != 0
                                if (!config && info.size > 0) {
                                    codec.getOutputBuffer(outIndex)?.let { buffer ->
                                        writer.write(buffer, info)
                                    }
                                }
                                val end = info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0
                                codec.releaseOutputBuffer(outIndex, false)
                                progressed = true
                                if (end) outputDone = true
                            }
                        }
                    }
                    if (progressed) {
                        idle = 0
                        reportProgress(writer.written, expected, targetRate)
                    } else {
                        idle += 1
                        // 200 essais après la fin d’entrée, 500 si elle n’arrive pas.
                        // Même politique que test/codec_drain_test.dart.
                        if (inputDone && idle > 200) outputDone = true
                        if (!inputDone && idle > 500) {
                            failed = true
                            outputDone = true
                        }
                    }
                }
                writer.finish()
                if (failed || writer.written <= 0L) {
                    outFile.delete()
                    return null
                }
                return mapOf(
                    "path" to outFile.absolutePath,
                    "sampleRate" to targetRate,
                    "samples" to writer.written,
                    "durationMs" to writer.written * 1000L / targetRate,
                )
            }
        } catch (error: Exception) {
            outFile?.delete()
            throw error
        } finally {
            try {
                codec?.stop()
            } catch (_: Exception) {
            }
            codec?.release()
            extractor.release()
        }
    }

    /// Échantillons déjà écrits, au plus toutes les 400 ms.
    private fun reportProgress(samples: Long, expected: Long, sampleRate: Int) {
        val now = SystemClock.elapsedRealtime()
        if (now - lastProgressAt < 400L) return
        lastProgressAt = now
        val sink = progressSink ?: return
        Handler(Looper.getMainLooper()).post {
            if (progressSink !== sink) return@post
            sink.success(
                mapOf(
                    "samples" to samples,
                    "expected" to expected,
                    "sampleRate" to sampleRate,
                ),
            )
        }
    }
}

/**
 * Mélange vers le mono et rééchantillonne en linéaire, sans garder
 * le PCM source.
 */
private class PcmWriter(
    private val targetRate: Int,
    stream: FileOutputStream,
) {
    private val out = stream.buffered()
    private var sourceRate = targetRate
    private var channels = 1
    private var floatPcm = false
    private val pending = ArrayList<Double>(8192)
    private var head = 0
    private var base = 0.0
    private var cursor = 0.0
    var written = 0L
        private set

    fun update(format: MediaFormat) {
        if (format.containsKey(MediaFormat.KEY_SAMPLE_RATE)) {
            sourceRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE).coerceAtLeast(1)
        }
        if (format.containsKey(MediaFormat.KEY_CHANNEL_COUNT)) {
            channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT).coerceAtLeast(1)
        }
        if (format.containsKey(MediaFormat.KEY_PCM_ENCODING)) {
            floatPcm = format.getInteger(MediaFormat.KEY_PCM_ENCODING) ==
                AudioFormat.ENCODING_PCM_FLOAT
        }
    }

    fun write(buffer: ByteBuffer, info: MediaCodec.BufferInfo) {
        buffer.position(info.offset)
        buffer.limit(info.offset + info.size)
        buffer.order(ByteOrder.LITTLE_ENDIAN)
        val frameBytes = (if (floatPcm) 4 else 2) * channels
        if (frameBytes <= 0 || info.size < frameBytes) return
        val frames = info.size / frameBytes
        repeat(frames) {
            var sum = 0.0
            repeat(channels) {
                sum += if (floatPcm) buffer.float.toDouble() else buffer.short.toDouble()
            }
            pending.add(sum / channels)
        }
        drain()
    }

    fun finish() {
        if (sourceRate == targetRate) {
            while (head < pending.size) {
                emit(pending[head])
                head += 1
            }
        }
        out.flush()
    }

    private fun drain() {
        if (sourceRate == targetRate) {
            while (head < pending.size) {
                emit(pending[head])
                head += 1
            }
            compact()
            return
        }
        val step = sourceRate.toDouble() / targetRate.toDouble()
        val available = pending.size - head
        val end = base + available
        while (cursor + 1.0 < end) {
            val index = (cursor - base).toInt()
            if (index < 0 || index + 1 >= available) break
            val frac = cursor - base - index
            val left = pending[head + index]
            val right = pending[head + index + 1]
            emit(left * (1.0 - frac) + right * frac)
            cursor += step
        }
        val drop = (cursor - base).toInt()
        if (drop > 0) {
            head += drop.coerceAtMost(available)
            base += drop
            cursor = cursor.coerceAtLeast(base)
        }
        compact()
    }

    private fun compact() {
        if (head == 0 || head < 4096) return
        if (head >= pending.size) {
            pending.clear()
            head = 0
            return
        }
        val tail = ArrayList<Double>(pending.size - head)
        for (index in head until pending.size) tail.add(pending[index])
        pending.clear()
        pending.addAll(tail)
        head = 0
    }

    private fun emit(sample: Double) {
        val clipped = sample.coerceIn(-32768.0, 32767.0).toInt()
        out.write(clipped and 0xff)
        out.write((clipped shr 8) and 0xff)
        written += 1
    }
}
