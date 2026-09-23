package com.start.notes

import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.media.MediaPlayer
import android.media.ToneGenerator
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.view.WindowManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.text.BreakIterator
import java.util.Locale

/**
 * 原生通道层：偏好读写 / 中文分词 / 音效震动 / 系统信息。
 * prefs 直接走同名 SharedPreferences，保证与老 Java 版数据完全兼容。
 */
class MainActivity : FlutterActivity() {

    private var chime: MediaPlayer? = null

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        val m = engine.dartExecutor.binaryMessenger

        MethodChannel(m, "start/prefs").setMethodCallHandler { call, result ->
            val sp = getSharedPreferences(call.argument<String>("name") ?: "start_prefs", MODE_PRIVATE)
            when (call.method) {
                "getAll" -> result.success(sp.all)
                "set" -> {
                    val key = call.argument<String>("key") ?: return@setMethodCallHandler result.error("args", "key required", null)
                    val value = call.argument<Any?>("value")
                    val e = sp.edit()
                    when (value) {
                        null -> e.remove(key)
                        is Boolean -> e.putBoolean(key, value)
                        is Int -> e.putInt(key, value)
                        is Long -> e.putLong(key, value)
                        is Double -> e.putFloat(key, value.toFloat())
                        is String -> e.putString(key, value)
                        else -> return@setMethodCallHandler result.error("type", "unsupported ${value?.javaClass}", null)
                    }
                    e.apply()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(m, "start/segment").setMethodCallHandler { call, result ->
            when (call.method) {
                "words" -> result.success(segmentWords(call.argument<String>("text") ?: ""))
                else -> result.notImplemented()
            }
        }

        MethodChannel(m, "start/sound").setMethodCallHandler { call, result ->
            when (call.method) {
                "tick" -> {
                    val vol = ((call.argument<Int>("volume") ?: 70).coerceIn(0, 100) * 8).coerceAtMost(100)
                    val tg = ToneGenerator(AudioManager.STREAM_SYSTEM, vol)
                    tg.startTone(ToneGenerator.TONE_PROP_BEEP, 60)
                    result.success(null)
                }
                "chime" -> {
                    stopChime()
                    chime = MediaPlayer.create(this, R.raw.finish_chime)?.apply {
                        setOnCompletionListener { it.release() }
                        start()
                    }
                    result.success(null)
                }
                "stopChime" -> { stopChime(); result.success(null) }
                else -> result.notImplemented()
            }
        }

        MethodChannel(m, "start/system").setMethodCallHandler { call, result ->
            when (call.method) {
                "filesDir" -> result.success(filesDir.absolutePath)
                "vibrate" -> {
                    vibrate((call.argument<Int>("ms") ?: 20).toLong())
                    result.success(null)
                }
                "keepScreenOn" -> {
                    if (call.argument<Boolean>("on") == true)
                        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    else
                        window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
                    result.success(null)
                }
                "initialShare" -> result.success(
                    intent?.takeIf { it.action == Intent.ACTION_SEND }?.getStringExtra(Intent.EXTRA_TEXT)
                )
                else -> result.notImplemented()
            }
        }
    }

    private fun stopChime() {
        chime?.let { if (it.isPlaying) it.stop(); it.release() }
        chime = null
    }

    private fun vibrate(ms: Long) {
        val v = getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        if (Build.VERSION.SDK_INT >= 26) {
            v.vibrate(VibrationEffect.createOneShot(ms, VibrationEffect.DEFAULT_AMPLITUDE))
        } else {
            @Suppress("DEPRECATION") v.vibrate(ms)
        }
    }

    /** 词级分词：BreakIterator ICU 词典，剥掉首尾标点，移植自老版 BigBangOverlay。 */
    private fun segmentWords(text: String): List<String> {
        val out = ArrayList<String>()
        val bi = BreakIterator.getWordInstance(Locale.CHINA)
        bi.setText(text)
        var start = bi.first()
        var end = bi.next()
        while (end != BreakIterator.DONE) {
            var w = text.substring(start, end).trim()
                .trim('，', '。', '、', '；', '：', '！', '？', ',', '.', '!', '?', ';', ':',
                    '"', '\'', '(', ')', '（', '）', '<', '>', '「', '」', '『', '』', '【', '】',
                    '[', ']', '…', '—', '·')
            if (w.isNotEmpty()) out.add(w)
            start = end
            end = bi.next()
        }
        return out
    }
}
