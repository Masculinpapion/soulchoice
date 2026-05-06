package com.soulchoice.soulchoice

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import javax.net.ssl.HttpsURLConnection
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "SCUploader"
    }

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

                    val executor = Executors.newSingleThreadExecutor()
                    val future = executor.submit<Pair<Int, String?>> uploadTask@{
                        var conn: HttpsURLConnection? = null
                        try {
                            Log.d(TAG, "step=compress size=${bytes.size} ct=$contentType")
                            val (uploadBytes, uploadCT) = if (contentType == "image/png") {
                                Pair(compressToJpeg(bytes), "image/jpeg")
                            } else {
                                Pair(bytes, contentType)
                            }
                            Log.d(TAG, "step=compressed newSize=${uploadBytes.size}")

                            conn = URL(urlStr).openConnection() as HttpsURLConnection
                            conn.requestMethod = "PUT"
                            conn.doOutput = true
                            conn.connectTimeout = 30_000
                            conn.readTimeout = 120_000
                            conn.setFixedLengthStreamingMode(uploadBytes.size.toLong())
                            conn.setRequestProperty("Authorization", "Bearer $accessToken")
                            conn.setRequestProperty("apikey", apiKey)
                            conn.setRequestProperty("x-upsert", "true")
                            conn.setRequestProperty("Content-Type", uploadCT)

                            Log.d(TAG, "step=connecting url=$urlStr")
                            conn.connect()
                            Log.d(TAG, "step=connected writing=${uploadBytes.size}bytes")

                            conn.outputStream.use { out ->
                                val chunk = 32768
                                var offset = 0
                                while (offset < uploadBytes.size) {
                                    val end = minOf(offset + chunk, uploadBytes.size)
                                    out.write(uploadBytes, offset, end - offset)
                                    offset = end
                                    Log.d(TAG, "step=written offset=$offset total=${uploadBytes.size}")
                                }
                                out.flush()
                            }
                            Log.d(TAG, "step=body_done reading_response")

                            val code = conn.responseCode
                            Log.d(TAG, "step=response code=$code")
                            Pair(code, null)
                        } catch (e: Exception) {
                            Log.e(TAG, "step=error ${e.javaClass.simpleName}: ${e.message}", e)
                            Pair(-1, "${e.javaClass.simpleName}: ${e.message}")
                        } finally {
                            conn?.disconnect()
                        }
                    }

                    thread {
                        try {
                            val (code, error) = future.get(5, TimeUnit.MINUTES)
                            runOnUiThread {
                                if (error != null) {
                                    result.error("UPLOAD_ERROR", error, null)
                                } else if (code in 200..299) {
                                    result.success(code)
                                } else {
                                    result.error("HTTP_$code", "Upload failed with status $code", null)
                                }
                            }
                        } catch (e: TimeoutException) {
                            future.cancel(true)
                            Log.e(TAG, "step=TIMEOUT 5min exceeded")
                            runOnUiThread {
                                result.error("UPLOAD_ERROR", "TimeoutException: upload exceeded 5 minutes", null)
                            }
                        } finally {
                            executor.shutdown()
                        }
                    }
                } else {
                    result.notImplemented()
                }
            }
    }
}
