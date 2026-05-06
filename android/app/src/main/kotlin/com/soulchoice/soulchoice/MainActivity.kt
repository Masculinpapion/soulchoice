package com.soulchoice.soulchoice

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .writeTimeout(5, TimeUnit.MINUTES)
        .readTimeout(2, TimeUnit.MINUTES)
        .build()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.soulchoice/uploader")
            .setMethodCallHandler { call, result ->
                if (call.method == "uploadBytes") {
                    val url         = call.argument<String>("url")!!
                    val accessToken = call.argument<String>("accessToken")!!
                    val apiKey      = call.argument<String>("apiKey")!!
                    val bytes       = call.argument<ByteArray>("bytes")!!
                    val contentType = call.argument<String>("contentType")!!

                    thread {
                        try {
                            val body = bytes.toRequestBody(contentType.toMediaType())
                            val request = Request.Builder()
                                .url(url)
                                .put(body)
                                .addHeader("Authorization", "Bearer $accessToken")
                                .addHeader("apikey", apiKey)
                                .addHeader("x-upsert", "true")
                                .build()

                            val response = httpClient.newCall(request).execute()
                            val code = response.code
                            response.close()

                            runOnUiThread {
                                if (code in 200..299) {
                                    result.success(code)
                                } else {
                                    result.error("HTTP_$code", "Upload failed with status $code", null)
                                }
                            }
                        } catch (e: Exception) {
                            runOnUiThread {
                                result.error("UPLOAD_ERROR", e.message ?: "Unknown error", null)
                            }
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
