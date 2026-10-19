package com.example.mobile_app

import android.content.ContentValues
import android.content.Context
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.FileOutputStream

/** Publishes a generated CSV to the public Documents/SCT_Results directory. */
class CsvStorage(private val context: Context) {
    fun publishCsv(sourcePath: String, displayName: String): String {
        val source = File(sourcePath)
        require(source.isFile) { "CSV source file does not exist: $sourcePath" }
        val safeName = File(displayName).name
        require(safeName.endsWith(".csv", ignoreCase = true)) { "Expected a .csv filename" }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = context.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, safeName)
                put(MediaStore.MediaColumns.MIME_TYPE, "text/csv")
                put(MediaStore.MediaColumns.RELATIVE_PATH, "Documents/SCT_Results")
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Files.getContentUri("external"), values)
                ?: error("Could not create CSV in public Documents")
            try {
                resolver.openOutputStream(uri)?.use { output ->
                    source.inputStream().use { input -> input.copyTo(output) }
                } ?: error("Could not open CSV output stream")
                val finished = ContentValues().apply {
                    put(MediaStore.MediaColumns.IS_PENDING, 0)
                }
                resolver.update(uri, finished, null, null)
                return uri.toString()
            } catch (error: Exception) {
                resolver.delete(uri, null, null)
                throw error
            }
        }

        val folder = File(Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOCUMENTS), "SCT_Results")
        if (!folder.exists() && !folder.mkdirs()) error("Could not create Documents/SCT_Results")
        val destination = File(folder, safeName)
        source.inputStream().use { input ->
            FileOutputStream(destination).use { output -> input.copyTo(output) }
        }
        return destination.absolutePath
    }
}
