// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import android.app.Activity
import android.content.Context
import android.os.Handler
import android.os.Looper
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClient.BillingResponseCode
import com.android.billingclient.api.BillingClient.ProductType
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.PendingPurchasesParams
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.lang.ref.WeakReference

// the tip jar, the play build only: google play billing for a few one-time
// products that give a supporter badge. no account and no profile id is ever
// set on a purchase, so google holds nothing of ours to tie it to a person.
// dart gets each purchase's product, state and token, never its order id,
// and stores none of them (lib/tips/tip_jar.dart). the products are kept,
// never consumed: google play hands them back on a new install
object PlayTips : PurchasesUpdatedListener {
    const val CHANNEL = "kryfo/tips"

    private val main = Handler(Looper.getMainLooper())
    private var client: BillingClient? = null
    private var ready = false
    private val waiting = mutableListOf<(BillingClient?) -> Unit>()
    private val details = HashMap<String, ProductDetails>()

    // the screen in front, which the payment sheet opens over
    @Volatile
    var shown: WeakReference<Activity>? = null

    // what dart reads of a response
    fun codeName(code: Int): String = when (code) {
        BillingResponseCode.OK -> "ok"
        BillingResponseCode.USER_CANCELED -> "canceled"
        BillingResponseCode.ITEM_ALREADY_OWNED -> "owned"
        BillingResponseCode.BILLING_UNAVAILABLE,
        BillingResponseCode.FEATURE_NOT_SUPPORTED,
        BillingResponseCode.SERVICE_UNAVAILABLE -> "unavailable"
        BillingResponseCode.ITEM_UNAVAILABLE -> "missing"
        else -> "failed"
    }

    fun stateName(state: Int): String = when (state) {
        Purchase.PurchaseState.PURCHASED -> "purchased"
        Purchase.PurchaseState.PENDING -> "pending"
        else -> "other"
    }

    // the option the price and the payment sheet come from: the "buy" option
    // at its base price, never a discount offer play may list first
    const val BUY_OPTION = "buy"

    fun baseOffer(d: ProductDetails): ProductDetails.OneTimePurchaseOfferDetails? {
        val all = d.oneTimePurchaseOfferDetailsList ?: return null
        return all.firstOrNull { it.purchaseOptionId == BUY_OPTION && it.offerId.isNullOrEmpty() }
            ?: all.firstOrNull { it.offerId.isNullOrEmpty() }
            ?: all.firstOrNull()
    }

    // a purchase as dart sees it: the order id stays here
    fun purchaseMap(p: Purchase): Map<String, Any> = mapOf(
        "products" to p.products.toList(),
        "state" to stateName(p.purchaseState),
        "token" to p.purchaseToken,
        "acked" to p.isAcknowledged,
    )

    private fun build(c: Context): BillingClient = BillingClient.newBuilder(c.applicationContext)
        .setListener(this)
        .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
        .enableAutoServiceReconnection()
        .build()

