// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Application
import android.content.ComponentName
import android.content.pm.PackageManager
import com.google.android.datatransport.Encoding
import com.google.android.datatransport.Event
import com.google.android.datatransport.cct.CCTDestination
import com.google.android.datatransport.runtime.TransportRuntime
import com.google.android.datatransport.runtime.backends.TransportBackendDiscovery
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

// play billing logs to google over datatransport (PLAY_BILLING_LIBRARY on
// cct), firebase can too. the play manifest leaves datatransport without a
// backend, so such an event is dropped on the phone
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class QuietTransportTest {
    private val app: Application = RuntimeEnvironment.getApplication()

    @Test
    fun theMergedManifestNamesNoBackend() {
        val info = app.packageManager.getServiceInfo(
            ComponentName(app, TransportBackendDiscovery::class.java),
            PackageManager.GET_META_DATA,
        )
        val keys = info.metaData?.keySet() ?: emptySet()
        assertTrue("$keys", keys.none { it.startsWith("backend:") })
    }

    @Test
    fun billingsOwnLoggingGoesNowhere() {
        TransportRuntime.initialize(app)
        val transport = TransportRuntime.getInstance()
            .newFactory(CCTDestination.LEGACY_INSTANCE)
            .getTransport("PLAY_BILLING_LIBRARY", ByteArray::class.java, Encoding.of("proto")) { it }
        val got = AtomicReference<Exception?>()
        val done = CountDownLatch(1)
        transport.schedule(Event.ofData(byteArrayOf(1, 2, 3))) { e ->
            got.set(e)
            done.countDown()
        }
        assertTrue(done.await(10, TimeUnit.SECONDS))
        val e = got.get()
        assertNotNull("the event was taken for sending", e)
        assertTrue("${e?.message}", e?.message?.contains("not registered") == true)
    }
}
