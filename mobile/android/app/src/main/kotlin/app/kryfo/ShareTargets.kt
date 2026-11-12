// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.content.Context
import android.content.Intent
import android.content.pm.ShortcutInfo
import android.content.pm.ShortcutManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.drawable.Icon
import android.os.Build
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

// chats in the share menu (lib/share_targets.dart decides which, and when
// there are none). a name and a drawn initial each, never a photo, kept off
// the launcher's long press, and not long lived: the system keeps no copy
// once they are removed. android 13 and later only, the first that can keep
// them off the launcher
object ShareTargets {
    const val CHANNEL = "kryfo/share_targets"

    // the share-target in res/xml/share_targets.xml names it
    const val CATEGORY = "app.kryfo.category.SHARE_CHAT"

    private const val MOST = 4

    // the icon's side; the middle two thirds show in the round mask
    private const val SIDE = 216

    fun supported(): Boolean = Build.VERSION.SDK_INT >= 33

    fun handle(context: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "supported" -> result.success(supported())
            "publish" -> {
                val list = call.argument<List<Map<String, Any?>>>("targets") ?: emptyList()
                val bg = call.argument<Number>("bg")?.toInt() ?: 0xFF000000.toInt()
                val fg = call.argument<Number>("fg")?.toInt() ?: 0xFFFFFFFF.toInt()
                result.success(publish(context, list, bg, fg))
            }
            "clear" -> result.success(clear(context))
            else -> result.notImplemented()
        }
    }

    // shortcuts came with android 7.1: on 7.0 the class is not there
    private fun manager(context: Context): ShortcutManager? =
        if (Build.VERSION.SDK_INT < 25) null
        else context.getSystemService(ShortcutManager::class.java)

    // every one there was is replaced by these
    private fun publish(context: Context, list: List<Map<String, Any?>>, bg: Int, fg: Int): Boolean {
        if (Build.VERSION.SDK_INT < 33) return clear(context)
        val sm = manager(context) ?: return false
        return try {
            val infos = list.take(MOST).mapIndexedNotNull { i, t ->
                val id = t["id"] as? String ?: return@mapIndexedNotNull null
                val name = (t["name"] as? String)?.takeIf { it.isNotBlank() }
                    ?: return@mapIndexedNotNull null
                val initial = t["initial"] as? String ?: "?"
                ShortcutInfo.Builder(context, id)
                    .setShortLabel(name)
                    .setLongLabel(name)
                    .setIcon(Icon.createWithAdaptiveBitmap(initialIcon(initial, bg, fg)))
                    .setIntent(
                        Intent(Intent.ACTION_MAIN).setComponent(AppIcon.entry(context))
                    )
                    .setCategories(setOf(CATEGORY))
                    .setLongLived(false)
                    .setRank(i)
                    .setExcludedFromSurfaces(ShortcutInfo.SURFACE_LAUNCHER)
                    .build()
            }
            if (infos.isEmpty()) return clear(context)
            // false: the system's rate limit took none
            sm.setDynamicShortcuts(infos)
        } catch (e: Exception) {
            DebugLog.i("share", "targets not published (${e.javaClass.simpleName})")
            clear(context)
            false
        }
    }

    // true when none are left, also on an android without any
    fun clear(context: Context): Boolean {
        if (Build.VERSION.SDK_INT < 25) return true
        val sm = manager(context) ?: return false
        return try {
            val ids = sm.dynamicShortcuts.map { it.id }
            sm.removeAllDynamicShortcuts()
            // a cached copy, should the system have made one, goes too
            if (ids.isNotEmpty() && Build.VERSION.SDK_INT >= 30) sm.removeLongLivedShortcuts(ids)
            true
        } catch (e: Throwable) {
            false
        }
    }

    private fun initialIcon(initial: String, bg: Int, fg: Int): Bitmap {
        val b = Bitmap.createBitmap(SIDE, SIDE, Bitmap.Config.ARGB_8888)
        val c = Canvas(b)
        c.drawColor(bg)
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = fg
            textAlign = Paint.Align.CENTER
            textSize = SIDE * 0.36f
            typeface = Typeface.create(Typeface.SERIF, Typeface.NORMAL)
        }
        val y = SIDE / 2f - (p.descent() + p.ascent()) / 2f
        c.drawText(initial, SIDE / 2f, y, p)
        return b
    }
}
