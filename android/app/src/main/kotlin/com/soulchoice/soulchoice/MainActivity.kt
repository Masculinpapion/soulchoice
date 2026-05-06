package com.soulchoice.soulchoice

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {

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
                            val conn = URL(url).openConnection() as HttpURLConnection
                            conn.requestMethod = "PUT"
                            conn.doOutput = true
                            conn.connectTimeout = 30_000
                            conn.readTimeout    = 300_000
                            conn.setFixedLengthStreamingMode(bytes.size.toLong())
                            conn.setRequestProperty("Authorization", "Bearer $accessToken")
                            conn.setRequestProperty("apikey", apiKey)
                            conn.setRequestProperty("Content-Type", contentType)
                            conn.setRequestProperty("x-upsert", "true")

                            conn.outputStream.use { it.write(bytes) }

                            val code = conn.responseCode
                            conn.disconnect()

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
