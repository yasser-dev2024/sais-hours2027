package com.abuammar.horseclub.mobile2026

import android.media.AudioAttributes
import android.media.MediaPlayer
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var alertPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "horse_club/audio",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "playAlert" -> {
                    try {
                        playAlert(call.argument<Boolean>("loop") ?: false)
                        result.success(true)
                    } catch (error: Exception) {
                        result.error("ALERT_SOUND_FAILED", error.message, null)
                    }
                }

                "stopAlert" -> {
                    stopAlert()
                    result.success(true)
                }

                else -> result.notImplemented()
            }
        }
    }

    private fun playAlert(loop: Boolean) {
        stopAlert()
        val descriptor = resources.openRawResourceFd(R.raw.jrs)
        val player = MediaPlayer()
        try {
            player.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            player.setDataSource(
                descriptor.fileDescriptor,
                descriptor.startOffset,
                descriptor.length,
            )
            player.isLooping = loop
            player.setVolume(1f, 1f)
            player.setOnCompletionListener { completed ->
                if (!completed.isLooping) {
                    completed.release()
                    if (alertPlayer === completed) alertPlayer = null
                }
            }
            player.prepare()
            alertPlayer = player
            player.start()
        } catch (error: Exception) {
            player.release()
            throw error
        } finally {
            descriptor.close()
        }
    }

    private fun stopAlert() {
        alertPlayer?.runCatching {
            if (isPlaying) stop()
            release()
        }
        alertPlayer = null
    }

    override fun onDestroy() {
        stopAlert()
        super.onDestroy()
    }
}
