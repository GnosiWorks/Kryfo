// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Application
import android.app.job.JobScheduler
import android.content.Context
import android.os.Bundle
import com.google.firebase.messaging.RemoteMessage
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.Robolectric
import org.robolectric.RobolectricTestRunner
import org.robolectric.RuntimeEnvironment
import org.robolectric.annotation.Config

// a google push is a knock: the same gate and the same expedited check-in
// job as a helper app's, its body never read, and nothing while google
// push is off. the play manifest keeps firebase from starting on its own
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = Application::class)
class GooglePushTest {
    private val app: Application = RuntimeEnvironment.getApplication()

    @Before
    fun setUp() {
        // the app's database is there: knocks are for a set-up kryfo
        File(app.dataDir, "app_flutter").mkdirs()
        File(app.dataDir, "app_flutter/halo.db").writeText("")
        app.getSharedPreferences("helper_push", Context.MODE_PRIVATE).edit().clear().commit()
        app.getSharedPreferences("google_push", Context.MODE_PRIVATE).edit().clear().commit()
    }

    private fun on(v: Boolean) {
        app.getSharedPreferences("google_push", Context.MODE_PRIVATE).edit()
            .putBoolean("on", v).commit()
    }

    private fun knockJob() =
        app.getSystemService(JobScheduler::class.java).getPendingJob(JobSetup.KNOCK_JOB_ID)

    private fun service() =
        Robolectric.buildService(KryfoMessagingService::class.java).get()

    @Test
    fun aPushRunsTheKnockPath() {
        on(true)
        val s = service()
        // what the push carries is never read: a body changes nothing
        s.onMessageReceived(RemoteMessage(Bundle().apply { putString("anything", "ignored") }))
        val job = knockJob()
        assertNotNull(job)
        assertEquals("push", job!!.extras.getString("why"))
        assertEquals(1, GooglePush.stats(app)["got"])
        // the next one inside the floor waits for it, as a helper knock does
        s.onMessageReceived(RemoteMessage(Bundle()))
        assertNotNull(
            app.getSystemService(JobScheduler::class.java).getPendingJob(JobSetup.KNOCK_LATER_JOB_ID)
        )
    }

    @Test
    fun nothingWhileGooglePushIsOff() {
        on(false)
        service().onMessageReceived(RemoteMessage(Bundle()))
        assertNull(knockJob())
        assertEquals(0, GooglePush.stats(app)["got"])
    }

    @Test
    fun aPushToAWipedAppDoesNothing() {
        on(true)
        File(app.dataDir, "app_flutter/halo.db").delete()
        service().onMessageReceived(RemoteMessage(Bundle()))
        assertNull(knockJob())
    }

    @Test
    fun knocksTheFcmDroppedStillGetOneCheckIn() {
        on(true)
        service().onDeletedMessages()
        assertNotNull(knockJob())
    }

    @Test
    fun turningOffNeverStartsFirebaseThatNeverRan() {
        var done = false
        GooglePush.stop(app) { done = true }
        assertTrue(done)
        assertFalse(GooglePush.isOn(app))
        assertTrue(com.google.firebase.FirebaseApp.getApps(app).isEmpty())
    }

    @Test
    fun googlePushIsNotAlwaysOn() {
        app.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE).edit()
            .putString("flutter.delivery_mode", "google").commit()
        assertFalse(DeliveryPrefs.staysOn(app))
    }

    @Test
    fun thePlayManifestKeepsFirebaseQuiet() {
        val m = File("src/play/AndroidManifest.xml").readText()
        for (want in listOf(
            "\"firebase_messaging_auto_init_enabled\"\n            android:value=\"false\"",
            "\"firebase_analytics_collection_deactivated\"\n            android:value=\"true\"",
            "\"google_analytics_adid_collection_enabled\"\n            android:value=\"false\"",
            "\"delivery_metrics_exported_to_big_query_enabled\"\n            android:value=\"false\"",
        )) {
            assertTrue(want, m.contains(want))
        }
        assertTrue(m.contains("com.google.firebase.provider.FirebaseInitProvider"))
        assertTrue(m.contains("tools:node=\"remove\""))
    }

    @Test
    fun fossCarriesNoGoogleCode() {
        val main = File("src/main").walkTopDown().filter { it.isFile }.map { it.readText() }
        assertFalse(main.any { it.contains("com.google.firebase") || it.contains("com.google.android.gms.common") })
    }
}
