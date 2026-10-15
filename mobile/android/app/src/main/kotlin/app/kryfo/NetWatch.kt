package app.kryfo

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

// which network is the default one, from the callbacks in the order android
// sends them. a new default arrives with onAvailable. android 7 sends no
// capabilities after it, so there they are asked for; later androids send
// them, and a read of our own could race them with an older answer. the
// old default's onLost can come after the new one is up, and then it
// changes nothing. the network there at the start and the same word again
// are not news: only a word that differs from the last is reported.
class NetTracker<N>(
    private val describe: (N?) -> String,
    private val report: (String) -> Unit,
    private val capsFollow: Boolean,
    private var said: String,
) {
    private var current: N? = null

    fun available(n: N) {
        current = n
        if (!capsFollow) say(describe(n))
    }

    fun changed(n: N, state: String) {
        current = n
        say(state)
    }

    fun lost(n: N) {
        if (n != current) return
        current = null
        say(describe(null))
    }

    private fun say(state: String) {
        if (state == said) return
        said = state
        report(state)
    }
}

// the default network as android sees it: whether there is one, its type,
// whether android validated it, whether a captive portal sits in front and
// whether a vpn carries it, and android's handle for it, so a new network
// of the same type is told from the one before. dart hands each change to
// the engine, where automatic bridges read it. android validates against a
// google host that some networks block, so this is a hint, never proof.
object NetWatch {
    const val CHANNEL = "kryfo/net"

    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    @Volatile private var last = describe(null, null)

    fun start(context: Context, engine: FlutterEngine) {
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            if (call.method == "state") result.success(last) else result.notImplemented()
        }
        channel = ch
        val cm = context.getSystemService(ConnectivityManager::class.java) ?: return
        try {
            val active = cm.activeNetwork
            last = describe(active, active?.let { cm.getNetworkCapabilities(it) })
            val tracker = NetTracker<Network>(
                describe = { n -> describe(n, n?.let { cm.getNetworkCapabilities(it) }) },
                report = { report(it) },
                capsFollow = Build.VERSION.SDK_INT >= Build.VERSION_CODES.O,
                said = last,
            )
            cm.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
                override fun onAvailable(network: Network) {
                    tracker.available(network)
                }

                override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                    tracker.changed(network, describe(network, caps))
                }

                override fun onLost(network: Network) {
                    tracker.lost(network)
                }
            })
        } catch (e: Exception) {
            // a phone that refuses the callback keeps the old signal only
            Log.i("halo-engine", "net watch: ${e.javaClass.simpleName}")
        }
    }

    @Synchronized
    private fun report(state: String) {
        last = state
        main.post {
            try {
                channel?.invokeMethod("net", state)
            } catch (e: Exception) {
                Log.i("halo-engine", "net watch: ${e.javaClass.simpleName}")
            }
        }
    }

    private fun describe(network: Network?, caps: NetworkCapabilities?): String {
        val o = JSONObject()
        if (network == null || caps == null || !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
            o.put("on", false)
            o.put("kind", "other")
            return o.toString()
        }
        o.put("on", true)
        o.put("validated", caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_VALIDATED))
        o.put("limited", caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_CAPTIVE_PORTAL))
        o.put("vpn", caps.hasTransport(NetworkCapabilities.TRANSPORT_VPN))
        o.put(
            "kind",
            when {
                caps.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
                caps.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
                else -> "other"
            }
        )
        o.put("net", network.networkHandle)
        return o.toString()
    }
}
