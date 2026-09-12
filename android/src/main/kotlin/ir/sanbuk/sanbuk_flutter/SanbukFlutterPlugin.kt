package ir.sanbuk.sanbuk_flutter

import android.content.Context
import android.view.View
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory
import ir.sanbuk.sdk.Sanbuk
import ir.sanbuk.sdk.SanbukAd
import ir.sanbuk.sdk.SanbukAdView
import ir.sanbuk.sdk.SanbukConfig
import ir.sanbuk.sdk.SanbukFullscreen
import java.util.concurrent.atomic.AtomicInteger

/**
 * The Android half of the Flutter binding.
 *
 * A translator, nothing more: it turns a method call into a call on the native
 * SDK and turns the answer back into something the standard codec can carry.
 * Every decision — which ad, when a view counts, when a full-screen ad may
 * interrupt — stays in the native core, where it is written once and shared by
 * every shell. A rule copied into this file would have to be copied again into
 * the Unity and React Native shells, and the copies would drift, because the
 * shells ship at different speeds.
 *
 * Nothing here throws into Flutter. An ad that cannot be found answers with a
 * null rather than an error: the worst an advertisement may cost a publisher's
 * app is an empty box.
 */
class SanbukFlutterPlugin : FlutterPlugin, MethodChannel.MethodCallHandler, ActivityAware {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    /**
     * Ads and loaded full-screen ads the Dart side still holds a handle to.
     *
     * A live ad cannot cross the channel — it has a session behind it and has
     * to be able to report its own impression — so Dart holds an int and the
     * object stays here, capped, because a map that only grows is a leak with a
     * slow fuse.
     */
    private val ads = object : LinkedHashMap<Int, SanbukAd>(16, 0.75f, false) {
        // Ads outlive their own impression, so nothing removes them one by one
        // and the map would grow for as long as the app runs. A feed that loads
        // an ad every few rows reaches thousands in a session. The oldest goes
        // at the cap: by then it is off screen and out of reach of any click.
        override fun removeEldestEntry(eldest: MutableMap.MutableEntry<Int, SanbukAd>) =
            size > MAX_LIVE_ADS
    }

    private val fullscreens = HashMap<Int, SanbukFullscreen>()
    private val handles = AtomicInteger(0)

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL)
        channel.setMethodCallHandler(this)
        registerAdView(binding.binaryMessenger, binding.platformViewRegistry)
    }

    private fun registerAdView(
        messenger: BinaryMessenger,
        registry: io.flutter.plugin.platform.PlatformViewRegistry,
    ) {
        registry.registerViewFactory(
            VIEW_TYPE,
            object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(viewContext: Context, id: Int, args: Any?): PlatformView {
                    val placement = ((args as? Map<*, *>)?.get("placementCode") as? String).orEmpty()

                    return SanbukPlatformView(viewContext, placement)
                }
            },
        )
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "init" -> {
                val mediaCode = call.argument<String>("mediaCode").orEmpty()
                Sanbuk.init(
                    context,
                    SanbukConfig(
                        mediaCode = mediaCode,
                        debug = call.argument<Boolean>("debug") ?: false,
                    ),
                )
                result.success(null)
            }

            "loadAd" -> {
                val placement = call.argument<String>("placementCode").orEmpty()
                Sanbuk.loadAd(context, placement) { ad ->
                    if (ad == null) {
                        result.success(null)
                        return@loadAd
                    }
                    val handle = handles.incrementAndGet()
                    ads[handle] = ad
                    result.success(describe(handle, ad))
                }
            }

            "recordImpression" -> {
                // Kept, not removed. An ad is reported when it appears and
                // clicked afterwards, so dropping it here would silently
                // swallow every click — the publisher does the work and earns
                // nothing. Counting twice is already impossible: the native ad
                // guards it, and so does the Dart wrapper.
                ads[call.argument<Int>("adId")]?.recordImpression()
                result.success(null)
            }

            "click" -> {
                ads[call.argument<Int>("adId")]?.click(activity ?: context)
                result.success(null)
            }

            "loadFullscreen" -> {
                val placement = call.argument<String>("placementCode").orEmpty()
                val rewarded = call.argument<Boolean>("rewarded") ?: false
                val onResult: (SanbukFullscreen?) -> Unit = { ad ->
                    if (ad == null) {
                        result.success(null)
                    } else {
                        val handle = handles.incrementAndGet()
                        fullscreens[handle] = ad
                        result.success(handle)
                    }
                }
                if (rewarded) {
                    SanbukFullscreen.loadRewarded(context, placement, onResult)
                } else {
                    SanbukFullscreen.load(context, placement, onResult)
                }
            }

            "showFullscreen" -> {
                val handle = call.argument<Int>("handle")
                // Shown once: a loaded full-screen ad is spent when it appears.
                fullscreens.remove(handle)?.show(activity ?: context)
                result.success(null)
            }

            else -> result.notImplemented()
        }
    }

    /** The drawable half, in the flat shape the standard codec can carry. */
    private fun describe(handle: Int, ad: SanbukAd): Map<String, Any?> = mapOf(
        "id" to handle,
        "format" to ad.format,
        "campaignId" to ad.campaignId,
        "headline" to ad.headline,
        "body" to ad.body,
        "callToAction" to ad.callToAction,
        "imageUrl" to ad.imageUrl,
        "logoUrl" to ad.logoUrl,
        "brandColor" to ad.brandColor,
    )

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        ads.clear()
        fullscreens.clear()
    }

    // A click and a full-screen ad want an Activity when there is one: starting
    // either from the application context forces a new task, which drops the
    // visitor outside the publisher's app.
    private var activity: android.app.Activity? = null

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    private companion object {
        const val MAX_LIVE_ADS = 64
        const val CHANNEL = "ir.sanbuk/sdk"
        const val VIEW_TYPE = "ir.sanbuk/adView"
    }
}

/** Hosts the SDK's own view; the renderer and its viewability gate are its own. */
private class SanbukPlatformView(context: Context, placementCode: String) : PlatformView {

    private val view = SanbukAdView(context).apply { load(placementCode) }

    override fun getView(): View = view

    override fun dispose() {
        // The view stops its own sampling on detach; nothing else is held.
    }
}
