package br.com.walkman.walkman

import android.content.ContentUris
import android.content.Context
import android.net.Uri
import android.os.Build
import android.provider.DocumentsContract
import android.provider.MediaStore
import java.io.File

/** Somente consulta referências: não copia nem modifica arquivos do usuário. */
class AudioCatalog(private val context: Context) {
    fun folders(tree: Uri): List<String> {
        val root = DocumentsContract.getTreeDocumentId(tree)
        val result = mutableListOf(root.replace(':', '/'))
        val pending = java.util.ArrayDeque<Pair<String, String>>()
        pending.add(root to result[0])
        val visited = mutableSetOf<String>()
        while (pending.isNotEmpty() && !Thread.currentThread().isInterrupted) {
            val (id, path) = pending.removeFirst()
            if (!visited.add(id)) continue
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, id)
            context.contentResolver.query(children, arrayOf(DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME, DocumentsContract.Document.COLUMN_MIME_TYPE), null, null, null)?.use { cursor ->
                while (cursor.moveToNext()) {
                    if (cursor.getString(2) == DocumentsContract.Document.MIME_TYPE_DIR) {
                        val childPath = "$path/${cursor.getString(1)}"
                        result.add(childPath); pending.add(cursor.getString(0) to childPath)
                    }
                }
            }
        }
        return result.sorted()
    }
    fun allTracks(): List<Map<String, Any>> {
        val media = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val folderColumn = if (Build.VERSION.SDK_INT >= 29) {
            MediaStore.MediaColumns.RELATIVE_PATH
        } else {
            MediaStore.MediaColumns.DATA
        }
        val columns = arrayOf(
            MediaStore.Audio.Media._ID, MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST, MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION, folderColumn
        )
        val tracks = mutableListOf<Map<String, Any>>()
        context.contentResolver.query(media, columns, null, null,
            "${MediaStore.Audio.Media.TITLE} ASC")?.use { cursor ->
            while (cursor.moveToNext()) {
                val id = cursor.getLong(0)
                val rawFolder = cursor.getString(5).orEmpty()
                val folder = if (Build.VERSION.SDK_INT >= 29) {
                    rawFolder.ifEmpty { "Pasta não informada" }
                } else {
                    File(rawFolder).parent ?: "Pasta não informada"
                }
                tracks.add(mapOf(
                    "id" to id.toString(),
                    "title" to (cursor.getString(1) ?: "Sem título"),
                    "artist" to clean(cursor.getString(2), "Artista desconhecido"),
                    "album" to clean(cursor.getString(3), "Álbum desconhecido"),
                    "folder" to folder,
                    "uri" to ContentUris.withAppendedId(media, id).toString(),
                    "duration" to cursor.getLong(4).coerceAtLeast(0)
                ))
            }
        } ?: error("O Android não disponibilizou a biblioteca. Tente novamente.")
        return tracks
    }

    fun folderTracks(tree: Uri): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        val root = DocumentsContract.getTreeDocumentId(tree)
        val pending = java.util.ArrayDeque<Pair<String, String>>()
        pending.add(root to root.replace(':', '/'))
        val visited = mutableSetOf<String>()
        while (pending.isNotEmpty()) {
            if (Thread.currentThread().isInterrupted) break
            val (parent, path) = pending.removeFirst()
            if (!visited.add(parent)) continue
            val children = DocumentsContract.buildChildDocumentsUriUsingTree(tree, parent)
            val projection = arrayOf(
                DocumentsContract.Document.COLUMN_DOCUMENT_ID,
                DocumentsContract.Document.COLUMN_DISPLAY_NAME,
                DocumentsContract.Document.COLUMN_MIME_TYPE
            )
            context.contentResolver.query(children, projection, null, null, null)?.use { cursor ->
                while (cursor.moveToNext()) {
                    val id = cursor.getString(0)
                    val name = cursor.getString(1).orEmpty()
                    val mime = cursor.getString(2).orEmpty()
                    if (mime == DocumentsContract.Document.MIME_TYPE_DIR) {
                        pending.add(id to "$path/$name")
                    } else if (mime.startsWith("audio/") ||
                        name.substringAfterLast('.', "").lowercase() in
                        setOf("mp3", "m4a", "aac", "flac", "wav", "ogg", "opus", "wma")) {
                        val uri = DocumentsContract.buildDocumentUriUsingTree(tree, id)
                        result.add(mapOf(
                            "id" to uri.toString(), "title" to name,
                            "artist" to "Pasta selecionada", "album" to "Arquivo local",
                            "folder" to path, "uri" to uri.toString(), "duration" to 0L
                        ))
                    }
                }
            } ?: error("Não foi possível ler a pasta selecionada.")
        }
        return result.sortedBy { it["title"].toString().lowercase() }
    }

    private fun clean(value: String?, fallback: String) =
        if (value.isNullOrBlank() || value == "<unknown>") fallback else value
}