    // the client once it is connected, or null when play billing is not there
    private fun connected(c: Context, then: (BillingClient?) -> Unit) {
        val have = client
        if (have != null && ready) return then(have)
        waiting.add(then)
        if (have != null) return
        val made = try {
            build(c)
        } catch (e: Exception) {
            DebugLog.i("halo-engine", "tips: no billing client: ${e.javaClass.simpleName}")
            null
        }
        if (made == null) return flush(null)
        client = made
        made.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(r: BillingResult) {
                main.post {
                    if (r.responseCode == BillingResponseCode.OK) {
                        ready = true
                        flush(made)
                    } else {
                        // asked again from the start next time
                        client = null
                        ready = false
                        made.endConnection()
                        flush(null)
                    }
                }
            }

            // auto reconnection takes the next call through
            override fun onBillingServiceDisconnected() {}
        })
    }

    private fun flush(c: BillingClient?) {
        val all = waiting.toList()
        waiting.clear()
        all.forEach { it(c) }
    }

    fun handle(c: Context, call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "products" -> products(c, call.argument<List<String>>("ids") ?: emptyList(), result)
            "buy" -> buy(c, call.argument<String>("id") ?: "", result)
            "owned" -> owned(c, result)
            "ack" -> ack(c, call.argument<String>("token") ?: "", result)
            else -> result.notImplemented()
        }
    }

    private fun answer(result: MethodChannel.Result, v: Any?) {
        main.post { result.success(v) }
    }

    private fun products(c: Context, ids: List<String>, result: MethodChannel.Result) {
        if (ids.isEmpty()) return answer(result, mapOf("code" to "ok", "items" to emptyList<Any>()))
        connected(c) { bc ->
            if (bc == null) return@connected answer(result, mapOf("code" to "unavailable"))
            val params = QueryProductDetailsParams.newBuilder().setProductList(
                ids.map {
                    QueryProductDetailsParams.Product.newBuilder()
                        .setProductId(it)
                        .setProductType(ProductType.INAPP)
                        .build()
                }
            ).build()
            bc.queryProductDetailsAsync(params) { r, got ->
                if (r.responseCode != BillingResponseCode.OK) {
                    return@queryProductDetailsAsync answer(result, mapOf("code" to codeName(r.responseCode)))
                }
                val items = mutableListOf<Map<String, String>>()
                for (d in got.productDetailsList) {
                    val offer = baseOffer(d) ?: continue
                    main.post { details[d.productId] = d }
                    items.add(mapOf("id" to d.productId, "price" to offer.formattedPrice))
                }
                answer(result, mapOf("code" to "ok", "items" to items))
            }
        }
    }

    // the payment sheet. only the product and its offer go in: no account
    // id, no profile id
    private fun buy(c: Context, id: String, result: MethodChannel.Result) {
        val d = details[id]
        val token = d?.let { baseOffer(it) }?.offerToken
        val activity = shown?.get()
        if (d == null || token == null || activity == null || activity.isFinishing) {
            return answer(result, "failed")
        }
        connected(c) { bc ->
            if (bc == null) return@connected answer(result, "unavailable")
            val params = BillingFlowParams.newBuilder()
                .setProductDetailsParamsList(
                    listOf(
                        BillingFlowParams.ProductDetailsParams.newBuilder()
                            .setProductDetails(d)
                            .setOfferToken(token)
                            .build()
                    )
                )
                .build()
            val r = bc.launchBillingFlow(activity, params)
            answer(result, codeName(r.responseCode))
        }
    }

    private fun owned(c: Context, result: MethodChannel.Result) {
        connected(c) { bc ->
            if (bc == null) return@connected answer(result, mapOf("code" to "unavailable"))
            val params = QueryPurchasesParams.newBuilder().setProductType(ProductType.INAPP).build()
            bc.queryPurchasesAsync(params) { r, list ->
                answer(
                    result,
                    mapOf("code" to codeName(r.responseCode), "purchases" to list.map { purchaseMap(it) }),
                )
            }
        }
    }

    // kept, never consumed: an acknowledged product comes back on a new
    // install from queryPurchasesAsync
    private fun ack(c: Context, token: String, result: MethodChannel.Result) {
        if (token.isEmpty()) return answer(result, "failed")
        connected(c) { bc ->
            if (bc == null) return@connected answer(result, "unavailable")
            val params = AcknowledgePurchaseParams.newBuilder().setPurchaseToken(token).build()
            bc.acknowledgePurchase(params) { r -> answer(result, codeName(r.responseCode)) }
        }
    }

    // a payment sheet closed, or a pending payment went through while the
    // app runs: dart grants the badge and acknowledges
    override fun onPurchasesUpdated(r: BillingResult, purchases: MutableList<Purchase>?) {
        val args = mapOf(
            "code" to codeName(r.responseCode),
            "purchases" to (purchases ?: emptyList()).map { purchaseMap(it) },
        )
        main.post {
            val engine = FlutterEngineCache.getInstance().get(HaloApplication.ENGINE_ID) ?: return@post
            try {
                MethodChannel(engine.dartExecutor.binaryMessenger, CHANNEL).invokeMethod("updated", args)
            } catch (e: Exception) {
                DebugLog.i("halo-engine", "tips: dart not reachable: ${e.javaClass.simpleName}")
            }
        }
    }
}
