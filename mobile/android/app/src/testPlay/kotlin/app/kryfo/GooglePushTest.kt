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

    @org.junit.After
    fun tearDown() {
        // the real ones back, for whatever runs next
        GooglePush.deleter = GooglePush.firebaseDeleter
        GooglePush.present = { GooglePush.available(it) }
        GooglePush.fetch = { c, done -> GooglePush.token(c, done) }
    }

    @Test
    fun aFailedDeleteIsOwedAndTriedAgain() {
        GooglePush.present = { true }
        on(true)
        val tries = mutableListOf<Boolean>()
        var answer = false
        GooglePush.deleter = { _, done -> tries.add(answer); done(answer) }
        try {
            GooglePush.stop(app) {}
            assertFalse(GooglePush.isOn(app))
            assertTrue(GooglePush.deleteOwed(app))
            // the next start or return to the app tries again, and again
            GooglePush.settle(app)
            assertTrue(GooglePush.deleteOwed(app))
            answer = true
            GooglePush.settle(app)
            assertFalse(GooglePush.deleteOwed(app))
            assertEquals(3, tries.size)
            // nothing owed: nothing tried
            GooglePush.settle(app)
            assertEquals(3, tries.size)
        } finally {
            GooglePush.deleter = GooglePush.firebaseDeleter
        }
    }

    @Test
    fun pickedAgainMeanwhileNothingIsDeleted() {
        on(true)
        GooglePush.deleter = { _, done -> done(false) }
        GooglePush.stop(app) {}
        on(true)
        var tried = false
        GooglePush.deleter = { _, done -> tried = true; done(true) }
        GooglePush.settle(app)
        assertFalse(tried)
    }

    @Test
    fun pickedAgainWhileADeleteRunsWaitsForIt() {
        on(true)
        var finish: ((Boolean) -> Unit)? = null
        GooglePush.deleter = { _, done -> finish = done }
        GooglePush.stop(app) {}
        GooglePush.fetch = { _, done -> done("fresh") }
        var asked = 0
        GooglePush.start(app) { asked++ }
        // no token is asked for while the delete could still kill it
        assertEquals(0, asked)
        finish!!(true)
        assertEquals(1, asked)
        assertTrue(GooglePush.isOn(app))
        assertFalse(GooglePush.deleteOwed(app))
    }

    @Test
    fun anOwedDeleteIsGivenUpAfterAMonth() {
        GooglePush.present = { true }
        on(true)
        GooglePush.deleter = { _, done -> done(false) }
        GooglePush.stop(app) {}
        assertTrue(GooglePush.deleteOwed(app))
        var tried = 0
        GooglePush.deleter = { _, done -> tried++; done(false) }
        GooglePush.settle(app, System.currentTimeMillis() + GooglePush.OWED_FOR_MS + 1000)
        assertEquals(0, tried)
        assertFalse(GooglePush.deleteOwed(app))
    }

    @Test
    fun anOwedDeleteWaitsForPlayServices() {
        GooglePush.present = { false }
        on(true)
        GooglePush.deleter = { _, done -> done(false) }
        GooglePush.stop(app) {}
        var tried = 0
        GooglePush.deleter = { _, done -> tried++; done(true) }
        GooglePush.settle(app)
        assertEquals(0, tried)
        assertTrue(GooglePush.deleteOwed(app))
    }

    @Test
    fun offeredOnlyWhenPlayServicesWorkNow() {
        val r = com.google.android.gms.common.ConnectionResult::class.java
        fun code(name: String) = r.getField(name).getInt(null)
        assertTrue(GooglePush.offerableFrom(code("SUCCESS")))
        assertFalse(GooglePush.offerableFrom(code("SERVICE_VERSION_UPDATE_REQUIRED")))
        assertFalse(GooglePush.offerableFrom(code("SERVICE_UPDATING")))
    }

    @Test
    fun playServicesUpdatingIsStillThere() {
        val r = com.google.android.gms.common.ConnectionResult::class.java
        fun code(name: String) = r.getField(name).getInt(null)
        assertTrue(GooglePush.availableFrom(code("SUCCESS")))
        assertTrue(GooglePush.availableFrom(code("SERVICE_UPDATING")))
        assertTrue(GooglePush.availableFrom(code("SERVICE_VERSION_UPDATE_REQUIRED")))
        assertFalse(GooglePush.availableFrom(code("SERVICE_MISSING")))
        assertFalse(GooglePush.availableFrom(code("SERVICE_DISABLED")))
        assertFalse(GooglePush.availableFrom(code("SERVICE_INVALID")))
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
