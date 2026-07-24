package com.soulchoice.soulchoice

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.Base64
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.IOException
import java.net.URI
import java.net.URL
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException
import javax.net.ssl.HttpsURLConnection
import kotlin.concurrent.thread

class MainActivity : FlutterActivity() {

    companion object {
        private const val TAG = "SCUploader"
        private const val CHUNK = 65536 // 64 KB per PATCH — small enough to pass ISP DPI
    }

    private fun b64(s: String): String =
        Base64.encodeToString(s.toByteArray(Charsets.UTF_8), Base64.NO_WRAP)

    private fun compressToJpeg(bytes: ByteArray): ByteArray {
        val bm = BitmapFactory.decodeByteArray(bytes, 0, bytes.size)
            ?: throw IOException("Failed to decode image")
        val out = ByteArrayOutputStream()
        bm.compress(Bitmap.CompressFormat.JPEG, 82, out)
        bm.recycle()
        return out.toByteArray()
    }

    private fun openConn(url: URL, accessToken: String, apiKey: String): HttpsURLConnection =
        (url.openConnection() as HttpsURLConnection).also {
            it.connectTimeout = 30_000
            it.readTimeout    = 60_000
            it.setRequestProperty("Authorization", "Bearer $accessToken")
            it.setRequestProperty("apikey", apiKey)
            it.setRequestProperty("Tus-Resumable", "1.0.0")
        }

    private fun tusUpload(
        storageUrl: String,   // e.g. https://host/storage/v1/object/bucket/uid/file.jpg
        accessToken: String,
        apiKey: String,
        bytes: ByteArray,
        contentType: String
    ) {
        // Parse bucket and object path from the storage URL
        val uri = URI(storageUrl)
        val base = "${uri.scheme}://${uri.host}"
        val after = uri.path.removePrefix("/storage/v1/object/")
        val slash = after.indexOf('/')
        val bucket = after.substring(0, slash)
        val objPath = after.substring(slash + 1)

        val metadata = "bucketName ${b64(bucket)}," +
                "objectName ${b64(objPath)}," +
                "contentType ${b64(contentType)}," +
                "cacheControl ${b64("max-age=3600")}"

        // ── Step 1: create TUS upload ──────────────────────────────────────────
        Log.d(TAG, "TUS create: bucket=$bucket path=$objPath size=${bytes.size}")
        val createConn = openConn(URL("$base/storage/v1/upload/resumable"), accessToken, apiKey)
        createConn.requestMethod = "POST"
        createConn.setRequestProperty("Upload-Length", bytes.size.toString())
        createConn.setRequestProperty("Upload-Metadata", metadata)
        createConn.setRequestProperty("Content-Length", "0")
        createConn.setRequestProperty("x-upsert", "true")

        val createCode = createConn.responseCode
        val location   = createConn.getHeaderField("Location")
        createConn.disconnect()

        if (createCode != 201 || location == null)
            throw IOException("TUS create failed: HTTP $createCode")
        Log.d(TAG, "TUS location: $location")

        val uploadUrl = if (location.startsWith("http")) URL(location)
                        else URL("$base$location")

        // ── Step 2: PATCH in 64 KB chunks ─────────────────────────────────────
        var offset = 0
        while (offset < bytes.size) {
            val chunkLen = minOf(CHUNK, bytes.size - offset)

            val patchConn = openConn(uploadUrl, accessToken, apiKey)
            patchConn.requestMethod = "PATCH"
            patchConn.doOutput = true
            patchConn.setFixedLengthStreamingMode(chunkLen.toLong())
            patchConn.setRequestProperty("Upload-Offset", offset.toString())
            patchConn.setRequestProperty("Content-Type", "application/offset+octet-stream")

            Log.d(TAG, "TUS PATCH offset=$offset len=$chunkLen")
            patchConn.outputStream.use { it.write(bytes, offset, chunkLen); it.flush() }

            val patchCode = patchConn.responseCode
            patchConn.disconnect()

            if (patchCode != 204)
                throw IOException("TUS PATCH failed at offset=$offset: HTTP $patchCode")

            offset += chunkLen
            Log.d(TAG, "TUS chunk OK totalDone=$offset/${bytes.size}")
        }

        Log.d(TAG, "TUS upload complete")
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "com.soulchoice/uploader")
            .setMethodCallHandler { call, result ->
                if (call.method != "uploadBytes") { result.notImplemented(); return@setMethodCallHandler }

                val url         = call.argument<String>("url")!!
                val accessToken = call.argument<String>("accessToken")!!
                val apiKey      = call.argument<String>("apiKey")!!
                val bytes       = call.argument<ByteArray>("bytes")!!
                val contentType = call.argument<String>("contentType")!!

                val executor = Executors.newSingleThreadExecutor()
                val future = executor.submit<String?> {
                    try {
                        Log.d(TAG, "Compress ${bytes.size}B ct=$contentType")
                        // 24.07 E2E: sıkıştırma yalnız PNG'de çalışıyordu; büyük JPEG'ler
                        // (crop çıktısı 1-3MB) ham gidip yüklemeyi uzatıyordu — tüm görseller normalize edilir.
                        val (uploadBytes, uploadCT) = if (contentType.startsWith("image/"))
                            Pair(compressToJpeg(bytes), "image/jpeg") else Pair(bytes, contentType)
                        Log.d(TAG, "Compressed → ${uploadBytes.size}B")

                        tusUpload(url, accessToken, apiKey, uploadBytes, uploadCT)
                        null
                    } catch (e: Exception) {
                        Log.e(TAG, "Upload failed: ${e.javaClass.simpleName}: ${e.message}", e)
                        "${e.javaClass.simpleName}: ${e.message}"
                    }
                }

                thread {
                    try {
                        val error = future.get(10, TimeUnit.MINUTES)
                        runOnUiThread {
                            if (error == null) result.success(200)
                            else result.error("UPLOAD_ERROR", error, null)
                        }
                    } catch (e: TimeoutException) {
                        future.cancel(true)
                        runOnUiThread { result.error("UPLOAD_ERROR", "TimeoutException: >10 min", null) }
                    } finally {
                        executor.shutdown()
                    }
                }
            }
    }
}
