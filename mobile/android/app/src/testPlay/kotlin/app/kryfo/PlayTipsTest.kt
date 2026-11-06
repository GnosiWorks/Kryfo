// SPDX-License-Identifier: GPL-3.0-or-later
package app.kryfo

import com.android.billingclient.api.BillingClient.BillingResponseCode
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

// what the tip jar hands dart of a purchase: its product, state, token and
// whether play heard of it. never the order id, the account or the package
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], application = android.app.Application::class)
class PlayTipsTest {
    private fun purchase(state: Int, acked: Boolean) = Purchase(
        """
        {"orderId":"GPA.1234-5678-9012-34567","packageName":"app.kryfo",
         "productId":"tip_patron","productIds":["tip_patron"],
         "purchaseTime":1762300000000,"purchaseState":${if (state == Purchase.PurchaseState.PENDING) 4 else 0},
         "purchaseToken":"tok-abc","quantity":1,"acknowledged":$acked}
        """.trimIndent(),
        "sig",
    )

    @Test
    fun aPurchaseGoesOverWithoutItsOrderId() {
        val m = PlayTips.purchaseMap(purchase(Purchase.PurchaseState.PURCHASED, false))
        assertEquals(setOf("products", "state", "token", "acked"), m.keys)
        assertEquals(listOf("tip_patron"), m["products"])
        assertEquals("purchased", m["state"])
        assertEquals("tok-abc", m["token"])
        assertEquals(false, m["acked"])
        assertFalse(m.values.joinToString().contains("GPA."))
        assertFalse(m.values.joinToString().contains("app.kryfo"))
    }

    @Test
    fun aPendingOneSaysSo() {
        val m = PlayTips.purchaseMap(purchase(Purchase.PurchaseState.PENDING, false))
        assertEquals("pending", m["state"])
        assertEquals(true, PlayTips.purchaseMap(purchase(Purchase.PurchaseState.PURCHASED, true))["acked"])
    }

    @Test
    fun responsesReadAsDartReadsThem() {
        assertEquals("ok", PlayTips.codeName(BillingResponseCode.OK))
        assertEquals("canceled", PlayTips.codeName(BillingResponseCode.USER_CANCELED))
        assertEquals("owned", PlayTips.codeName(BillingResponseCode.ITEM_ALREADY_OWNED))
        assertEquals("missing", PlayTips.codeName(BillingResponseCode.ITEM_UNAVAILABLE))
        for (c in listOf(
            BillingResponseCode.BILLING_UNAVAILABLE,
            BillingResponseCode.SERVICE_UNAVAILABLE,
            BillingResponseCode.FEATURE_NOT_SUPPORTED,
        )) {
            assertEquals("unavailable", PlayTips.codeName(c))
        }
        assertEquals("failed", PlayTips.codeName(BillingResponseCode.ERROR))
        assertEquals("failed", PlayTips.codeName(BillingResponseCode.DEVELOPER_ERROR))
    }

    // play's own json for a one-time product, as queryProductDetailsAsync
    // builds it
    private fun option(option: String?, offer: String?, price: String, token: String) =
        """{"purchaseOptionId":${q(option)},"offerId":${q(offer)},"offerIdToken":"$token",
           "formattedPrice":"$price","priceAmountMicros":1,"priceCurrencyCode":"EUR"}"""

    private fun q(s: String?) = if (s == null) "\"\"" else "\"$s\""

    private fun product(vararg options: String): ProductDetails {
        val json = """{"productId":"tip_patron","type":"inapp","title":"t","name":"n",
            "description":"d","skuDetailsToken":"x",
            "oneTimePurchaseOfferDetailsList":[${options.joinToString(",")}]}"""
        val make = ProductDetails::class.java.getDeclaredConstructor(String::class.java)
        make.isAccessible = true
        return make.newInstance(json)
    }

    @Test
    fun oneOptionIsTheOne() {
        val o = PlayTips.baseOffer(product(option("buy", null, "€14.99", "base")))!!
        assertEquals("base", o.offerToken)
        assertEquals("€14.99", o.formattedPrice)
    }

    @Test
    fun aDiscountListedFirstIsPassedOver() {
        val o = PlayTips.baseOffer(
            product(
                option("buy", "spring", "€9.99", "discount"),
                option("buy", null, "€14.99", "base"),
            )
        )!!
        assertEquals("base", o.offerToken)
        assertEquals("€14.99", o.formattedPrice)
    }

    @Test
    fun withoutABuyOptionTheBasePriceStillWins() {
        val o = PlayTips.baseOffer(
            product(
                option("other", "spring", "€9.99", "discount"),
                option("other", null, "€14.99", "base"),
            )
        )!!
        assertEquals("base", o.offerToken)
        assertEquals("other", o.purchaseOptionId)
        val only = PlayTips.baseOffer(product(option("other", "spring", "€9.99", "discount")))!!
        assertEquals("discount", only.offerToken)
    }

    @Test
    fun noOptionsNoOffer() {
        assertNull(PlayTips.baseOffer(product()))
    }
}
