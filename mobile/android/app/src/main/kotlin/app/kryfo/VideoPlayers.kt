// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.media.AudioAttributes
import android.media.MediaMetadataRetriever
import android.media.MediaPlayer
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.view.TextureRegistry

// the in-app video player: android's own MediaPlayer drawing into a flutter
// texture, so no player library to vendor and trust. the file never leaves
// the app, where another app could keep a copy or index it.
class VideoPlayers(private val textures: TextureRegistry) {
    private class Player(val producer: TextureRegistry.SurfaceProducer, val mp: MediaPlayer) {
        var prepared = false
        var completed = false
        var answered = false
    }

    private val players = HashMap<Long, Player>()

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        val id = (call.argument<Number>("id"))?.toLong()
        val p = id?.let { players[it] }
        when (call.method) {
            "open" -> open(call.argument<String>("path"), result)
            "play" -> {
                if (p?.prepared == true) {
                    if (p.completed) p.mp.seekTo(0)
                    p.completed = false
                    p.mp.start()
                }
                result.success(null)
            }
            "pause" -> {
                if (p?.prepared == true && p.mp.isPlaying) p.mp.pause()
                result.success(null)
            }
            "seek" -> {
                val ms = call.argument<Number>("ms")?.toLong() ?: 0L
                if (p?.prepared == true) {
                    p.completed = false
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                        p.mp.seekTo(ms, MediaPlayer.SEEK_CLOSEST)
                    } else {
                        p.mp.seekTo(ms.toInt())
                    }
                }
                result.success(null)
            }
            "state" -> {
                if (p == null || !p.prepared) {
                    result.success(null)
                } else {
                    result.success(
                        mapOf(
                            "ms" to p.mp.currentPosition,
                            "playing" to p.mp.isPlaying,
                            "done" to p.completed,
                        )
                    )
                }
            }
            "close" -> {
                if (id != null) release(id)
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    private fun open(path: String?, result: MethodChannel.Result) {
        if (path == null) {
            result.success(null)
            return
        }
        val producer = textures.createSurfaceProducer()
        val mp = MediaPlayer()
        val p = Player(producer, mp)
        players[producer.id()] = p
        // the app goes to the background and the surface behind the texture
        // can be taken away; the player is told, and given the new one back
        producer.setCallback(object : TextureRegistry.SurfaceProducer.Callback {
            override fun onSurfaceAvailable() {
                try { mp.setSurface(producer.surface) } catch (_: Exception) {}
            }
            override fun onSurfaceCleanup() {
                try { mp.setSurface(null) } catch (_: Exception) {}
            }
        })
        try {
            mp.setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MOVIE)
                    .build()
            )
            mp.setDataSource(path)
            // a phone held upright records a wide picture and a turn in the
            // track header. the newer texture path draws frames as decoded,
            // unturned, so the turn and the decoded size go to dart
            val shape = shapeOf(path)
            val turns = if (producer.handlesCropAndRotation()) 0 else shape.turns
            mp.setOnPreparedListener {
                p.prepared = true
                var w = shape.w
                var h = shape.h
                if (w <= 0 || h <= 0) {
                    // the player gives the size as shown, already turned
                    w = if (shape.turns % 2 == 1) it.videoHeight else it.videoWidth
                    h = if (shape.turns % 2 == 1) it.videoWidth else it.videoHeight
                }
                if (w > 0 && h > 0) producer.setSize(w, h)
                mp.setSurface(producer.surface)
                if (!p.answered) {
                    p.answered = true
                    // w and h as shown on screen
                    val odd = shape.turns % 2 == 1
                    result.success(
                        mapOf(
                            "id" to producer.id(),
                            "w" to if (odd) h else w,
                            "h" to if (odd) w else h,
                            "turns" to turns,
                            "ms" to it.duration,
                        )
                    )
                }
            }
            mp.setOnVideoSizeChangedListener { _, w, h ->
                // given as shown; the texture takes the decoded size
                val odd = shape.turns % 2 == 1
                if (w > 0 && h > 0) producer.setSize(if (odd) h else w, if (odd) w else h)
            }
            mp.setOnCompletionListener { p.completed = true }
            mp.setOnErrorListener { _, _, _ ->
                // a codec the phone does not have: the screen offers another
                // app instead
                if (!p.answered) {
                    p.answered = true
                    release(producer.id())
                    result.success(null)
                }
                true
            }
            mp.prepareAsync()
        } catch (e: Exception) {
            release(producer.id())
            if (!p.answered) {
                p.answered = true
                result.success(null)
            }
        }
    }

    private class Shape(val w: Int, val h: Int, val turns: Int)

    // the decoded size and the quarter turns the track header asks for
    private fun shapeOf(path: String): Shape {
        val r = MediaMetadataRetriever()
        return try {
            r.setDataSource(path)
            val w = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_WIDTH)
                ?.toIntOrNull() ?: 0
            val h = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_HEIGHT)
                ?.toIntOrNull() ?: 0
            val deg = r.extractMetadata(MediaMetadataRetriever.METADATA_KEY_VIDEO_ROTATION)
                ?.toIntOrNull() ?: 0
            Shape(w, h, Math.floorMod(deg / 90, 4))
        } catch (_: Exception) {
            Shape(0, 0, 0)
        } finally {
            try { r.release() } catch (_: Exception) {}
        }
    }

    private fun release(id: Long) {
        val p = players.remove(id) ?: return
        try { p.mp.reset() } catch (_: Exception) {}
        try { p.mp.release() } catch (_: Exception) {}
        try { p.producer.release() } catch (_: Exception) {}
    }

    fun releaseAll() {
        for (id in players.keys.toList()) release(id)
    }
}
