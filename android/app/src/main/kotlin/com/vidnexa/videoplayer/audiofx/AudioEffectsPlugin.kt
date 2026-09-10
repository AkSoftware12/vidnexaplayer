package com.vidnexa.videoplayer.audiofx

import android.content.Context
import android.media.AudioDeviceCallback
import android.media.AudioDeviceInfo
import android.media.AudioManager
import android.media.audiofx.AudioEffect
import android.media.audiofx.BassBoost
import android.media.audiofx.Equalizer
import android.media.audiofx.LoudnessEnhancer
import android.media.audiofx.PresetReverb
import android.media.audiofx.Virtualizer
import android.media.audiofx.Visualizer
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlin.math.hypot
import kotlin.math.ln
import kotlin.math.max
import kotlin.math.min
import kotlin.math.pow
import kotlin.math.sqrt

/**
 * Bridges `android.media.audiofx` to Dart for BOTH the music player
 * (just_audio -> real ExoPlayer session id) and the video player
 * (media_kit/mpv -> a session id we generate and hand to libmpv via
 * `audiotrack-session-id`; Dart falls back to an mpv filter chain when that
 * property does not exist in the bundled libmpv).
 *
 * Every effect lives in a per-session [Bundle], so a track/video change only
 * tears down the bundle for the OLD session id — the classic leak that later
 * shows up as "effect creation failed". Nothing here throws into Dart: an
 * unsupported effect degrades to a `false` capability flag, never to a crash.
 */
