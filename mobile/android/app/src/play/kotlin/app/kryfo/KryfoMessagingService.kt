// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

// a google push is a knock and nothing more: the gateway sends it empty,
// and what it carries is never read. a high-priority one puts kryfo on
// android's short allowlist, so the expedited job of the knock starts at
// once, doze or not, and tor gets its time to fetch
class KryfoMessagingService : FirebaseMessagingService() {
    override fun onCreate() {
        // a process this push started has firebase up already when google
        // push is on (PlayApplication); a stray one finds it up too
        GooglePush.app(this)
        super.onCreate()
    }

    override fun onMessageReceived(message: RemoteMessage) {
        if (!GooglePush.isOn(this)) return
        GooglePush.received(this, message.priority != message.originalPriority)
        Knock.arrived(this, "google")
    }

    // fcm dropped knocks it held for too long: one check-in fetches all
    override fun onDeletedMessages() {
        if (GooglePush.isOn(this)) Knock.arrived(this, "google")
    }

    override fun onNewToken(token: String) {
        if (GooglePush.isOn(this)) GooglePush.tell("token")
    }
}
