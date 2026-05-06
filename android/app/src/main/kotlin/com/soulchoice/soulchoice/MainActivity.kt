package com.soulchoice.soulchoice

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.util.concurrent.TimeUnit
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {

    private val httpClient = OkHttpClient.Builder()
        .connectTimeout(60, TimeUnit.SECONDS)
        .writeTimeout(5, TimeUnit.MINUTES)
        .readTimeout(2, TimeUnit.MINUTES)
        .protocols(listOf(Protocol.HTTP_1_1))
        .build()

    private fun compressToJpeg(bytes: ByteArray): ByteArray {
        val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: throw IOException("Failed to decode image bytes")
        val baos = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.JPEG, 82, baos)
        bitmap.recycle()
        return baos.toByteArray()
    }

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
                            val (uploadBytes, uploadContentType) = if (contentType == "image/png") {
                                Pair(compressToJpeg(bytes), "image/jpeg")
                            } else {
                                Pair(bytes, contentType)
                            }

                            val body = uploadBytes.toRequestBody(uploadContentType.toMediaType())
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
                                result.error("UPLOAD_ERROR", "${e.javaClass.simpleName}: ${e.message}", null)
                            }
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
