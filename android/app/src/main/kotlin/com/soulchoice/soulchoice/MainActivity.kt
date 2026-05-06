package com.soulchoice.soulchoice

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.URL
import javax.net.ssl.HttpsURLConnection
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {

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
                    val urlStr      = call.argument<String>("url")!!
                    val accessToken = call.argument<String>("accessToken")!!
                    val apiKey      = call.argument<String>("apiKey")!!
                    val bytes       = call.argument<ByteArray>("bytes")!!
                    val contentType = call.argument<String>("contentType")!!

                    thread {
                        var conn: HttpsURLConnection? = null
                        try {
                            val (uploadBytes, uploadContentType) = if (contentType == "image/png") {
                                Pair(compressToJpeg(bytes), "image/jpeg")
                            } else {
                                Pair(bytes, contentType)
                            }

                            conn = URL(urlStr).openConnection() as HttpsURLConnection
                            conn.requestMethod = "PUT"
                            conn.doOutput = true
                            conn.connectTimeout = 30_000
                            conn.readTimeout = 120_000
                            // Streams body immediately without buffering the whole thing in RAM first.
                            // Without this, HttpURLConnection buffers the entire body → nginx sees 0 bytes.
                            conn.setFixedLengthStreamingMode(uploadBytes.size.toLong())
                            conn.setRequestProperty("Authorization", "Bearer $accessToken")
                            conn.setRequestProperty("apikey", apiKey)
                            conn.setRequestProperty("x-upsert", "true")
                            conn.setRequestProperty("Content-Type", uploadContentType)

                            conn.outputStream.use { out ->
                                val chunkSize = 65536
                                var offset = 0
                                while (offset < uploadBytes.size) {
                                    val end = minOf(offset + chunkSize, uploadBytes.size)
                                    out.write(uploadBytes, offset, end - offset)
                                    offset = end
                                }
                                out.flush()
                            }

                            val code = conn.responseCode
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
                        } finally {
                            conn?.disconnect()
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