class AudioEffectsPlugin(
    context: Context,
    messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "AudioEffectsPlugin"
        const val METHOD_CHANNEL = "vidnexa/audio_effects"
        const val VISUALIZER_CHANNEL = "vidnexa/audio_effects/visualizer"
        const val DEVICE_CHANNEL = "vidnexa/audio_effects/output_device"

        /** Number of spectrum bars pushed to the UI painter. */
        private const val BAR_COUNT = 32

        /** Bucket edges (Hz) the rule-based content classifier reasons about. */
        private val BAND_EDGES =
            doubleArrayOf(20.0, 60.0, 250.0, 500.0, 2000.0, 4000.0, 16000.0)

        /** Min gap between two visualizer frames pushed to Dart (~20 fps). */
        private const val EMIT_INTERVAL_MS = 50L
    }

    private val main = Handler(Looper.getMainLooper())
    private val audioManager =
        context.getSystemService(Context.AUDIO_SERVICE) as AudioManager

    private val methodChannel = MethodChannel(messenger, METHOD_CHANNEL).also {
        it.setMethodCallHandler(this)
    }
    private val visualizerChannel = EventChannel(messenger, VISUALIZER_CHANNEL)
    private val deviceChannel = EventChannel(messenger, DEVICE_CHANNEL)

    private var visualizerSink: EventChannel.EventSink? = null
    private var deviceSink: EventChannel.EventSink? = null

    /** One bundle per audio session id currently in use. */
    private val bundles = HashMap<Int, Bundle>()

    private var deviceCallback: AudioDeviceCallback? = null

    init {
        visualizerChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                visualizerSink = events
            }

            override fun onCancel(arguments: Any?) {
                visualizerSink = null
            }
        })

        deviceChannel.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                deviceSink = events
                events?.success(currentOutputDevice())
                registerDeviceCallback()
            }

            override fun onCancel(arguments: Any?) {
                deviceSink = null
                unregisterDeviceCallback()
            }
        })
    }

    // ── lifecycle ────────────────────────────────────────────────────────────

    /** Called from MainActivity.cleanUpFlutterEngine — releases every effect. */
    fun dispose() {
        releaseAll()
        unregisterDeviceCallback()
        methodChannel.setMethodCallHandler(null)
        visualizerChannel.setStreamHandler(null)
        deviceChannel.setStreamHandler(null)
    }

    // ── MethodChannel ────────────────────────────────────────────────────────

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "generateSessionId" -> result.success(generateSessionId())

                "attach" -> result.success(
                    attach(
                        call.argument<Int>("sessionId") ?: 0,
                        call.argument<Boolean>("allowGlobalFallback") ?: false,
                    )
                )

                "release" -> {
                    release(call.argument<Int>("sessionId") ?: 0)
                    result.success(true)
                }

                "releaseAll" -> {
                    releaseAll()
                    result.success(true)
                }

                "setEnabled" -> result.success(
                    withBundle(call) {
                        it.setEnabled(call.argument<Boolean>("enabled") ?: false)
                    }
                )

                "setBandLevel" -> result.success(
                    withBundle(call) {
                        it.setBandLevel(
                            call.argument<Int>("band") ?: 0,
                            call.argument<Int>("levelMb") ?: 0,
                        )
                    }
                )

                "setBandLevels" -> result.success(
                    withBundle(call) {
                        it.setBandLevels(call.argument<List<Int>>("levelsMb") ?: emptyList())
                    }
                )

                "setBassBoost" -> result.success(
                    withBundle(call) { it.setBassBoost(call.argument<Int>("strength") ?: 0) }
                )

                "setVirtualizer" -> result.success(
                    withBundle(call) { it.setVirtualizer(call.argument<Int>("strength") ?: 0) }
                )

                "setReverb" -> result.success(
                    withBundle(call) { it.setReverb(call.argument<Int>("preset") ?: 0) }
                )

                "setLoudness" -> result.success(
                    withBundle(call) { it.setLoudness(call.argument<Int>("gainMb") ?: 0) }
                )

                "setVisualizerEnabled" -> result.success(
                    withBundle(call) {
                        it.setVisualizerEnabled(call.argument<Boolean>("enabled") ?: false)
                    }
                )

                "getOutputDevice" -> result.success(currentOutputDevice())

                else -> result.notImplemented()
            }
        } catch (t: Throwable) {
            // A vendor audiofx quirk must not surface as a PlatformException.
            Log.w(TAG, "call ${call.method} failed", t)
            result.success(false)
        }
    }

    private inline fun withBundle(call: MethodCall, body: (Bundle) -> Unit): Boolean {
        val id = call.argument<Int>("sessionId") ?: return false
        val bundle = bundles[id] ?: return false
        return try {
            body(bundle)
            true
        } catch (t: Throwable) {
            Log.w(TAG, "effect write failed on session $id", t)
            false
        }
    }

    // ── session ids ──────────────────────────────────────────────────────────

    /**
     * A session id we own, handed to mpv via `audiotrack-session-id` so the
     * video path can use real hardware effects instead of the filter fallback.
     */
    private fun generateSessionId(): Int = try {
        audioManager.generateAudioSessionId()
    } catch (t: Throwable) {
        AudioManager.ERROR
    }

    /**
     * Builds (or reuses) the effect bundle for [sessionId] and reports what the
     * device actually supports. `sessionId == 0` is the global output mix:
     * deprecated and unreliable since Android 10, so it is honoured only when
     * Dart explicitly opts in as a last resort.
     */
    private fun attach(sessionId: Int, allowGlobalFallback: Boolean): Map<String, Any?> {
        if (sessionId == 0 && !allowGlobalFallback) {
            return mapOf("attached" to false, "reason" to "no_session")
        }
        bundles[sessionId]?.let { return it.capabilities(sessionId) }

        val bundle = Bundle(sessionId, ::emitVisualizerFrame)
        bundles[sessionId] = bundle
        val caps = bundle.capabilities(sessionId)

        // No equalizer at all means the bundle is dead weight — drop it now so
        // it cannot hold a vendor effect slot open.
        if (caps["equalizer"] != true &&
            caps["bassBoost"] != true &&
            caps["loudness"] != true
        ) {
            bundles.remove(sessionId)?.release()
            return mapOf(
                "attached" to false,
                "reason" to "unsupported_device",
                "sessionId" to sessionId,
            )
        }
        return caps
    }

    private fun release(sessionId: Int) {
        bundles.remove(sessionId)?.release()
    }

    private fun releaseAll() {
        bundles.values.forEach { it.release() }
        bundles.clear()
    }

    // ── visualizer plumbing ──────────────────────────────────────────────────

    private fun emitVisualizerFrame(frame: Map<String, Any?>) {
        val sink = visualizerSink ?: return
        main.post { sink.success(frame) }
    }

    // ── output device ────────────────────────────────────────────────────────

    /**
     * Coarse output route, used to pick the auto-switch profile in Dart.
     * Priority is bluetooth > usb > wired > speaker, since several of these can
     * be reported as connected at once.
     */
    private fun currentOutputDevice(): String {
        return try {
            val devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS)
            var best = "speaker"
            for (d in devices) {
                when (d.type) {
                    AudioDeviceInfo.TYPE_BLUETOOTH_A2DP,
                    AudioDeviceInfo.TYPE_BLUETOOTH_SCO,
                    -> best = "bluetooth"

                    AudioDeviceInfo.TYPE_USB_HEADSET,
                    AudioDeviceInfo.TYPE_USB_DEVICE,
                    AudioDeviceInfo.TYPE_USB_ACCESSORY,
                    -> if (best != "bluetooth") best = "usb"

                    AudioDeviceInfo.TYPE_WIRED_HEADSET,
                    AudioDeviceInfo.TYPE_WIRED_HEADPHONES,
                    -> if (best == "speaker") best = "wired"
                }
            }
            best
        } catch (t: Throwable) {
            "speaker"
        }
    }

    private fun registerDeviceCallback() {
        if (deviceCallback != null) return
        val cb = object : AudioDeviceCallback() {
            override fun onAudioDevicesAdded(added: Array<out AudioDeviceInfo>?) = push()
            override fun onAudioDevicesRemoved(removed: Array<out AudioDeviceInfo>?) = push()
            private fun push() {
                val route = currentOutputDevice()
                main.post { deviceSink?.success(route) }
            }
        }
        deviceCallback = cb
        try {
            audioManager.registerAudioDeviceCallback(cb, main)
        } catch (t: Throwable) {
            deviceCallback = null
        }
    }

    private fun unregisterDeviceCallback() {
        deviceCallback?.let {
            try {
                audioManager.unregisterAudioDeviceCallback(it)
            } catch (_: Throwable) {
            }
        }
        deviceCallback = null
    }

    // ── per-session effect bundle ────────────────────────────────────────────

    /**
     * Owns every AudioEffect for one session id. Each effect is constructed in
     * its own try/catch: on MIUI / Samsung / Realme a system equalizer can hold
     * an exclusive lock and only SOME of these come up.
     */
    private class Bundle(
        private val sessionId: Int,
        private val onFrame: (Map<String, Any?>) -> Unit,
    ) {
        val equalizer: Equalizer? = build { Equalizer(0, sessionId) }
        val bassBoost: BassBoost? = build { BassBoost(0, sessionId) }
        val virtualizer: Virtualizer? = build { Virtualizer(0, sessionId) }
        val reverb: PresetReverb? = build { PresetReverb(0, sessionId) }
        val loudness: LoudnessEnhancer? = build { LoudnessEnhancer(sessionId) }

        private var visualizer: Visualizer? = null
        private var lastEmit = 0L

        /** Master switch — individual effects only go live while this is true. */
        private var masterOn = false

        private fun <T> build(factory: () -> T): T? = try {
            factory()
        } catch (t: Throwable) {
            Log.w(TAG, "effect unavailable: ${t.message}")
            null
        }

        fun capabilities(sessionId: Int): Map<String, Any?> {
            val eq = equalizer
            val bands = try {
                eq?.numberOfBands?.toInt() ?: 0
            } catch (t: Throwable) {
                0
            }
            val range = try {
                eq?.bandLevelRange
            } catch (t: Throwable) {
                null
            }

            val freqs = ArrayList<Int>(bands)
            for (b in 0 until bands) {
                freqs.add(
                    try {
                        eq!!.getCenterFreq(b.toShort())
                    } catch (t: Throwable) {
                        0
                    }
                )
            }

            val presets = ArrayList<String>()
            try {
                for (p in 0 until (eq?.numberOfPresets?.toInt() ?: 0)) {
                    presets.add(eq!!.getPresetName(p.toShort()))
                }
            } catch (_: Throwable) {
            }

            return mapOf(
                "attached" to true,
                "sessionId" to sessionId,
                "isGlobalSession" to (sessionId == 0),
                "equalizer" to (eq != null && bands > 0),
                "numberOfBands" to bands,
                // millibel; -1500..1500 on most devices
                "minLevelMb" to (range?.getOrNull(0)?.toInt() ?: -1500),
                "maxLevelMb" to (range?.getOrNull(1)?.toInt() ?: 1500),
                "centerFreqsMilliHz" to freqs,
                "devicePresets" to presets,
                "bassBoost" to (bassBoost != null),
                "virtualizer" to (virtualizer != null),
                "reverb" to (reverb != null),
                "loudness" to (loudness != null),
            )
        }

        fun setEnabled(on: Boolean) {
            masterOn = on
            equalizer?.runCatchingFx { enabled = on }
            bassBoost?.runCatchingFx { enabled = on }
            virtualizer?.runCatchingFx { enabled = on }
            reverb?.runCatchingFx { enabled = on }
            loudness?.runCatchingFx { enabled = on }
        }

        fun setBandLevel(band: Int, levelMb: Int) {
            equalizer?.runCatchingFx {
                if (masterOn && !enabled) enabled = true
                setBandLevel(band.toShort(), levelMb.toShort())
            }
        }

        fun setBandLevels(levelsMb: List<Int>) {
            equalizer?.runCatchingFx {
                if (masterOn && !enabled) enabled = true
                val n = min(levelsMb.size, numberOfBands.toInt())
                for (b in 0 until n) setBandLevel(b.toShort(), levelsMb[b].toShort())
            }
        }

        fun setBassBoost(strength: Int) {
            bassBoost?.runCatchingFx {
                enabled = masterOn && strength > 0
                if (strengthSupported) setStrength(strength.coerceIn(0, 1000).toShort())
            }
        }

        fun setVirtualizer(strength: Int) {
            virtualizer?.runCatchingFx {
                enabled = masterOn && strength > 0
                if (strengthSupported) setStrength(strength.coerceIn(0, 1000).toShort())
            }
        }

        fun setReverb(preset: Int) {
            reverb?.runCatchingFx {
                enabled = masterOn && preset > 0
                this.preset = preset.coerceIn(0, 6).toShort()
            }
        }

        fun setLoudness(gainMb: Int) {
            loudness?.runCatchingFx {
                setTargetGain(gainMb.coerceIn(0, 2000))
                enabled = masterOn && gainMb > 0
            }
        }

        /**
         * Visualizer needs RECORD_AUDIO — Dart calls this only once the user has
         * turned the spectrum or Auto-EQ on and granted the permission.
         */
        fun setVisualizerEnabled(on: Boolean) {
            if (!on) {
                visualizer?.let { v ->
                    try {
                        v.enabled = false
                    } catch (_: Throwable) {
                    }
                    try {
                        v.release()
                    } catch (_: Throwable) {
                    }
                }
                visualizer = null
                return
            }
            if (visualizer != null) return

            val v = try {
                Visualizer(sessionId)
            } catch (t: Throwable) {
                Log.w(TAG, "visualizer unavailable", t)
                return
            }
            visualizer = v
            try {
                val sizes = Visualizer.getCaptureSizeRange()
                v.captureSize = 1024.coerceIn(sizes[0], sizes[1])
                v.scalingMode = Visualizer.SCALING_MODE_NORMALIZED
                v.setDataCaptureListener(
                    object : Visualizer.OnDataCaptureListener {
                        override fun onWaveFormDataCapture(
                            vis: Visualizer?,
                            wave: ByteArray?,
                            rate: Int,
                        ) = Unit

                        override fun onFftDataCapture(
                            vis: Visualizer?,
                            fft: ByteArray?,
                            rate: Int,
                        ) {
                            if (fft == null) return
                            val now = System.currentTimeMillis()
                            if (now - lastEmit < EMIT_INTERVAL_MS) return
                            lastEmit = now
                            val sr = try {
                                vis?.samplingRate ?: 44100000
                            } catch (t: Throwable) {
                                44100000
                            }
                            onFrame(analyse(fft, sr))
                        }
                    },
                    Visualizer.getMaxCaptureRate() / 2,
                    false, // waveform not needed
                    true,  // fft
                )
                v.enabled = true
            } catch (t: Throwable) {
                Log.w(TAG, "visualizer setup failed", t)
                try {
                    v.release()
                } catch (_: Throwable) {
                }
                visualizer = null
            }
        }

        /**
         * Turns one FFT capture into (a) 32 log-spaced bars for the painter and
         * (b) six perceptual band energies the Dart classifier reasons about.
         * [samplingRateMilliHz] is what Visualizer reports — milli-Hz, not Hz.
         */
        private fun analyse(fft: ByteArray, samplingRateMilliHz: Int): Map<String, Any?> {
            val binCount = fft.size / 2
            if (binCount < 2) {
                return mapOf(
                    "bars" to DoubleArray(BAR_COUNT).toList(),
                    "bands" to DoubleArray(BAND_EDGES.size - 1).toList(),
                    "rms" to 0.0,
                )
            }

            val nyquist = (samplingRateMilliHz / 1000.0) / 2.0
            val hzPerBin = nyquist / binCount

            val mags = DoubleArray(binCount)
            var peak = 1e-6
            var energy = 0.0
            for (i in 1 until binCount) {
                val re = fft[2 * i].toInt().toDouble()
                val im = fft[2 * i + 1].toInt().toDouble()
                val m = hypot(re, im)
                mags[i] = m
                energy += m * m
                if (m > peak) peak = m
            }

            // Bars on a log frequency axis: linear bins crowd everything above
            // 5 kHz into the right half and leave the bass end looking dead.
            val bars = DoubleArray(BAR_COUNT)
            val minHz = 30.0
            val maxHz = min(16000.0, nyquist)
            for (b in 0 until BAR_COUNT) {
                val lo = minHz * (maxHz / minHz).pow(b.toDouble() / BAR_COUNT)
                val hi = minHz * (maxHz / minHz).pow((b + 1.0) / BAR_COUNT)
                bars[b] = normalise(bandPeak(mags, hzPerBin, lo, hi), peak)
            }

            val bands = DoubleArray(BAND_EDGES.size - 1)
            var bandSum = 0.0
            for (i in bands.indices) {
                val v = bandAvg(mags, hzPerBin, BAND_EDGES[i], BAND_EDGES[i + 1])
                bands[i] = v
                bandSum += v
            }
            // Share-of-total, so the classifier compares SHAPE, not loudness.
            if (bandSum > 0) for (i in bands.indices) bands[i] = bands[i] / bandSum

            return mapOf(
                "bars" to bars.toList(),
                "bands" to bands.toList(),
                "rms" to normalise(sqrt(energy / binCount), peak),
            )
        }

        private fun bandPeak(
            mags: DoubleArray,
            hzPerBin: Double,
            lo: Double,
            hi: Double,
        ): Double {
            var v = 0.0
            var i = max(1, (lo / hzPerBin).toInt())
            val end = min(mags.size - 1, (hi / hzPerBin).toInt())
            while (i <= end) {
                if (mags[i] > v) v = mags[i]
                i++
            }
            return v
        }

        private fun bandAvg(
            mags: DoubleArray,
            hzPerBin: Double,
            lo: Double,
            hi: Double,
        ): Double {
            var sum = 0.0
            var n = 0
            var i = max(1, (lo / hzPerBin).toInt())
            val end = min(mags.size - 1, (hi / hzPerBin).toInt())
            while (i <= end) {
                sum += mags[i]
                n++
                i++
            }
            return if (n == 0) 0.0 else sum / n
        }

        /** Log compression — raw magnitudes render as a flat line otherwise. */
        private fun normalise(value: Double, peak: Double): Double {
            if (value <= 0) return 0.0
            val r = (value / peak).coerceIn(1e-4, 1.0)
            return (1.0 - ln(r) / ln(1e-4)).coerceIn(0.0, 1.0)
        }

        fun release() {
            setVisualizerEnabled(false)
            listOfNotNull(equalizer, bassBoost, virtualizer, reverb, loudness).forEach {
                try {
                    it.enabled = false
                } catch (_: Throwable) {
                }
                try {
                    it.release()
                } catch (_: Throwable) {
                }
            }
        }

        /** audiofx setters throw on vendor firmware far more than the docs admit. */
        private inline fun <T : AudioEffect> T.runCatchingFx(body: T.() -> Unit) {
            try {
                body()
            } catch (t: Throwable) {
                Log.w(TAG, "fx write failed", t)
            }
        }
    }
}
