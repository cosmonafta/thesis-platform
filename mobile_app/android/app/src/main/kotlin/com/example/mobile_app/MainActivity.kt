package com.example.mobile_app
import io.flutter.plugin.common.MethodChannel
import android.Manifest
import android.content.pm.PackageManager
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioManager
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

                        audioTrack?.write(
                            audioData,
                            0,
                            audioData.size
                        )

                        result.success(null)

                    } else {

                        result.error(
                            "INVALID_AUDIO",
                            "Audio data was null",
                            null
                        )
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
    // INITIALIZE AUDIO PLAYBACK
    // ============================================================

    private fun initializeAudioTrack() {

        if (audioTrack != null) {
            return
        }

        val sampleRate = 48000

        // ========================================================
        // AUDIO ROUTING
        // ========================================================

        val audioManager =
            getSystemService(
                AUDIO_SERVICE
            ) as AudioManager

        // Tell Android that this is a voice communication session.
        audioManager.mode =
            AudioManager.MODE_IN_COMMUNICATION

        // Explicitly disable the loudspeaker.
        //
        // This is important for the OnePlus 5 / Android 10,
        // where Android otherwise selected the loudspeaker.

        @Suppress("DEPRECATION")
        audioManager.isSpeakerphoneOn = false

        Log.i(
            "AudioRouting",
            "Communication mode enabled, speakerphone OFF"
        )

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

        Log.i(
            "AudioPlayback",
            "AudioTrack initialized"
        )
    }

    // ============================================================
    // STOP AUDIO PLAYBACK
    // ============================================================

    private fun stopAudioTrack() {

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