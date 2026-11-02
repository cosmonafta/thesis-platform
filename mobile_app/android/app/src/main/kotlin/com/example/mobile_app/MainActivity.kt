package com.example.mobile_app
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
import android.media.AudioDeviceInfo
import android.media.AudioDeviceCallback
import android.os.Handler
import android.os.Looper
import android.os.Build
import android.media.AudioRecord
import android.media.AudioTrack
import android.media.MediaRecorder
import android.media.audiofx.AcousticEchoCanceler
import android.util.Log
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import java.util.Locale
import java.util.ArrayDeque
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {

    // ============================================================
    // CHANNEL NAMES
    // ============================================================

    private val PLAYBACK_CHANNEL =
        "com.example.mobile_app/audio_playback"

    private val CAPTURE_CHANNEL =
        "com.example.mobile_app/audio_capture"

    private val AUDIO_STREAM_CHANNEL =
        "com.example.mobile_app/audio_capture_stream"

    // ============================================================
    // AUDIO OBJECTS
    // ============================================================

    private var audioTrack: AudioTrack? = null

    // One playback writer; both network streams are mixed into its PCM frames.
    private val mixerLock = Object()
    private val remoteQueue = ArrayDeque<ByteArray>()
    private val echoQueue = ArrayDeque<ByteArray>()
    @Volatile private var mixerRunning = false
    private var mixerThread: Thread? = null
    private val frameBytes = 960 // 10 ms, 48 kHz, PCM16 mono
    private val maxQueuedFrames = 30 // Cap queue growth at ~300 ms

    private fun enqueuePcm(input: ByteArray, echo: Boolean) {
        synchronized(mixerLock) {
            val queue = if (echo) echoQueue else remoteQueue
            var offset = 0
            while (offset + 1 < input.size) {
                val frame = ByteArray(frameBytes)
                val count = minOf(frameBytes, input.size - offset)
                val evenCount = count - count % 2
                System.arraycopy(input, offset, frame, 0, evenCount)
                if (queue.size >= maxQueuedFrames) queue.removeFirst()
                queue.addLast(frame)
                offset += evenCount
            }
        }
    }

    private fun mixFrames(remote: ByteArray?, echo: ByteArray?): ByteArray {
        val mixed = ByteArray(frameBytes)
        for (i in 0 until frameBytes step 2) {
            val a = if (remote == null) 0 else
                ((remote[i].toInt() and 0xff) or (remote[i + 1].toInt() shl 8)).toShort().toInt()
            val b = if (echo == null) 0 else
                ((echo[i].toInt() and 0xff) or (echo[i + 1].toInt() shl 8)).toShort().toInt()
            val sum = (a + b).coerceIn(-32768, 32767)
            mixed[i] = sum.toByte()
            mixed[i + 1] = (sum shr 8).toByte()
        }
        return mixed
    }

    private fun startMixer() {
        mixerRunning = true
        mixerThread = thread(start = true, name = "NativeAudioMixer") {
            val silence = ByteArray(frameBytes)
            while (mixerRunning) {
                val frames = synchronized(mixerLock) {
                    Pair(
                        if (remoteQueue.isEmpty()) null else remoteQueue.removeFirst(),
                        if (echoQueue.isEmpty()) null else echoQueue.removeFirst()
                    )
                }
                val pcm = if (frames.first == null && frames.second == null) silence
                          else mixFrames(frames.first, frames.second)
                // Blocking write is on this worker, never Flutter's UI thread.
                val track = audioTrack ?: break
                val written = track.write(pcm, 0, pcm.size, AudioTrack.WRITE_BLOCKING)
                if (written < 0) {
                    Log.w("AudioPlayback", "Mixer AudioTrack write error: $written")
                    break
                }
            }
        }
    }

    private var audioRecord: AudioRecord? = null

    // Acoustic Echo Canceler
    private var echoCanceler: AcousticEchoCanceler? = null
    private var experimentDiscovery: ExperimentDiscovery? = null

    // ============================================================
    // CAPTURE STATE
    // ============================================================

    @Volatile
    private var recording = false

    private var recordingThread: Thread? = null

    private var audioSink: EventChannel.EventSink? = null

    // ============================================================
    // FLUTTER ENGINE
    // ============================================================


  


    override fun configureFlutterEngine(
        flutterEngine: FlutterEngine
    ) {
        super.configureFlutterEngine(flutterEngine)

        experimentDiscovery = ExperimentDiscovery(this)

MethodChannel(
    flutterEngine.dartExecutor.binaryMessenger,
    "sct/experiment_discovery"
).setMethodCallHandler(experimentDiscovery)


        // ========================================================
        // RECORDING STORAGE METHOD CHANNEL
        // ========================================================

        val recordingStorage = RecordingStorage(this)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "sct/recording_storage"
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "publishRecording" -> {

                    val sourcePath =
                        call.argument<String>("sourcePath")

                    val displayName =
                        call.argument<String>("displayName")

                    if (sourcePath == null || displayName == null) {
                        result.error(
                            "INVALID_ARGUMENTS",
                            "sourcePath and displayName are required",
                            null
                        )
                    } else {
                        try {
                            val publishedUri =
                                recordingStorage.publishRecording(
                                    sourcePath,
                                    displayName
                                )

                            result.success(publishedUri)

                        } catch (e: Exception) {
                            result.error(
                                "PUBLISH_ERROR",
                                e.message,
                                null
                            )
                        }
                    }
                }
"publishPdf" -> {
    val sourcePath = call.argument<String>("sourcePath")
    val displayName = call.argument<String>("displayName")

    if (sourcePath == null || displayName == null) {
        result.error(
            "INVALID_ARGUMENTS",
            "sourcePath and displayName are required",
            null
        )
    } else {
        try {
            result.success(
                recordingStorage.publishPdf(
                    sourcePath,
                    displayName
                )
            )
        } catch (e: Exception) {
            result.error(
                "PDF_PUBLISH_ERROR",
                e.message,
                null
            )
        }
    }
}
"publishCsv" -> {
    val sourcePath = call.argument<String>("sourcePath")!!
    val displayName = call.argument<String>("displayName")!!

    try {
        val uri = CsvStorage(this)
            .publishCsv(sourcePath, displayName)
        result.success(uri)
    } catch (e: Exception) {
        result.error("CSV_SAVE_ERROR", e.message, null)
    }
}

                else -> result.notImplemented()
            }
        }




        // ========================================================
        // PLAYBACK METHOD CHANNEL
        // ========================================================

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            PLAYBACK_CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "initialize" -> {

                    initializeAudioTrack()

                    result.success(null)
                }

                "playAudio" -> {

                    val audioData =
                        call.arguments as? ByteArray

                    if (audioData != null) {

                        enqueuePcm(audioData, echo = false)

                        result.success(null)

                    } else {

                        result.error(
                            "INVALID_AUDIO",
                            "Audio data was null",
                            null
                        )
                    }
                }

                "playEcho" -> {
                    val audioData = call.arguments as? ByteArray
                    if (audioData != null) {
                        enqueuePcm(audioData, echo = true)
                        result.success(null)
                    } else {
                        result.error("INVALID_AUDIO", "Echo audio was null", null)
                    }
                }

                "stop" -> {

                    stopAudioTrack()

                    result.success(null)
                }

                else -> {

                    result.notImplemented()
                }
            }
        }

        // ========================================================
        // CAPTURE METHOD CHANNEL
        // ========================================================

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CAPTURE_CHANNEL
        ).setMethodCallHandler { call, result ->

            when (call.method) {

                "start" -> {

                    try {

                        startAudioCapture()

                        result.success(null)

                    } catch (e: Exception) {

                        result.error(
                            "CAPTURE_ERROR",
                            e.message,
                            null
                        )
                    }
                }

                "stop" -> {

                    stopAudioCapture()

                    result.success(null)
                }

                else -> {

                    result.notImplemented()
                }
            }
        }

        // ========================================================
        // AUDIO EVENT CHANNEL
        // ========================================================

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            AUDIO_STREAM_CHANNEL
        ).setStreamHandler(

            object : EventChannel.StreamHandler {

                override fun onListen(
                    arguments: Any?,
                    events: EventChannel.EventSink?
                ) {

                    audioSink = events
                }

                override fun onCancel(
                    arguments: Any?
                ) {

                    audioSink = null
                }
            }
        )
    }

    // ============================================================
    // START AUDIO CAPTURE
    // ============================================================

    private fun startAudioCapture() {

        if (recording) {
            return
        }

        // --------------------------------------------------------
        // CHECK MICROPHONE PERMISSION
        // --------------------------------------------------------

        if (
            ActivityCompat.checkSelfPermission(
                this,
                Manifest.permission.RECORD_AUDIO
            ) != PackageManager.PERMISSION_GRANTED
        ) {

            throw SecurityException(
                "Microphone permission not granted"
            )
        }

        // --------------------------------------------------------
        // AUDIO SETTINGS
        // --------------------------------------------------------

        val sampleRate = 48000

        val minBufferSize =
            AudioRecord.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_IN_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )

        audioRecord = AudioRecord(
            MediaRecorder.AudioSource.VOICE_COMMUNICATION,
            sampleRate,
            AudioFormat.CHANNEL_IN_MONO,
            AudioFormat.ENCODING_PCM_16BIT,
            minBufferSize
        )

        // ========================================================
        // ACOUSTIC ECHO CANCELLATION
        // ========================================================

        if (AcousticEchoCanceler.isAvailable()) {

            echoCanceler =
                AcousticEchoCanceler.create(
                    audioRecord!!.audioSessionId
                )

            if (echoCanceler != null) {

                echoCanceler?.enabled = true

                Log.i(
                    "AudioAEC",
                    "Acoustic Echo Canceler enabled: " +
                        echoCanceler?.enabled
                )

            } else {

                Log.w(
                    "AudioAEC",
                    "Could not create Acoustic Echo Canceler"
                )
            }

        } else {

            Log.w(
                "AudioAEC",
                "Acoustic Echo Canceler not available on this device"
            )
        }

        recording = true

        audioRecord?.startRecording()

        // Audio capture can change the communication route on some devices.
        // Re-select the speaker after the microphone starts.
        enableLoudspeaker()

        // ========================================================
        // RECORDING THREAD
        // ========================================================

        recordingThread = thread(
            start = true,
            name = "NativeAudioCapture"
        ) {

            // ----------------------------------------------------
            // 960 bytes =
            // 480 samples × 2 bytes
            //
            // At 48 kHz:
            //
            // 480 / 48000 = 0.010 seconds
            //
            // Therefore each chunk represents
            // approximately 10 ms of audio.
            // ----------------------------------------------------

            val chunkSize = 960

            val buffer =
                ByteArray(chunkSize)

            // ====================================================
            // NATIVE TIMING MEASUREMENT
            // ====================================================

            var lastReadNs = 0L

            var timingCount = 0

            var timingSumMs = 0.0

            var timingMinMs =
                Double.MAX_VALUE

            var timingMaxMs = 0.0

            var lateReads = 0

            // ====================================================
            // CAPTURE LOOP
            // ====================================================

            while (recording) {

                val bytesRead =
                    audioRecord?.read(
                        buffer,
                        0,
                        buffer.size
                    ) ?: 0

                if (bytesRead > 0) {

                    // ============================================
                    // MEASURE NATIVE AUDIORECORD TIMING
                    // ============================================

                    val nowNs =
                        System.nanoTime()

                    if (lastReadNs != 0L) {

                        val intervalMs =
                            (nowNs - lastReadNs) /
                                1_000_000.0

                        timingCount++

                        timingSumMs +=
                            intervalMs

                        if (
                            intervalMs <
                            timingMinMs
                        ) {

                            timingMinMs =
                                intervalMs
                        }

                        if (
                            intervalMs >
                            timingMaxMs
                        ) {

                            timingMaxMs =
                                intervalMs
                        }

                        if (
                            intervalMs > 20.0
                        ) {

                            lateReads++
                        }

                        // ========================================
                        // PRINT ONCE EVERY 100 READS
                        // ========================================

                        if (
                            timingCount % 100 == 0
                        ) {

                            val averageMs =
                                timingSumMs /
                                    100.0

                            Log.i(
                                "AudioCaptureTiming",
                                "100 native reads: " +
                                    "average=" +
                                    String.format(
                                        Locale.US,
                                        "%.2f",
                                        averageMs
                                    ) +
                                    " ms, min=" +
                                    String.format(
                                        Locale.US,
                                        "%.2f",
                                        timingMinMs
                                    ) +
                                    " ms, max=" +
                                    String.format(
                                        Locale.US,
                                        "%.2f",
                                        timingMaxMs
                                    ) +
                                    " ms, late(>20ms)=" +
                                    lateReads
                            )

                            // Reset statistics for
                            // the next 100 native reads.

                            timingSumMs = 0.0

                            timingMinMs =
                                Double.MAX_VALUE

                            timingMaxMs = 0.0

                            lateReads = 0
                        }
                    }

                    lastReadNs = nowNs

                    // ============================================
                    // COPY AUDIO
                    // ============================================

                    val audioChunk =
                        buffer.copyOf(
                            bytesRead
                        )

                    // ============================================
                    // SEND AUDIO TO FLUTTER
                    // ============================================

                    runOnUiThread {

                        audioSink?.success(
                            audioChunk
                        )
                    }
                }
            }
        }

        Log.i(
            "AudioCaptureTiming",
            "Native audio capture started"
        )
    }

    // ============================================================
    // STOP AUDIO CAPTURE
    // ============================================================

    private fun stopAudioCapture() {

        recording = false

        try {

            audioRecord?.stop()

        } catch (_: Exception) {
        }

        try {

            recordingThread?.join(
                500
            )

        } catch (_: InterruptedException) {
        }

        recordingThread = null

        // ========================================================
        // RELEASE ECHO CANCELLER
        // ========================================================

        echoCanceler?.release()

        echoCanceler = null

        // ========================================================
        // RELEASE AUDIO RECORD
        // ========================================================

        audioRecord?.release()

        audioRecord = null

        Log.i(
            "AudioCaptureTiming",
            "Native audio capture stopped"
        )
    }

    // ============================================================
    // AUTOMATIC HEADPHONE / SPEAKER ROUTING
    // ============================================================

    private var routeCallback: AudioDeviceCallback? = null
    private var selectedPlaybackDeviceId: Int? = null

    private fun watchAudioDevices() {
        if (routeCallback != null) return
        val manager = getSystemService(AUDIO_SERVICE) as AudioManager
        routeCallback = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(addedDevices: Array<out AudioDeviceInfo>) {
                enableLoudspeaker()
            }
            override fun onAudioDevicesRemoved(removedDevices: Array<out AudioDeviceInfo>) {
                enableLoudspeaker()
            }
        }
        manager.registerAudioDeviceCallback(routeCallback, Handler(Looper.getMainLooper()))
    }

    private fun stopWatchingAudioDevices() {
        val manager = getSystemService(AUDIO_SERVICE) as AudioManager
        routeCallback?.let { manager.unregisterAudioDeviceCallback(it) }
        routeCallback = null
    }

    // Kept the original function name to avoid touching capture/playback callers.
    // Headphones are preferred, but never required.
    // Explicitly bind OUR AudioTrack to the selected physical output.
    private fun enableLoudspeaker() {
        val manager = getSystemService(AUDIO_SERVICE) as AudioManager
        manager.mode = AudioManager.MODE_IN_COMMUNICATION

        val outputs = manager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
        fun priority(device: AudioDeviceInfo): Int = when (device.type) {
            AudioDeviceInfo.TYPE_WIRED_HEADSET,
            AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
            AudioDeviceInfo.TYPE_USB_HEADSET,
            AudioDeviceInfo.TYPE_USB_DEVICE -> 0
            AudioDeviceInfo.TYPE_BLUETOOTH_A2DP -> 1
            AudioDeviceInfo.TYPE_BLUETOOTH_SCO -> 2
            AudioDeviceInfo.TYPE_BUILTIN_SPEAKER -> 10
            else -> 100
        }
        val target = outputs.filter {
            priority(it) < 100 || (Build.VERSION.SDK_INT >= 33 &&
                it.type == AudioDeviceInfo.TYPE_BLE_HEADSET)
        }.minByOrNull {
            if (Build.VERSION.SDK_INT >= 33 && it.type == AudioDeviceInfo.TYPE_BLE_HEADSET) 3
            else priority(it)
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            // Communication routing can differ from the actual AudioTrack route.
            // Set it for compatible devices, then also bind the playback track.
            val communicationTarget = manager.availableCommunicationDevices.firstOrNull {
                it.id == target?.id
            }
            try {
                if (communicationTarget != null) {
                    manager.setCommunicationDevice(communicationTarget)
                } else if (target?.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER) {
                    manager.availableCommunicationDevices.firstOrNull {
                        it.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
                    }?.let { manager.setCommunicationDevice(it) }
                } else {
                    manager.clearCommunicationDevice()
                }
            } catch (error: Exception) {
                Log.w("AudioRouting", "Communication route selection failed: $error")
            }
        } else {
            @Suppress("DEPRECATION")
            manager.isSpeakerphoneOn = target == null ||
                target.type == AudioDeviceInfo.TYPE_BUILTIN_SPEAKER
            if (target?.type == AudioDeviceInfo.TYPE_BLUETOOTH_SCO) {
                try {
                    @Suppress("DEPRECATION")
                    manager.startBluetoothSco()
                } catch (error: Exception) {
                    Log.w("AudioRouting", "Bluetooth SCO setup failed: $error")
                }
            }
        }

        val track = audioTrack
        if (track != null) {
            try {
                val applied = track.setPreferredDevice(target)
                selectedPlaybackDeviceId = if (applied) target?.id else null
                Log.i("AudioRouting", "AudioTrack preferred output: type=${target?.type}, id=${target?.id}, applied=$applied, routed=${track.routedDevice?.type}")
            } catch (error: Exception) {
                Log.w("AudioRouting", "AudioTrack output selection failed: $error")
            }
        }
        Log.i("AudioRouting", "Detected playback output: type=${target?.type}, id=${target?.id}")
    }

    // ============================================================
    // INITIALIZE AUDIO PLAYBACK
    // ============================================================

    private fun initializeAudioTrack() {
        // Apply routing on every initialize request, even if the
        // AudioTrack already exists.
        watchAudioDevices()
        enableLoudspeaker()

        if (audioTrack != null) {
            return
        }

        val sampleRate = 48000

        // ========================================================
        // CREATE AUDIOTRACK
        // ========================================================

        val minBufferSize =
            AudioTrack.getMinBufferSize(
                sampleRate,
                AudioFormat.CHANNEL_OUT_MONO,
                AudioFormat.ENCODING_PCM_16BIT
            )

        audioTrack = AudioTrack(
            AudioAttributes.Builder()
                .setUsage(
                    AudioAttributes.USAGE_VOICE_COMMUNICATION
                )
                .setContentType(
                    AudioAttributes.CONTENT_TYPE_SPEECH
                )
                .build(),

            AudioFormat.Builder()
                .setEncoding(
                    AudioFormat.ENCODING_PCM_16BIT
                )
                .setSampleRate(
                    sampleRate
                )
                .setChannelMask(
                    AudioFormat.CHANNEL_OUT_MONO
                )
                .build(),

            minBufferSize,

            AudioTrack.MODE_STREAM,

            AudioManager.AUDIO_SESSION_ID_GENERATE
        )

        audioTrack?.play()
        startMixer()

        // Some Android devices re-evaluate the route when playback begins.
        enableLoudspeaker()

        Log.i(
            "AudioPlayback",
            "AudioTrack initialized"
        )
    }

    // ============================================================
    // STOP AUDIO PLAYBACK
    // ============================================================

    private fun stopAudioTrack() {
        stopWatchingAudioDevices()
        mixerRunning = false
        // Stop unblocks any pending blocking write before joining the worker.
        try { audioTrack?.pause() } catch (_: Exception) {}
        try { audioTrack?.flush() } catch (_: Exception) {}
        try { audioTrack?.stop() } catch (_: Exception) {}
        try { mixerThread?.join(500) } catch (_: InterruptedException) {}
        mixerThread = null
        synchronized(mixerLock) {
            remoteQueue.clear()
            echoQueue.clear()
        }

        try {

            audioTrack?.stop()

        } catch (_: Exception) {
        }

        audioTrack?.release()

        audioTrack = null

        // ========================================================
        // RESTORE NORMAL AUDIO MODE
        // ========================================================

        val audioManager =
            getSystemService(
                AUDIO_SERVICE
            ) as AudioManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            audioManager.clearCommunicationDevice()
        } else {
            @Suppress("DEPRECATION")
            audioManager.isSpeakerphoneOn = false
        }

        audioManager.mode =
            AudioManager.MODE_NORMAL

        Log.i(
            "AudioRouting",
            "Audio mode restored to normal"
        )

        Log.i(
            "AudioPlayback",
            "AudioTrack stopped"
        )
    }

    // ============================================================
    // CLEANUP
    // ============================================================

    override fun onDestroy() {

        stopAudioCapture()

        stopAudioTrack()

         experimentDiscovery?.dispose()

        super.onDestroy()
    }
}