package br.com.walkman.walkman

import android.Manifest
import android.app.Activity
import android.content.ContentValues
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.concurrent.ExecutorService

/** Exporta somente arquivos temporários do próprio app e lê o documento escolhido. */
class BackupChannel(private val activity: MainActivity, private val worker: ExecutorService) {
    private var picking: MethodChannel.Result? = null
    private var waitingExport: Pair<String, MethodChannel.Result>? = null
    private var savingAs: Pair<String, MethodChannel.Result>? = null
    private var exporting = false
    private val prefs get() = activity.getSharedPreferences("music_library", Activity.MODE_PRIVATE)
    private val limit = 128L * 1024 * 1024

    fun attach(engine: FlutterEngine) {
        MethodChannel(engine.dartExecutor.binaryMessenger, "walkmen/backup").setMethodCallHandler { call, result ->
            when (call.method) {
                "selectedFolder" -> result.success(prefs.getString("folder", null))
                "restoreFolder" -> {
                    val saved = call.argument<String>("folder")
                    if (saved == null) { prefs.edit().remove("folder").apply(); result.success(false) }
                    else {
                        val allowed = try {
                            val uri = Uri.parse(saved)
                            uri.scheme == "content" && activity.contentResolver.persistedUriPermissions.any { it.uri == uri && it.isReadPermission }
                        } catch (_: Exception) { false }
                        if (allowed) prefs.edit().putString("folder", saved).apply() else prefs.edit().remove("folder").apply()
                        result.success(allowed)
                    }
                }
                "pick" -> {
                    if (picking != null || savingAs != null || exporting || waitingExport != null) { result.error("BUSY", "Outra operação de backup está em andamento.", null); return@setMethodCallHandler }
                    picking = result
                    try {
                        @Suppress("DEPRECATION")
                        activity.startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(Intent.EXTRA_MIME_TYPES, arrayOf("application/json", "text/plain", "application/octet-stream"))
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }, 205)
                    } catch (_: Exception) { picking = null; result.error("PICK_ERROR", "Não foi possível abrir o seletor de arquivos.", null) }
                }
                "export" -> {
                    val path = call.argument<String>("path")
                    if (path == null || exporting || waitingExport != null || savingAs != null || picking != null) {
                        result.error("BUSY", "Não foi possível iniciar a exportação.", null); return@setMethodCallHandler
                    }
                    if (Build.VERSION.SDK_INT < 29 && activity.checkSelfPermission(Manifest.permission.WRITE_EXTERNAL_STORAGE) != PackageManager.PERMISSION_GRANTED) {
                        waitingExport = path to result
                        activity.requestPermissions(arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), 204)
                    } else export(path, result)
                }
                "exportToFile" -> {
                    val path = call.argument<String>("path")
                    if (path == null || exporting || waitingExport != null || savingAs != null || picking != null) {
                        result.error("BUSY", "Outra operação de backup está em andamento.", null); return@setMethodCallHandler
                    }
                    try {
                        temporaryFile(path)
                        savingAs = path to result
                        @Suppress("DEPRECATION")
                        activity.startActivityForResult(Intent(Intent.ACTION_CREATE_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "application/json"
                            putExtra(Intent.EXTRA_TITLE, backupName())
                            addFlags(Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                        }, 206)
                    } catch (_: Exception) {
                        savingAs = null
                        result.error("SAVE_PICKER_ERROR", "Não foi possível abrir o seletor para salvar.", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    fun permission(request: Int, grants: IntArray) {
        if (request != 204) return
        val pending = waitingExport ?: return
        waitingExport = null
        if (grants.firstOrNull() == PackageManager.PERMISSION_GRANTED) export(pending.first, pending.second)
        else pending.second.error("PERMISSION_DENIED", "Permita o acesso aos arquivos para salvar em Downloads.", null)
    }
    fun activityResult(request: Int, code: Int, data: Intent?) {
        if (request == 206) {
            val pending = savingAs ?: return
            savingAs = null
            val uri = data?.data
            if (code != Activity.RESULT_OK || uri == null) { pending.second.success(null); return }
            exportSelected(pending.first, uri, pending.second)
            return
        }
        if (request != 205) return
        val result = picking ?: return
        picking = null
        val uri = data?.data
        if (code != Activity.RESULT_OK || uri == null) { result.success(null); return }
        worker.execute {
            var temp: File? = null
            try {
                temp = File.createTempFile("walkmen-import-", ".json", activity.cacheDir)
                val target = temp
                activity.contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(target).use { output ->
                        val buffer = ByteArray(16384); var total = 0L
                        while (true) {
                            val read = input.read(buffer); if (read < 0) break
                            total += read
                            if (total > limit) throw IllegalArgumentException("Arquivo maior que 128 MB")
                            output.write(buffer, 0, read)
                        }
                    }
                } ?: throw IllegalStateException("Arquivo indisponível")
                activity.runOnUiThread { if (!activity.isDestroyed) result.success(target.absolutePath) else target.delete() }
            } catch (_: Exception) {
                temp?.delete()
                activity.runOnUiThread { if (!activity.isDestroyed) result.error("READ_ERROR", "Não foi possível ler o backup. O limite é 128 MB.", null) }
            }
        }
    }
    private fun backupName(): String = "Walkmen-backup-" + SimpleDateFormat("yyyyMMdd-HHmmss-SSS", Locale.ROOT).format(Date()) + ".json"
    private fun temporaryFile(path: String): File {
        val cache = activity.cacheDir.canonicalFile
        val source = File(path).canonicalFile
        require(source.parentFile == cache && source.isFile && source.length() <= limit)
        return source
    }
    private fun exportSelected(path: String, uri: Uri, result: MethodChannel.Result) {
        exporting = true
        worker.execute {
            try {
                val source = temporaryFile(path)
                activity.contentResolver.openOutputStream(uri, "wt")?.use { output ->
                    source.inputStream().use { it.copyTo(output) }
                } ?: throw IllegalStateException("Arquivo indisponível")
                val name = try {
                    activity.contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
                        if (cursor.moveToFirst()) cursor.getString(0) else null
                    }
                } catch (_: Exception) { null }
                activity.runOnUiThread { exporting = false; if (!activity.isDestroyed) result.success(name ?: "Backup.json") }
            } catch (_: Exception) {
                activity.runOnUiThread { exporting = false; if (!activity.isDestroyed) result.error("EXPORT_ERROR", "Não foi possível concluir. O arquivo escolhido pode estar incompleto.", null) }
            }
        }
    }
    private fun export(path: String, result: MethodChannel.Result) {
        exporting = true
        worker.execute {
            var published: Uri? = null
            var legacy: File? = null
            var createdLegacy = false
            try {
                val source = temporaryFile(path)
                val name = backupName()
                if (Build.VERSION.SDK_INT >= 29) {
                    val values = ContentValues().apply {
                        put(MediaStore.MediaColumns.DISPLAY_NAME, name)
                        put(MediaStore.MediaColumns.MIME_TYPE, "application/json")
                        put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS + "/")
                        put(MediaStore.MediaColumns.IS_PENDING, 1)
                    }
                    published = activity.contentResolver.insert(MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                        ?: throw IllegalStateException("Não foi possível criar o arquivo")
                    activity.contentResolver.openOutputStream(published, "w")?.use { output -> source.inputStream().use { it.copyTo(output) } }
                        ?: throw IllegalStateException("Não foi possível escrever o arquivo")
                    val updated = activity.contentResolver.update(published, ContentValues().apply { put(MediaStore.MediaColumns.IS_PENDING, 0) }, null, null)
                    if (updated != 1) throw IllegalStateException("Não foi possível publicar o arquivo")
                } else {
                    @Suppress("DEPRECATION")
                    val folder = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
                    if (!folder.exists() && !folder.mkdirs()) throw IllegalStateException("Downloads indisponível")
                    legacy = File(folder, name)
                    if (!legacy.createNewFile()) throw IllegalStateException("Arquivo já existe")
                    createdLegacy = true
                    FileOutputStream(legacy).use { output -> source.inputStream().use { it.copyTo(output) } }
                    android.media.MediaScannerConnection.scanFile(activity, arrayOf(legacy.absolutePath), arrayOf("application/json"), null)
                }
                activity.runOnUiThread { exporting = false; if (!activity.isDestroyed) result.success(name) }
            } catch (_: Exception) {
                if (published != null) try { activity.contentResolver.delete(published, null, null) } catch (_: Exception) { }
                if (createdLegacy) legacy?.delete()
                activity.runOnUiThread { exporting = false; if (!activity.isDestroyed) result.error("EXPORT_ERROR", "Não foi possível salvar o backup em Downloads.", null) }
            }
        }
    }
}
