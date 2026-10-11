package app.kryfo

import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

// the default network as android sees it: whether there is one, its type,
// whether android validated it, whether a captive portal sits in front and
// whether a vpn carries it. dart hands each change to the engine, where
// automatic bridges read it. android validates against a google host that
// some networks block, so this is a hint, never proof.
object NetWatch {
    const val CHANNEL = "kryfo/net"

    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    @Volatile private var last = describe(null)

    fun start(context: Context, engine: FlutterEngine) {
        val ch = MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL)
        ch.setMethodCallHandler { call, result ->
            if (call.method == "state") result.success(last) else result.notImplemented()
        }
        channel = ch
        val cm = context.getSystemService(ConnectivityManager::class.java) ?: return
        try {
            last = describe(cm.getNetworkCapabilities(cm.activeNetwork))
            cm.registerDefaultNetworkCallback(object : ConnectivityManager.NetworkCallback() {
                override fun onCapabilitiesChanged(network: Network, caps: NetworkCapabilities) {
                    report(describe(caps))
                }

                override fun onLost(network: Network) {
                    report(describe(null))
                }
            })
        } catch (e: Exception) {
            // a phone that refuses the callback keeps the old signal only
            Log.i("halo-engine", "net watch: ${e.javaClass.simpleName}")
        }
    }

    private fun report(state: String) {
        if (state == last) return
        last = state
        main.post {
            try {
                channel?.invokeMethod("net", state)
            } catch (e: Exception) {
                Log.i("halo-engine", "net watch: ${e.javaClass.simpleName}")
            }
        }
    }

    private fun describe(caps: NetworkCapabilities?): String {
        val o = JSONObject()
        if (caps == null || !caps.hasCapability(NetworkCapabilities.NET_CAPABILITY_INTERNET)) {
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
        return o.toString()
    }
}
