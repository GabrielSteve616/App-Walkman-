package br.com.walkman.walkman

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.provider.Settings
import android.provider.DocumentsContract
import com.ryanheise.audioservice.AudioServiceActivity
import android.media.MediaMetadataRetriever
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import java.io.ByteArrayOutputStream
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : AudioServiceActivity() {
    override fun onStart() { super.onStart(); com.ryanheise.audioservice.AudioService.uiVisible = true; com.ryanheise.audioservice.AudioService.refreshNotificationVisuals() }
    override fun onStop() { com.ryanheise.audioservice.AudioService.uiVisible = false; com.ryanheise.audioservice.AudioService.refreshNotificationVisuals(); super.onStop() }
    private var companionChannel: MethodChannel? = null
    private var companionReady = false
    private var pendingAction: Map<String,String>? = null
    private var notificationResult: MethodChannel.Result? = null
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        captureWidgetIntent(intent)
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        captureWidgetIntent(intent)
    }
    private fun captureWidgetIntent(intent: Intent?) {
        val action=intent?.getStringExtra("walkmen_action")?:return
        val payload=mapOf("action" to action,"id" to (intent.getStringExtra("walkmen_id")?:""))
        intent.removeExtra("walkmen_action")
        if(companionReady)companionChannel?.invokeMethod("launch",payload)else pendingAction=payload
    }
    private val worker = Executors.newFixedThreadPool(2)
    private val backupChannel by lazy { BackupChannel(this, worker) }
    private var permissionResult: MethodChannel.Result? = null
    private var folderResult: MethodChannel.Result? = null
    private val preferences by lazy { getSharedPreferences("music_library", MODE_PRIVATE) }
    private val audioPermission: String
        get() = if (Build.VERSION.SDK_INT >= 33) Manifest.permission.READ_MEDIA_AUDIO
            else Manifest.permission.READ_EXTERNAL_STORAGE

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        backupChannel.attach(flutterEngine)
        companionChannel=MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"walkmen/companion").apply {
            setMethodCallHandler { call,result ->
                val prefs=getSharedPreferences("companion",MODE_PRIVATE)
                when(call.method){
                    "ensureNotifications" -> {
                        if(Build.VERSION.SDK_INT<33 || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS)==PackageManager.PERMISSION_GRANTED) result.success(true)
                        else if(prefs.getBoolean("notification_asked",false)||notificationResult!=null)result.success(false)
                        else {
                            prefs.edit().putBoolean("notification_asked",true).apply()
                            notificationResult=result
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS),203)
                        }
                    }
                    "ready" -> { companionReady=true;val action=pendingAction;pendingAction=null;result.success(action) }
                    "syncWidgets" -> {
                        prefs.edit().putString("tapes",call.argument<String>("tapes")?:"[]").apply()
                        ShelfWidget.updateAll(this@MainActivity);WalkmanWidget.updateAll(this@MainActivity);result.success(null)
                    }
                    "savePlayback" -> {
                        val edit=prefs.edit().putInt("last_index",call.argument<Int>("index")?:0)
                        call.argument<String>("queue")?.let { edit.putString("last_queue",it) }
                        call.argument<String>("name")?.let { edit.putString("last_name",it) }
                        edit.apply();result.success(null)
                    }
                    "restorePlayback" -> result.success(mapOf("queue" to (prefs.getString("last_queue","[]")?:"[]"),"index" to prefs.getInt("last_index",0),"name" to prefs.getString("last_name",null)))
                    "pinWidget" -> {
                        val manager=AppWidgetManager.getInstance(this@MainActivity)
                        if(Build.VERSION.SDK_INT>=26&&manager.isRequestPinAppWidgetSupported){
                            val type=if(call.argument<String>("kind")=="shelf")ShelfWidget::class.java else WalkmanWidget::class.java
                            result.success(manager.requestPinAppWidget(ComponentName(this@MainActivity,type),null,null))
                        }else result.success(false)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        // A media engine may outlive its Activity; notify Dart when a new host attaches.
        companionChannel?.invokeMethod("hostAttached",null)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "walkman/library")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "artwork" -> {
                        val uri = call.argument<String>("uri")
                        worker.execute {
                            var bytes: ByteArray? = null
                            if (uri != null) {
                                val retriever = MediaMetadataRetriever()
                                try {
                                    retriever.setDataSource(applicationContext, Uri.parse(uri))
                                    val original = retriever.embeddedPicture
                                    if (original != null) {
                                        val options = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                                        BitmapFactory.decodeByteArray(original, 0, original.size, options)
                                        var sample = 1
                                        while (options.outWidth / sample > 512 || options.outHeight / sample > 512) sample *= 2
                                        options.inJustDecodeBounds = false
                                        options.inSampleSize = sample
                                        val bitmap = BitmapFactory.decodeByteArray(original, 0, original.size, options)
                                        if (bitmap != null) {
                                            val output = ByteArrayOutputStream()
                                            bitmap.compress(Bitmap.CompressFormat.JPEG, 85, output)
                                            bitmap.recycle()
                                            bytes = output.toByteArray()
                                        }
                                    }
                                } catch (_: Exception) { } finally {
                                    try { retriever.release() } catch (_: Exception) { }
                                }
                            }
                            runOnUiThread { if (!isDestroyed) result.success(bytes) }
                        }
                    }
                    "loadTracks" -> {
                        if (preferences.contains("folder")) {
                            queryTracks(result)
                        } else {
                            result.error("CHOOSE_FOLDER", "Escolha a pasta de músicas para começar.", null)
                        }
                    }
                    "folders" -> {
                        val saved = preferences.getString("folder", null)
                        worker.execute {
                            try {
                                val folders = if (saved == null) emptyList<String>()
                                    else AudioCatalog(applicationContext).folders(Uri.parse(saved))
                                runOnUiThread { if (!isDestroyed) result.success(folders) }
                            } catch (_: Exception) { runOnUiThread { if (!isDestroyed) result.success(emptyList<String>()) } }
                        }
                    }
                    "createFolder" -> {
                        val saved = preferences.getString("folder", null)
                        val name = call.argument<String>("name")?.trim().orEmpty()
                        if (saved == null || name.isEmpty() || name.contains('/') || name.contains('\\') || name == "." || name == "..") {
                            result.error("FOLDER_ERROR", "Selecione uma pasta e informe um nome válido.", null)
                        } else worker.execute {
                            try {
                                val tree = Uri.parse(saved)
                                val parent = DocumentsContract.buildDocumentUriUsingTree(tree, DocumentsContract.getTreeDocumentId(tree))
                                val child = DocumentsContract.createDocument(contentResolver, parent,
                                    DocumentsContract.Document.MIME_TYPE_DIR, name)
                                if (child == null) error("Pasta não criada")
                                runOnUiThread { if (!isDestroyed) result.success(null) }
                            } catch (_: Exception) { runOnUiThread { if (!isDestroyed) result.error("FOLDER_ERROR",
                                "Não foi possível criar a pasta. Autorize novamente a pasta em Ajustes para permitir alterações.", null) } }
                        }
                    }
                    "chooseFolder" -> {
                        if (folderResult != null) {
                            result.error("BUSY", "Seleção de pasta em andamento.", null)
                        } else {
                            folderResult = result
                            try {
                                startActivityForResult(Intent(Intent.ACTION_OPEN_DOCUMENT_TREE).apply {
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION or
                                        Intent.FLAG_GRANT_PERSISTABLE_URI_PERMISSION)
                                }, 202)
                            } catch (error: Exception) {
                                folderResult = null
                                result.error("FOLDER_ERROR", "Não foi possível abrir o seletor de pastas.", null)
                            }
                        }
                    }
                    "useAllMusic" -> {
                        preferences.edit().remove("folder").apply()
                        result.success(null)
                    }
                    "openSettings" -> {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun queryTracks(result: MethodChannel.Result) {
        val selectedFolder = preferences.getString("folder", null)
        worker.execute {
            try {
                val catalog = AudioCatalog(applicationContext)
                val tracks = if (selectedFolder == null) catalog.allTracks()
                    else catalog.folderTracks(Uri.parse(selectedFolder))
                runOnUiThread { if (!isDestroyed) result.success(tracks) }
            } catch (error: Exception) {
                runOnUiThread {
                    if (!isDestroyed) result.error("READ_ERROR",
                        "Não foi possível ler os arquivos. Atualize ou escolha a pasta novamente.", null)
                }
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>,
        grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        backupChannel.permission(requestCode, grantResults)
        if(requestCode==203){notificationResult?.success(grantResults.firstOrNull()==PackageManager.PERMISSION_GRANTED);notificationResult=null}
        if (requestCode == 201) {
            val result = permissionResult ?: return
            permissionResult = null
            if (grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED) queryTracks(result)
            else result.error("PERMISSION_DENIED", "Acesso às músicas não autorizado.", null)
        }
    }

    @Deprecated("Activity result API required by FlutterActivity integration")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        backupChannel.activityResult(requestCode, resultCode, data)
        if (requestCode == 202) {
            val result = folderResult ?: return
            folderResult = null
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                result.success(false)
                return
            }
            try {
                if (((data?.flags ?: 0) and Intent.FLAG_GRANT_WRITE_URI_PERMISSION) != 0) {
                    contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_GRANT_WRITE_URI_PERMISSION)
                } else {
                    contentResolver.takePersistableUriPermission(uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                }
                preferences.edit().putString("folder", uri.toString()).apply()
                // Keep earlier grants: saved tapes and favorites may still use them.
                result.success(true)
            } catch (error: Exception) {
                result.error("FOLDER_ERROR", "Não foi possível autorizar essa pasta. Tente outra.", null)
            }
        }
    }

    override fun onDestroy() {
        worker.shutdownNow()
        super.onDestroy()
    }
}
