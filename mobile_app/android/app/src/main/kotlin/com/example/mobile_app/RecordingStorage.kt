
package com.example.mobile_app

import android.content.ContentValues
import android.content.Context
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import java.io.File
import java.io.FileInputStream
import java.io.FileOutputStream

class RecordingStorage(private val context: Context) {

    fun publishRecording(
        sourcePath: String,
        displayName: String
    ): String {
        val sourceFile = File(sourcePath)

        if (!sourceFile.exists()) {
            throw IllegalArgumentException(
                "Recording file does not exist: $sourcePath"
            )
        }

        val mimeType = if (
            displayName.endsWith(".mp3", ignoreCase = true)
        ) {
            "audio/mpeg"
        } else {
            "audio/wav"
        }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            return publishUsingMediaStore(
                sourceFile,
                displayName,
                mimeType
            )
        }

        return publishLegacy(
            sourceFile,
            displayName,
            mimeType
        )
    }

    private fun publishUsingMediaStore(
        sourceFile: File,
        displayName: String,
        mimeType: String
    ): String {
        val resolver = context.contentResolver

        val values = ContentValues().apply {
            put(
                MediaStore.MediaColumns.DISPLAY_NAME,
                displayName
            )
            put(
                MediaStore.MediaColumns.MIME_TYPE,
                mimeType
            )
            put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                "${Environment.DIRECTORY_MUSIC}/SCT_Recordings"
            )
            put(
                MediaStore.MediaColumns.IS_PENDING,
                1
            )
        }

        val uri = resolver.insert(
            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
            values
        ) ?: throw IllegalStateException(
            "Could not create MediaStore entry"
        )

        try {
            val outputStream = resolver.openOutputStream(uri)
                ?: throw IllegalStateException(
                    "Could not open MediaStore output stream"
                )

            outputStream.use { output ->
                FileInputStream(sourceFile).use { input ->
                    input.copyTo(output)
                }
            }

            val completedValues = ContentValues().apply {
                put(
                    MediaStore.MediaColumns.IS_PENDING,
                    0
                )
            }

            resolver.update(
                uri,
                completedValues,
                null,
                null
            )

            return uri.toString()
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    @Suppress("DEPRECATION")
    private fun publishLegacy(
        sourceFile: File,
        displayName: String,
        mimeType: String
    ): String {
        val musicDirectory =
            Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_MUSIC
            )

        val recordingsDirectory = File(
            musicDirectory,
            "SCT_Recordings"
        )

        if (!recordingsDirectory.exists()) {
            recordingsDirectory.mkdirs()
        }

        val destinationFile = File(
            recordingsDirectory,
            displayName
        )

        FileInputStream(sourceFile).use { input ->
            FileOutputStream(destinationFile).use { output ->
                input.copyTo(output)
            }
        }

        MediaScannerConnection.scanFile(
            context,
            arrayOf(destinationFile.absolutePath),
            arrayOf(mimeType),
            null
        )

        return destinationFile.absolutePath
    }
    
fun publishPdf(
    sourcePath: String,
    displayName: String
): String {
    val sourceFile = File(sourcePath)

    if (!sourceFile.exists()) {
        throw IllegalArgumentException(
            "PDF file does not exist: $sourcePath"
        )
    }

    if (!displayName.endsWith(".pdf", ignoreCase = true)) {
        throw IllegalArgumentException(
            "Expected a PDF filename"
        )
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
        val resolver = context.contentResolver

        val values = ContentValues().apply {
            put(MediaStore.MediaColumns.DISPLAY_NAME, displayName)
            put(MediaStore.MediaColumns.MIME_TYPE, "application/pdf")
            put(
                MediaStore.MediaColumns.RELATIVE_PATH,
                "${Environment.DIRECTORY_DOCUMENTS}/SCT_Results"
            )
            put(MediaStore.MediaColumns.IS_PENDING, 1)
        }

        val uri = resolver.insert(
            MediaStore.Files.getContentUri("external"),
            values
        ) ?: throw IllegalStateException(
            "Could not create PDF entry in MediaStore"
        )

        try {
            val output = resolver.openOutputStream(uri)
                ?: throw IllegalStateException(
                    "Could not open PDF output stream"
                )

            output.use { destination ->
                FileInputStream(sourceFile).use { input ->
                    input.copyTo(destination)
                }
            }

            val completedValues = ContentValues().apply {
                put(MediaStore.MediaColumns.IS_PENDING, 0)
            }

            resolver.update(uri, completedValues, null, null)

            return uri.toString()
        } catch (error: Exception) {
            resolver.delete(uri, null, null)
            throw error
        }
    }

    // Older Android versions.
    @Suppress("DEPRECATION")
    val documentsDirectory =
        Environment.getExternalStoragePublicDirectory(
            Environment.DIRECTORY_DOCUMENTS
        )

    val reportDirectory = File(
        documentsDirectory,
        "SCT_Results"
    )

    if (!reportDirectory.exists() &&
        !reportDirectory.mkdirs()
    ) {
        throw IllegalStateException(
            "Could not create PDF directory"
        )
    }

    val destination = File(reportDirectory, displayName)

    FileInputStream(sourceFile).use { input ->
        FileOutputStream(destination).use { output ->
            input.copyTo(output)
        }
    }

    MediaScannerConnection.scanFile(
        context,
        arrayOf(destination.absolutePath),
        arrayOf("application/pdf"),
        null
    )

    return destination.absolutePath
}

}
