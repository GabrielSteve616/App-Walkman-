package br.com.walkman.walkman

import android.content.ContentProvider
import android.content.ContentValues
import android.database.Cursor
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.ParcelFileDescriptor
import java.io.File
import java.security.MessageDigest

/** Private, read-only artwork provider. Audio is never copied. */
class AlbumArtProvider : ContentProvider() {
    override fun onCreate() = true
    override fun getType(uri: Uri) = "image/jpeg"
    override fun query(uri: Uri, projection: Array<out String>?, selection: String?, args: Array<out String>?, order: String?): Cursor? = null
    override fun insert(uri: Uri, values: ContentValues?): Uri? = null
    override fun delete(uri: Uri, selection: String?, args: Array<out String>?) = 0
    override fun update(uri: Uri, values: ContentValues?, selection: String?, args: Array<out String>?) = 0
    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw java.io.FileNotFoundException("Read only")
        val ctx = context ?: throw java.io.FileNotFoundException()
        val source = uri.getQueryParameter("source") ?: throw java.io.FileNotFoundException()
        val audio = Uri.parse(source)
        if (audio.scheme != "content" && audio.scheme != "file") throw java.io.FileNotFoundException()
        val key = MessageDigest.getInstance("SHA-256").digest(source.toByteArray()).joinToString("") { "%02x".format(it) }
        val directory = File(ctx.cacheDir,"notification_art").apply { mkdirs() }
        val file = File(directory,"$key.jpg")
        synchronized(lock) {
            if (!file.exists()) {
                var bitmap: Bitmap? = null
                val retriever = MediaMetadataRetriever()
                try {
                    retriever.setDataSource(ctx,audio)
                    retriever.embeddedPicture?.let { bytes ->
                        val options=BitmapFactory.Options().apply { inJustDecodeBounds=true }
                        BitmapFactory.decodeByteArray(bytes,0,bytes.size,options)
                        var sample=1
                        while(options.outWidth/sample>384 || options.outHeight/sample>384)sample*=2
                        options.inJustDecodeBounds=false;options.inSampleSize=sample
                        bitmap=BitmapFactory.decodeByteArray(bytes,0,bytes.size,options)
                    }
                } catch (_: Exception) { } finally { try { retriever.release() } catch (_: Exception) { } }
                val result=bitmap?:TapeGraphics.cassette()
                file.outputStream().use { result.compress(Bitmap.CompressFormat.JPEG,87,it) };result.recycle()
                directory.listFiles()?.sortedByDescending { it.lastModified() }?.drop(96)?.forEach { it.delete() }
            }
        }
        file.setLastModified(System.currentTimeMillis())
        return ParcelFileDescriptor.open(file,ParcelFileDescriptor.MODE_READ_ONLY)
    }
    companion object { private val lock=Any() }
}
