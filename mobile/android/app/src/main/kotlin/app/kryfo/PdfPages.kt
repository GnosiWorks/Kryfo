// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.nio.ByteBuffer
import java.util.concurrent.Executors

// pdf pages drawn by the phone's own renderer, so no pdf library to vendor
// and trust. dart hands over the file's plaintext as memory (an anonymous
// file it zeroes after), and pages come back as pixels, never as files.
// one thread: the renderer opens one page at a time
class PdfPages {
    private class Doc(val fd: ParcelFileDescriptor, val r: PdfRenderer)

    private val docs = HashMap<Int, Doc>()
    private var next = 1
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    // the most pixels one page may take: a huge page is drawn smaller
    private val mostPixels = 4_200_000

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        if (worker.isShutdown) {
            result.success(null)
            return
        }
        worker.execute {
            val answer: Any? = try {
                when (call.method) {
                    "open" -> open(call.argument<String>("path"))
                    "render" -> render(
                        call.argument<Number>("id")?.toInt(),
                        call.argument<Number>("page")?.toInt() ?: 0,
                        call.argument<Number>("width")?.toInt() ?: 0,
                    )
                    "find" -> find(
                        call.argument<Number>("id")?.toInt(),
                        call.argument<String>("words") ?: "",
                    )
                    "close" -> {
                        close(call.argument<Number>("id")?.toInt())
                        null
                    }
                    else -> NotImplemented
                }
            } catch (e: SecurityException) {
                // a pdf with a password: the renderer does not open those
                mapOf("error" to "locked")
            } catch (e: Exception) {
                mapOf("error" to "unreadable")
            }
            main.post {
                if (answer === NotImplemented) result.notImplemented() else result.success(answer)
            }
        }
    }

    private object NotImplemented

    private fun open(path: String?): Any? {
        if (path == null) return null
        val fd = ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY)
        val r = try {
            PdfRenderer(fd)
        } catch (e: Exception) {
            fd.close()
            throw e
        }
        val id = next++
        docs[id] = Doc(fd, r)
        val sizes = ArrayList<Int>(r.pageCount * 2)
        for (i in 0 until r.pageCount) {
            r.openPage(i).use {
                sizes.add(it.width)
                sizes.add(it.height)
            }
        }
        return mapOf(
            "id" to id,
            "pages" to r.pageCount,
            "sizes" to sizes,
            "find" to (Build.VERSION.SDK_INT >= 35),
        )
    }

    private fun render(id: Int?, page: Int, width: Int): Any? {
        val d = id?.let { docs[it] } ?: return null
        if (page < 0 || page >= d.r.pageCount || width <= 0) return null
        d.r.openPage(page).use { p ->
            var w = width
            var h = (width.toLong() * p.height / p.width.coerceAtLeast(1)).toInt().coerceAtLeast(1)
            if (w.toLong() * h > mostPixels) {
                val k = Math.sqrt(mostPixels.toDouble() / (w.toLong() * h))
                w = (w * k).toInt().coerceAtLeast(1)
                h = (h * k).toInt().coerceAtLeast(1)
            }
            val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            try {
                // a page without a ground of its own is paper white
                bmp.eraseColor(Color.WHITE)
                p.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                val buf = ByteBuffer.allocate(bmp.byteCount)
                bmp.copyPixelsToBuffer(buf)
                return mapOf("w" to w, "h" to h, "rgba" to buf.array())
            } finally {
                bmp.recycle()
            }
        }
    }

    // the pages the words are on, in order. only where the renderer reads
    // a page's text (android 15 and later)
    private fun find(id: Int?, words: String): Any? {
        val d = id?.let { docs[it] } ?: return null
        if (Build.VERSION.SDK_INT < 35 || words.isBlank()) return emptyList<Int>()
        val out = ArrayList<Int>()
        for (i in 0 until d.r.pageCount) {
            d.r.openPage(i).use { p ->
                if (p.searchText(words).isNotEmpty()) out.add(i)
            }
        }
        return out
    }

    private fun close(id: Int?) {
        val d = id?.let { docs.remove(it) } ?: return
        try { d.r.close() } catch (_: Exception) {}
        try { d.fd.close() } catch (_: Exception) {}
    }

    fun releaseAll() {
        worker.execute { for (id in docs.keys.toList()) close(id) }
        worker.shutdown()
    }
}
